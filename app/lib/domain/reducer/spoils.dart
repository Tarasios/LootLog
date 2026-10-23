part of '../reducer.dart';

/// The month-end spoils ritual: resolving each personal category's leftover
/// through explicit allocations or, past grace, the default policy. The
/// savings-rule variants live in `savings_economy.dart`; this part holds the
/// ritual itself and the legacy (pre-adoption) allocation rules.
extension _SpoilsRitual on _HouseholdStateBuilder {
  /// The spoils ritual for [month]. Explicit allocations win; past grace, the
  /// default attacks the owner's outstanding OVERBUDGETs first, then the
  /// configured policy. Fun categories resolve before important ones, which
  /// resolve before necessities, so default debt payments spend the fun money
  /// first. Legacy carries are written into [carryOut] (sliceId -> cents).
  void _resolveSpoils(
    Month month,
    List<_PersonalCategoryMonth> figures,
    SavingsRules? rules,
    Map<String, int> carryOut,
  ) {
    final ritualOrder = figures.toList()
      ..sort((first, second) {
        final byPriority = _ritualRank(
          first.config.priority,
        ).compareTo(_ritualRank(second.config.priority));
        return byPriority != 0
            ? byPriority
            : first.config.sliceId.compareTo(second.config.sliceId);
      });
    final graceDeadline = month.endInstantUtc().add(
      Duration(days: settings.spoilsGraceDays),
    );
    for (final figure in ritualOrder) {
      final config = figure.config;
      final explicit =
          allocations['${figure.ownerId}|${config.sliceId}|${month.toKey()}'];
      List<Allocation> effective;
      var resolved = true;
      if (explicit != null) {
        effective = explicit.allocations;
      } else if (now.isAfter(graceDeadline)) {
        effective = figure.underSavingsRules
            ? _savingsDefaults(
                config,
                figure.ownerId,
                figure.leftover,
                rules!.generalRateFor(month),
              )
            : _legacyDefaultAllocations(
                config,
                figure.ownerId,
                figure.leftover,
              );
      } else {
        effective = const [];
        resolved = false;
      }
      if (resolved) {
        if (figure.underSavingsRules) {
          var allowanceLeft = figure.leftover;
          for (final allocation in effective) {
            allowanceLeft = _applySavingsAllocation(
              config,
              figure.ownerId,
              allocation,
              month,
              rules!.generalRateFor(month),
              allowanceLeft,
            );
          }
        } else {
          for (final allocation in effective) {
            _applyLegacyAllocation(
              config,
              figure.ownerId,
              allocation,
              month,
              carryOut,
            );
          }
        }
      }
      sliceMonths[HouseholdState.monthKey(config.sliceId, month)] = SliceMonth(
        sliceId: config.sliceId,
        month: month,
        isGroup: false,
        ownerUserId: figure.ownerId,
        effectiveLimitCents: figure.effectiveLimit,
        spentCents: figure.spent,
        leftoverCents: figure.leftover,
        carryInCents: figure.carryIn,
        carryOutCents: carryOut[config.sliceId] ?? 0,
        overspendCents: figure.overspend,
        resolved: resolved,
        lockedCents: figure.locked,
        fromSavingsCents: figure.fromSavings,
        savingsCents: figure.savingsAfter,
        savingsTaxPaidCents: figure.savingsTaxPaid,
        coveredCents: figure.covered,
        trimmedCents: figure.trimmed,
      );
    }
  }

  /// Applies one legacy spoils-ritual allocation line for [config] (owned by
  /// [ownerId]) in [month].
  void _applyLegacyAllocation(
    SliceConfig config,
    String ownerId,
    Allocation allocation,
    Month month,
    Map<String, int> carryOut,
  ) {
    final destination = allocation.destination;
    switch (destination) {
      case CarryInSlice():
        carryOut[config.sliceId] =
            (carryOut[config.sliceId] ?? 0) + allocation.amountCents;
      case QuestDestination():
        // Category-match tithing: an attack from a category whose main
        // category matches the quest's is untithed (full damage). From a
        // non-matching category, the source category's pool tithe is skimmed
        // to the war chest and only the remainder lands as damage. A quest
        // without a main category never matches (always tithed).
        final int damage;
        if (_questMatchesCategory(destination.questId, config)) {
          damage = allocation.amountCents;
        } else {
          final split = Money.titheCents(
            allocation.amountCents,
            config.poolTithePct,
          );
          _addChest(split.titheCents, month);
          damage = split.remainderCents;
        }
        _creditQuest(destination.questId, ownerId, damage);
      case Discretionary():
        final split = Money.titheCents(
          allocation.amountCents,
          config.poolTithePct,
        );
        _addChest(split.titheCents, month);
        _creditVaultDuringSweep(ownerId, split.remainderCents);
      case OverbudgetPayment():
        // Attacks on the OVERBUDGET follow the same category-match tithing
        // as quests, against the indebted category's main category. Damage
        // beyond the outstanding debt is not lost — it converts to
        // discretionary. On a matched (untithed) attack that excess still
        // pays the pool tithe, so overpaying a debt never dodges the cut a
        // plain discretionary conversion would have taken.
        final outstanding = debtBySlice[destination.sliceId] ?? 0;
        final int payment;
        if (_sliceMatchesCategory(destination.sliceId, config)) {
          payment = allocation.amountCents < outstanding
              ? allocation.amountCents
              : outstanding;
          final excessGross = allocation.amountCents - payment;
          if (excessGross > 0) {
            final split = Money.titheCents(excessGross, config.poolTithePct);
            _addChest(split.titheCents, month);
            _creditVaultDuringSweep(ownerId, split.remainderCents);
          }
        } else {
          final split = Money.titheCents(
            allocation.amountCents,
            config.poolTithePct,
          );
          _addChest(split.titheCents, month);
          final damage = split.remainderCents;
          payment = damage < outstanding ? damage : outstanding;
          final excess = damage - payment;
          if (excess > 0) {
            _creditVaultDuringSweep(ownerId, excess);
          }
        }
        if (payment > 0) {
          debtBySlice[destination.sliceId] = outstanding - payment;
        }
    }
  }

  /// The legacy grace-expired default for a personal category's leftover:
  /// the owner's outstanding OVERBUDGETs are attacked first (gross amounts
  /// sized so the post-tithe damage covers each debt), and only the remainder
  /// follows the category's configured default policy. The OVERBUDGET must
  /// be paid; skipping it is an active choice made with an explicit
  /// allocation, never the silent default.
  List<Allocation> _legacyDefaultAllocations(
    SliceConfig config,
    String ownerId,
    int leftover,
  ) {
    if (leftover <= 0) {
      return const [];
    }
    final lines = <Allocation>[];
    var remaining = leftover;
    final indebted = debtBySlice.keys.toList()..sort();
    for (final sliceId in indebted) {
      if (remaining <= 0) {
        break;
      }
      final outstanding = debtBySlice[sliceId] ?? 0;
      if (outstanding <= 0 || debtOwner[sliceId] != ownerId) {
        continue;
      }
      final int grossNeeded;
      if (_sliceMatchesCategory(sliceId, config) || config.poolTithePct <= 0) {
        grossNeeded = outstanding;
      } else if (config.poolTithePct >= 100) {
        grossNeeded = remaining;
      } else {
        final keptPct = 100 - config.poolTithePct;
        grossNeeded = (outstanding * 100 + keptPct - 1) ~/ keptPct;
      }
      final amount = grossNeeded < remaining ? grossNeeded : remaining;
      if (amount > 0) {
        lines.add(
          Allocation(
            destination: OverbudgetPayment(sliceId),
            amountCents: amount,
          ),
        );
        remaining -= amount;
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
}

/// Resolution order in the ritual: fun first, necessities last.
int _ritualRank(SlicePriority priority) => switch (priority) {
  SlicePriority.fun => 0,
  SlicePriority.important => 1,
  SlicePriority.necessity => 2,
};
