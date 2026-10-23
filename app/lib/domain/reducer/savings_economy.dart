part of '../reducer.dart';

/// A purchase of a quest's goal covered from the purchaser's category
/// savings, applied inside the month sweep once that category's savings pool
/// for the month is known.
typedef _QuestSavingsCover = ({
  String questId,
  int amountCents,
  String purchaserId,
});

/// The savings economy (from the household's adoption month): shortfall
/// covers, month-end allocations through the taxed pools, grace-expired
/// defaults and advance repayment trims. Tax-on-move math itself lives in
/// `pools.dart`.
extension _SavingsEconomy on _HouseholdStateBuilder {
  /// Shortfall covers (savings rules only). General covers resolve here;
  /// category-savings covers on quest purchases are returned, keyed
  /// "sliceId|yyyy-MM", for the sweep to apply. A voided purchase ignores its
  /// covers, and covers never exceed the purchase.
  Map<String, List<_QuestSavingsCover>> _applyShortfallCovers(
    SavingsRules? rules,
  ) {
    final questCoversBySliceMonth = <String, List<_QuestSavingsCover>>{};
    final coveredSoFar = <String, int>{};
    for (final cover in shortfallCovers) {
      final accumulator = purchases[cover.purchaseId];
      if (accumulator == null || accumulator.voided) continue;
      final purchase = accumulator.event;
      if (rules == null || !rules.appliesTo(purchase.occurredMonth)) continue;
      final alreadyCovered = coveredSoFar[cover.purchaseId] ?? 0;
      final room = purchase.amountCents - alreadyCovered;
      final coverCents = cover.amountCents < room ? cover.amountCents : room;
      if (coverCents <= 0) continue;
      final target = purchase.target;
      switch (cover.source) {
        case GeneralCover():
          if (target is SliceCharge) {
            final coverKey =
                '${target.sliceId}|${purchase.occurredMonth.toKey()}';
            coverBySliceMonth[coverKey] =
                (coverBySliceMonth[coverKey] ?? 0) + coverCents;
          } else if (target is QuestCharge) {
            _creditQuest(target.questId, purchase.userId, coverCents);
          } else {
            continue;
          }
          _addVault(purchase.userId, -coverCents);
          _recordVaultFlow(
            purchase.userId,
            purchase.occurredMonth,
            -coverCents,
          );
        case CategorySavingsCover(:final sliceId):
          final config = slices[sliceId];
          if (target is! QuestCharge ||
              config == null ||
              config.ownerUserId != purchase.userId) {
            continue;
          }
          questCoversBySliceMonth
              .putIfAbsent(
                '$sliceId|${purchase.occurredMonth.toKey()}',
                () => [],
              )
              .add((
                questId: target.questId,
                amountCents: coverCents,
                purchaserId: purchase.userId,
              ));
      }
      coveredSoFar[cover.purchaseId] = alreadyCovered + coverCents;
    }
    return questCoversBySliceMonth;
  }

  /// Moves category-savings covers for quest purchases out of [config]'s
  /// savings pool into each quest, paying the difference tax (none when the
  /// quest's main category matches the category's).
  void _coverQuestsFromCategorySavings(
    SliceConfig config,
    String ownerId,
    Month month,
    SavingsRules rules,
    List<_QuestSavingsCover> covers,
  ) {
    for (final cover in covers) {
      final pool = savings[config.sliceId] ?? TaxedBalance.zero;
      final movable = cover.amountCents < pool.balanceCents
          ? cover.amountCents
          : pool.balanceCents;
      if (movable <= 0) continue;
      final move = moveTaxed(
        pool,
        movable,
        _questMatchesCategory(cover.questId, config)
            ? 0
            : rules.generalRateFor(month),
      );
      savings[config.sliceId] = move.remaining;
      _addChest(move.topUpCents, month);
      _creditQuest(cover.questId, ownerId, move.delivered.balanceCents);
    }
  }

  /// Applies one month-end line under the savings rules. Returns the unspent
  /// allowance still available for later lines.
  int _applySavingsAllocation(
    SliceConfig config,
    String ownerId,
    Allocation allocation,
    Month month,
    int generalRate,
    int allowanceLeft,
  ) {
    final fromSavings = allocation.source == AllocationSource.savings;
    final source = fromSavings
        ? (savings[config.sliceId] ?? TaxedBalance.zero)
        : TaxedBalance(allowanceLeft);
    final amount = allocation.amountCents < source.balanceCents
        ? allocation.amountCents
        : source.balanceCents;
    if (amount <= 0) return allowanceLeft;

    MoveResult move(int ratePct) {
      final result = moveTaxed(source, amount, ratePct);
      _addChest(result.topUpCents, month);
      if (fromSavings) savings[config.sliceId] = result.remaining;
      return result;
    }

    switch (allocation.destination) {
      case CarryInSlice():
        if (fromSavings) return allowanceLeft; // already in savings: stays
        final result = move(config.poolTithePct);
        savings[config.sliceId] =
            (savings[config.sliceId] ?? TaxedBalance.zero) + result.delivered;
      case Discretionary():
        _creditVaultDuringSweep(
          ownerId,
          move(generalRate).delivered.balanceCents,
        );
      case QuestDestination(:final questId):
        final delivered = move(
          _questMatchesCategory(questId, config) ? 0 : generalRate,
        ).delivered.balanceCents;
        _creditQuest(questId, ownerId, delivered);
      case OverbudgetPayment(:final sliceId):
        final untaxed =
            debtKind[sliceId] == DebtKind.provisions ||
            _sliceMatchesCategory(sliceId, config);
        final result = move(untaxed ? 0 : generalRate);
        final outstanding = debtBySlice[sliceId] ?? 0;
        final delivered = result.delivered.balanceCents;
        final payment = delivered < outstanding ? delivered : outstanding;
        if (payment > 0) debtBySlice[sliceId] = outstanding - payment;
        final excess = delivered - payment;
        if (excess > 0) {
          // The excess keeps its share of tax paid and tops up to general.
          final excessTaxPaid = delivered == 0
              ? 0
              : result.delivered.taxPaidCents * excess ~/ delivered;
          final toGeneral = moveTaxed(
            TaxedBalance(excess, excessTaxPaid),
            excess,
            generalRate,
          );
          _addChest(toGeneral.topUpCents, month);
          _creditVaultDuringSweep(ownerId, toGeneral.delivered.balanceCents);
        }
    }
    return fromSavings ? allowanceLeft : allowanceLeft - amount;
  }

  /// Grace-expired default under the savings rules: the owner's outstanding
  /// debts first (allowance sized so the post-tax payment covers each), then
  /// the category's default policy. Category savings are never moved.
  List<Allocation> _savingsDefaults(
    SliceConfig config,
    String ownerId,
    int leftover,
    int generalRate,
  ) {
    if (leftover <= 0) return const [];
    final lines = <Allocation>[];
    var remaining = leftover;
    for (final debtId in debtBySlice.keys.toList()..sort()) {
      if (remaining <= 0) break;
      final outstanding = debtBySlice[debtId] ?? 0;
      if (outstanding <= 0 || debtOwner[debtId] != ownerId) continue;
      final untaxed =
          debtKind[debtId] == DebtKind.provisions ||
          _sliceMatchesCategory(debtId, config);
      final gross = grossToDeliver(
        TaxedBalance(remaining),
        outstanding,
        untaxed ? 0 : generalRate,
      );
      if (gross > 0) {
        lines.add(
          Allocation(
            destination: OverbudgetPayment(debtId),
            amountCents: gross,
          ),
        );
        remaining -= gross;
      }
    }
    if (remaining > 0) {
      lines.add(
        Allocation(
          destination: config.defaultLeftoverPolicy,
          amountCents: remaining,
        ),
      );
    }
    return lines;
  }

  /// Allowance withheld from [config] in [month] to repay approved advances:
  /// this month's scheduled trim plus anything earlier months couldn't absorb,
  /// capped at the month's funding (the excess rolls on).
  int _takeAdvanceTrim(SliceConfig config, Month month, int carryIn) {
    final due =
        (trimBySliceMonth['${config.sliceId}|${month.toKey()}'] ?? 0) +
        (trimRollover[config.sliceId] ?? 0);
    if (due <= 0) return 0;
    final room = config.baseEffectiveLimitCents + carryIn;
    final taken = due < room ? due : (room > 0 ? room : 0);
    trimRollover[config.sliceId] = due - taken;
    return taken;
  }
}
