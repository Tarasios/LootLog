/// The single source of truth for "what is true now": a pure function
/// `List<Event> -> HouseholdState`. Everything time-based is computed here at
/// read time; there are no scheduled jobs. Pure Dart, zero Flutter imports.
library;

import 'event.dart';
import 'money.dart';
import 'state.dart';
import 'time.dart';
import 'value_types.dart';

/// Reduces the event log to the derived household state as of [asOf]
/// (defaults to now). The reduction is deterministic and order-independent:
/// events are de-duplicated by id and sorted internally.
HouseholdState reduce(List<Event> events, {DateTime? asOf}) {
  final now = (asOf ?? DateTime.now()).toUtc();

  // Idempotency: keep one event per id. Total order: (occurredAt, eventId).
  final seenIds = <String>{};
  final ordered = <Event>[];
  for (final e in events) {
    if (seenIds.add(e.eventId)) {
      ordered.add(e);
    }
  }
  ordered.sort((a, b) {
    final c = a.occurredAt.compareTo(b.occurredAt);
    return c != 0 ? c : a.eventId.compareTo(b.eventId);
  });

  final b = _Builder(now);
  for (final e in ordered) {
    b.gather(e);
  }
  return b.build();
}

/// Mutable accumulator that gathers events, then derives the read-model.
class _Builder {
  _Builder(this.now);

  final DateTime now;

  Settings settings = const Settings();
  final Set<String> userIds = {};

  // Last-writer-wins configuration by id.
  final Map<String, MainCategorySet> mainCategoryCfg = {};
  final Map<String, SliceConfig> slices = {};
  final Map<String, QuestSet> questCfg = {};
  final Map<String, EmergencyFundSet> fundCfg = {};
  final Map<String, PetSet> petCfg = {};
  final Map<String, MemberSet> memberCfg = {};

  // Per-adult share tables, last-writer-wins per month key.
  final Map<String, GroupShareSet> shareSets = {};
  final Map<String, RecurringExpenseSet> recurringCfg = {};
  final Map<String, AccountBalanceRecorded> accounts = {};
  final Map<String, TrackedAccountSet> accountCfg = {};
  final List<AccountTransferRecorded> accountTransfers = [];

  // Purchases and their receipts. Receipt attach/detach events are buffered
  // here and applied once all purchases are gathered (see [_applyReceipts]).
  final Map<String, _PurchaseAcc> purchases = {};
  final List<Event> _receiptEvents = [];

  // Variable-expense actuals, keyed "expenseId|month".
  final Map<String, int> variableActuals = {};

  // Leftover allocations, keyed "userId|sliceId|month" (last writer wins).
  final Map<String, LeftoverAllocated> allocations = {};

  // Quest lifecycle.
  final Set<String> abandonedQuests = {};

  // Gifts, contributions, refunds, income.
  final List<GiftReceived> gifts = [];
  final List<PoolContributionMade> contributions = [];
  final List<TaxRefundRecorded> taxRefunds = [];
  final Map<String, int> income = {}; // "userId|month" -> cents
  // Default incomes, keyed "userId|effectiveFromMonth" (last writer wins).
  final Map<String, DefaultIncomeSet> defaultIncomeCfg = {};

  // Withdrawals.
  final Map<String, PoolWithdrawalProposed> proposals = {};
  final Map<String, List<PoolWithdrawalApproved>> approvals = {};
  final Set<String> cancelledProposals = {};

  int? goalTarget;

  void _note(String? u) {
    if (u != null) {
      userIds.add(u);
    }
  }

  void gather(Event e) {
    _note(e.userId);
    switch (e) {
      case PurchaseAdded():
        _note(e.userId);
        purchases.putIfAbsent(
          e.purchaseId,
          () => _PurchaseAcc(e),
        );
      case PurchaseVoided():
        final p = purchases[e.purchaseId];
        if (p != null) {
          p.voided = true;
        }
      case ReceiptAttached():
      case ReceiptDetached():
        // Buffer receipt events and bind them after every purchase has been
        // gathered, so a receipt whose envelope happens to sort before its
        // purchase (same `occurredAt`, id tie-break) still attaches. Keeps the
        // reduction order-independent.
        _receiptEvents.add(e);
      case BudgetSliceSet():
        final existing = slices[e.sliceId];
        final created = existing == null
            ? e.occurredMonth
            : (existing.createdMonth.isBefore(e.occurredMonth)
                ? existing.createdMonth
                : e.occurredMonth);
        if (e.ownership is PersonalSlice) {
          _note((e.ownership as PersonalSlice).userId);
        }
        slices[e.sliceId] = SliceConfig(
          sliceId: e.sliceId,
          name: e.name,
          ownership: e.ownership,
          mainCategoryId: e.mainCategoryId,
          limitCents: e.limitCents,
          poolTithePct: e.poolTithePct,
          defaultLeftoverPolicy: e.defaultLeftoverPolicy,
          taxDeductibleByDefault: e.taxDeductibleByDefault,
          createdMonth: created,
          emergencyFundId: e.emergencyContribution?.fundId,
          emergencyContributionCents: e.emergencyContribution?.amountCents ?? 0,
          petId: e.petId,
        );
      case MainCategorySet():
        mainCategoryCfg[e.id] = e;
      case RecurringExpenseSet():
        if (e.ownership is PersonalParty) {
          _note((e.ownership as PersonalParty).userId);
        }
        recurringCfg[e.expenseId] = e;
      case VariableExpenseRecorded():
        variableActuals['${e.expenseId}|${e.month.toKey()}'] = e.actualCents;
      case IncomeSet():
        _note(e.forUserId);
        income['${e.forUserId}|${e.month.toKey()}'] = e.amountCents;
      case DefaultIncomeSet():
        _note(e.forUserId);
        defaultIncomeCfg['${e.forUserId}|${e.effectiveFromMonth.toKey()}'] = e;
      case QuestSet():
        if (e.ownership is PersonalParty) {
          _note((e.ownership as PersonalParty).userId);
        }
        questCfg[e.questId] = e;
      case QuestAbandoned():
        abandonedQuests.add(e.questId);
        _abandonInstants[e.questId] = e.occurredAt;
      case LeftoverAllocated():
        _note(e.forUserId);
        allocations['${e.forUserId}|${e.sliceId}|${e.month.toKey()}'] = e;
      case GiftReceived():
        _note(e.forUserId);
        gifts.add(e);
      case PoolContributionMade():
        _note(e.fromUserId);
        contributions.add(e);
      case PoolWithdrawalProposed():
        _note(e.byUserId);
        if (e.destination is UserVaultDestination) {
          _note((e.destination as UserVaultDestination).userId);
        }
        proposals[e.proposalId] = e;
      case PoolWithdrawalApproved():
        _note(e.byUserId);
        approvals.putIfAbsent(e.proposalId, () => []).add(e);
      case PoolWithdrawalCancelled():
        cancelledProposals.add(e.proposalId);
      case TaxRefundRecorded():
        taxRefunds.add(e);
      case EmergencyFundSet():
        fundCfg[e.fundId] = e;
      case PetSet():
        petCfg[e.petId] = e;
      case MemberSet():
        memberCfg[e.memberId] = e;
        // Adults carry a ledger, so they must be known users (even when
        // retired, so a prior balance still surfaces). Dependents and pets do
        // not — they never get a vault.
        if (e.role == MemberRole.adult) {
          _note(e.memberId);
        }
      case GroupShareSet():
        shareSets[e.month.toKey()] = e;
      case GoalSet():
        goalTarget = e.targetCents;
      case TrackedAccountSet():
        accountCfg[e.accountId] = e;
      case AccountBalanceRecorded():
        accounts[e.accountId] = e;
      case AccountTransferRecorded():
        accountTransfers.add(e);
      case SettingChanged():
        _applySetting(e);
      case CosmeticSet():
        break; // domain-inert
    }
  }

  void _applySetting(SettingChanged e) {
    final v = e.value;
    switch (e.key) {
      case 'spoilsGraceDays':
        if (v is int) settings = settings.copyWith(spoilsGraceDays: v);
      case 'dissolutionTithePct':
        if (v is int) settings = settings.copyWith(dissolutionTithePct: v);
      case 'showNetWorth':
        if (v is bool) settings = settings.copyWith(showNetWorth: v);
    }
  }

  // ---- Derivation -------------------------------------------------------

  // Running balances.
  final Map<String, int> vault = {};
  int warChest = 0;
  final Map<String, int> chestMonthlyNet = {}; // "yyyy-MM" -> net inflow
  final Map<String, int> questBalance = {};
  final Map<String, Map<String, int>> questContrib = {};
  final Map<String, SliceMonth> sliceMonths = {};
  final Map<String, int> recurringByUserMonth = {};
  final List<RansackRecord> ransacks = [];

  /// Debt minimum payments surfaced as shared recurring expenses.
  final List<_DerivedRecurring> derivedRecurring = [];

  static const Map<AccountCadence, int> _cadenceDays = {
    AccountCadence.daily: 1,
    AccountCadence.monthly: 30,
    AccountCadence.quarterly: 91,
    AccountCadence.annually: 365,
  };
  static const Map<AccountCadence, int> _cadencePerYear = {
    AccountCadence.daily: 365,
    AccountCadence.monthly: 12,
    AccountCadence.quarterly: 4,
    AccountCadence.annually: 1,
  };

  /// Interest accrued on [base] from [since] to [now] for the given rate and
  /// cadence, by completed compounding periods (no partial-period accrual).
  /// Zero when any input is missing or no full period has elapsed.
  int _accruedInterest(
      int base, int? aprBps, AccountCadence? cadence, DateTime? since) {
    if (aprBps == null || aprBps == 0 || cadence == null || since == null) {
      return 0;
    }
    final elapsedDays = now.difference(since).inDays;
    if (elapsedDays <= 0) {
      return 0;
    }
    final completed = elapsedDays ~/ _cadenceDays[cadence]!;
    if (completed <= 0) {
      return 0;
    }
    final fraction = completed / _cadencePerYear[cadence]!;
    return (base * (aprBps / 10000.0) * fraction).round();
  }

  /// Whether a manual value recorded at [since] has gone stale relative to its
  /// [cadence] (one full cadence has lapsed with no fresh recording).
  bool _isStale(AccountCadence? cadence, DateTime? since) {
    if (cadence == null || since == null) {
      return false;
    }
    return now.difference(since).inDays > _cadenceDays[cadence]!;
  }

  /// Whether [month] has fully ended as of the read time.
  bool _isClosed(Month month) => !now.isBefore(month.endInstantUtc());

  void _addChest(int amount, Month month) {
    warChest += amount;
    final k = month.toKey();
    chestMonthlyNet[k] = (chestMonthlyNet[k] ?? 0) + amount;
  }

  void _addVault(String user, int amount) {
    vault[user] = (vault[user] ?? 0) + amount;
  }

  /// The ledger-bearing adults. Explicit active adult members win; absent any,
  /// every known user is treated as an adult (legacy / dependents-only history).
  Set<String> _adultIds() {
    final declared = {
      for (final m in memberCfg.values)
        if (m.role == MemberRole.adult && m.active) m.memberId,
    };
    return declared.isNotEmpty ? declared : userIds;
  }

  bool _isAdult(String id) => _adultIds().contains(id);

  /// The permille weight per adult for shared costs in [month]: the latest share
  /// table with month ≤ [month] (carried forward), else an even split among the
  /// current adults.
  Map<String, int> _sharesFor(Month month) {
    GroupShareSet? best;
    for (final s in shareSets.values) {
      if (!s.month.isAfter(month) &&
          (best == null || s.month.isAfter(best.month))) {
        best = s;
      }
    }
    if (best != null && best.shares.isNotEmpty) {
      return best.shares;
    }
    return {for (final a in _adultIds()) a: 1};
  }

  /// Splits [amount] across [weights] with floor rounding. Any leftover cents go
  /// to [oddTo] (the purchaser) when given; otherwise they are distributed by
  /// largest remainder so the parts always sum exactly to [amount].
  Map<String, int> _splitShares(int amount, Map<String, int> weights,
      {String? oddTo}) {
    final totalWeight = weights.values.fold(0, (a, b) => a + b);
    if (amount == 0 || totalWeight <= 0) {
      return {?oddTo: amount};
    }
    final base = <String, int>{};
    final remainders = <String, int>{};
    var assigned = 0;
    for (final entry in weights.entries) {
      final numerator = amount * entry.value;
      final share = numerator ~/ totalWeight;
      base[entry.key] = share;
      remainders[entry.key] = numerator % totalWeight;
      assigned += share;
    }
    var leftover = amount - assigned;
    if (oddTo != null) {
      base[oddTo] = (base[oddTo] ?? 0) + leftover;
      return base;
    }
    final order = weights.keys.toList()
      ..sort((a, b) {
        final c = remainders[b]!.compareTo(remainders[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    var i = 0;
    while (leftover > 0 && order.isNotEmpty) {
      base[order[i % order.length]] = base[order[i % order.length]]! + 1;
      leftover--;
      i++;
    }
    return base;
  }

  /// Binds buffered receipt attach/detach events onto their purchases. Events
  /// arrive here in canonical `(occurredAt, eventId)` order, so a later detach
  /// correctly cancels a prior attach, and an attach that sorted ahead of its
  /// purchase now finds it. Receipts referencing an unknown purchase are ignored.
  void _applyReceipts() {
    for (final e in _receiptEvents) {
      switch (e) {
        case ReceiptAttached():
          purchases[e.purchaseId]?.receipts[e.sha256] = ReceiptRef(
            sha256: e.sha256,
            mimeType: e.mimeType,
            sizeBytes: e.sizeBytes,
          );
        case ReceiptDetached():
          purchases[e.purchaseId]?.receipts.remove(e.sha256);
        default:
          break;
      }
    }
  }

  HouseholdState build() {
    _applyReceipts();
    for (final u in userIds) {
      vault.putIfAbsent(u, () => 0);
    }

    // A debt's minimum payment surfaces automatically as a shared recurring
    // expense — the single, reminder-only crossover where a tracked account
    // touches the monthly plan (it never enters category math).
    for (final cfg in accountCfg.values) {
      if (cfg.kind == AccountKind.debt && (cfg.minPaymentCents ?? 0) > 0) {
        derivedRecurring.add(_DerivedRecurring(
          expenseId: 'debt:${cfg.accountId}',
          name: '${cfg.name} — minimum payment',
          amountCents: cfg.minPaymentCents!,
        ));
      }
    }

    // Per-slice, per-month spending derived from purchases.
    final personalSpent = <String, int>{}; // "sliceId|month"
    final groupSpent = <String, int>{};
    final questDrawdown = <String, int>{};
    final emergencyPurchases = <PurchaseAdded>[];

    for (final acc in purchases.values) {
      if (acc.voided) {
        continue;
      }
      final e = acc.event;
      final target = e.target;
      switch (target) {
        case SliceCharge():
          final cfg = slices[target.sliceId];
          final k = '${target.sliceId}|${e.occurredMonth.toKey()}';
          if (cfg != null && cfg.isGroup) {
            groupSpent[k] = (groupSpent[k] ?? 0) + e.amountCents;
          } else if (e.shared) {
            // Split across the adults by their share table; the purchaser's
            // share lands on this personal category, every co-adult's share is
            // charged to their vault. Odd cents go to the purchaser.
            final parts = _splitShares(
              e.amountCents,
              _sharesFor(e.occurredMonth),
              oddTo: e.userId,
            );
            parts.forEach((adult, amt) {
              if (adult == e.userId) {
                personalSpent[k] = (personalSpent[k] ?? 0) + amt;
              } else {
                _addVault(adult, -amt);
              }
            });
          } else {
            personalSpent[k] = (personalSpent[k] ?? 0) + e.amountCents;
          }
        case VaultCharge():
          if (e.shared) {
            // Each adult's share is charged to their own vault; odd cents to
            // the purchaser.
            final parts = _splitShares(
              e.amountCents,
              _sharesFor(e.occurredMonth),
              oddTo: e.userId,
            );
            parts.forEach((adult, amt) => _addVault(adult, -amt));
          } else {
            _addVault(e.userId, -e.amountCents);
          }
        case QuestCharge():
          questDrawdown[target.questId] =
              (questDrawdown[target.questId] ?? 0) + e.amountCents;
        case EmergencyCharge():
          emergencyPurchases.add(e);
      }
    }

    // Determine the month range to iterate.
    final range = _monthRange();

    // Chronological month sweep: leftover resolution, group leftovers,
    // recurring burden, and the emergency-contribution schedule.
    final carryPrev = <String, int>{}; // sliceId -> carry into current month
    final fundSchedule = <String, List<_FundContribution>>{};

    if (range != null) {
      var m = range.$1;
      final last = range.$2;
      while (!m.isAfter(last)) {
        final carryThis = <String, int>{};

        for (final cfg in slices.values) {
          if (cfg.createdMonth.isAfter(m)) {
            continue;
          }
          final spentKey = '${cfg.sliceId}|${m.toKey()}';
          if (cfg.isGroup) {
            final eff = cfg.baseEffectiveLimitCents;
            final spent = groupSpent[spentKey] ?? 0;
            final leftover = spent < eff ? eff - spent : 0;
            final overspend = spent > eff ? spent - eff : 0;
            // Group leftovers flow fully to the chest, but only once the month
            // has closed; the current, open month is still provisional.
            if (_isClosed(m)) {
              _addChest(leftover, m);
            }
            sliceMonths[HouseholdState.monthKey(cfg.sliceId, m)] = SliceMonth(
              sliceId: cfg.sliceId,
              month: m,
              isGroup: true,
              ownerUserId: null,
              effectiveLimitCents: eff,
              spentCents: spent,
              leftoverCents: leftover,
              carryInCents: 0,
              carryOutCents: 0,
              overspendCents: overspend,
              resolved: _isClosed(m),
            );
          } else {
            final owner = cfg.ownerUserId!;
            final carryIn = carryPrev[cfg.sliceId] ?? 0;
            final eff = cfg.baseEffectiveLimitCents + carryIn;
            final spent = personalSpent[spentKey] ?? 0;
            final leftover = spent < eff ? eff - spent : 0;
            final overspend = spent > eff ? spent - eff : 0;

            final alloc =
                allocations['$owner|${cfg.sliceId}|${m.toKey()}'];
            final graceDeadline =
                m.endInstantUtc().add(Duration(days: settings.spoilsGraceDays));

            List<Allocation> effective;
            var resolved = true;
            if (alloc != null) {
              effective = alloc.allocations;
            } else if (now.isAfter(graceDeadline)) {
              effective = leftover > 0
                  ? [
                      Allocation(
                        destination: cfg.defaultLeftoverPolicy,
                        amountCents: leftover,
                      ),
                    ]
                  : const [];
            } else {
              effective = const [];
              resolved = false;
            }

            if (resolved) {
              for (final a in effective) {
                final dest = a.destination;
                switch (dest) {
                  case CarryInSlice():
                    carryThis[cfg.sliceId] =
                        (carryThis[cfg.sliceId] ?? 0) + a.amountCents;
                  case QuestDestination():
                    questBalance[dest.questId] =
                        (questBalance[dest.questId] ?? 0) + a.amountCents;
                    final c = questContrib.putIfAbsent(dest.questId, () => {});
                    c[owner] = (c[owner] ?? 0) + a.amountCents;
                  case Discretionary():
                    final t = Money.titheCents(a.amountCents, cfg.poolTithePct);
                    _addChest(t.titheCents, m);
                    _addVault(owner, t.remainderCents);
                }
              }
            }

            sliceMonths[HouseholdState.monthKey(cfg.sliceId, m)] = SliceMonth(
              sliceId: cfg.sliceId,
              month: m,
              isGroup: false,
              ownerUserId: owner,
              effectiveLimitCents: eff,
              spentCents: spent,
              leftoverCents: leftover,
              carryInCents: carryIn,
              carryOutCents: carryThis[cfg.sliceId] ?? 0,
              overspendCents: overspend,
              resolved: resolved,
            );
          }

          // Emergency-contribution schedule (accrues off the top every active
          // month that has already started, regardless of spending). Months
          // whose start instant is still in the future — reached only because
          // the sweep extends to a recurring expense's future endMonth or a
          // future-dated purchase — must not accrue yet.
          if (cfg.emergencyFundId != null &&
              cfg.emergencyContributionCents > 0 &&
              !m.startInstantUtc().isAfter(now)) {
            fundSchedule.putIfAbsent(cfg.emergencyFundId!, () => []).add(
                  _FundContribution(
                    m.startInstantUtc(),
                    cfg.emergencyContributionCents,
                    m,
                  ),
                );
          }
        }

        // Recurring-expense burden for this month.
        for (final r in recurringCfg.values) {
          final active = !r.startMonth.isAfter(m) &&
              (r.endMonth == null || !m.isAfter(r.endMonth!));
          if (!active) {
            continue;
          }
          final amount = r.kind == RecurringKind.variable
              ? (variableActuals['${r.expenseId}|${m.toKey()}'] ?? r.amountCents)
              : r.amountCents;
          final own = r.ownership;
          if (own is PersonalParty) {
            final k = HouseholdState.monthKey(own.userId, m);
            recurringByUserMonth[k] = (recurringByUserMonth[k] ?? 0) + amount;
          } else {
            // Shared: split by the adults' share table for this month,
            // deterministically (largest remainder — there is no purchaser).
            final parts = _splitShares(amount, _sharesFor(m));
            parts.forEach((adult, amt) {
              final k = HouseholdState.monthKey(adult, m);
              recurringByUserMonth[k] = (recurringByUserMonth[k] ?? 0) + amt;
            });
          }
        }

        // Debt minimum payments: shared, ongoing every swept month.
        for (final d in derivedRecurring) {
          final parts = _splitShares(d.amountCents, _sharesFor(m));
          parts.forEach((adult, amt) {
            final k = HouseholdState.monthKey(adult, m);
            recurringByUserMonth[k] = (recurringByUserMonth[k] ?? 0) + amt;
          });
        }

        carryPrev
          ..clear()
          ..addAll(carryThis);
        m = m.next();
      }
    }

    // Gifts credit vaults, untithed.
    for (final g in gifts) {
      _addVault(g.forUserId, g.amountCents);
    }

    // Pool contributions: vault -> war chest.
    for (final c in contributions) {
      _addVault(c.fromUserId, -c.amountCents);
      _addChest(c.amountCents, c.occurredMonth);
    }

    // Tax refunds -> war chest.
    for (final t in taxRefunds) {
      _addChest(t.amountCents, t.occurredMonth);
    }

    // Withdrawals.
    final withdrawals = <String, WithdrawalProposal>{};
    for (final entry in proposals.entries) {
      final prop = entry.value;
      var status = WithdrawalStatus.pending;
      String? approvedBy;
      Month? approvedMonth;
      if (cancelledProposals.contains(prop.proposalId)) {
        status = WithdrawalStatus.cancelled;
      } else if (_adultIds().length <= 1) {
        // Single-adult household: "another adult" is auto-satisfied.
        status = WithdrawalStatus.approved;
        approvedBy = prop.byUserId;
        approvedMonth = prop.occurredMonth;
      } else {
        // A DIFFERENT adult must sign; self-approval and non-adults don't count.
        final valid = (approvals[prop.proposalId] ?? [])
            .where((a) => a.byUserId != prop.byUserId && _isAdult(a.byUserId))
            .toList();
        if (valid.isNotEmpty) {
          status = WithdrawalStatus.approved;
          approvedBy = valid.first.byUserId;
          approvedMonth = valid.first.occurredMonth;
        }
      }
      if (status == WithdrawalStatus.approved) {
        _addChest(-prop.amountCents, approvedMonth!);
        final dest = prop.destination;
        if (dest is UserVaultDestination) {
          _addVault(dest.userId, prop.amountCents);
        }
      }
      withdrawals[prop.proposalId] = WithdrawalProposal(
        proposalId: prop.proposalId,
        byUserId: prop.byUserId,
        amountCents: prop.amountCents,
        purpose: prop.purpose,
        destination: prop.destination,
        status: status,
        approvedByUserId: approvedBy,
      );
    }

    // Quests: apply drawdowns, completion, and abandonment.
    final questStates = <String, QuestState>{};
    for (final cfg in questCfg.values) {
      final funded = questBalance[cfg.questId] ?? 0;
      final drawn = questDrawdown[cfg.questId] ?? 0;
      var balance = funded - drawn;
      if (balance < 0) {
        balance = 0;
      }
      final contrib = Map<String, int>.from(questContrib[cfg.questId] ?? {});
      final totalContrib = contrib.values.fold(0, (a, x) => a + x);
      final completed = totalContrib >= cfg.targetCents && cfg.targetCents > 0;
      final abandoned = abandonedQuests.contains(cfg.questId);

      if (abandoned && balance > 0) {
        final tithe =
            Money.titheCents(balance, settings.dissolutionTithePct).titheCents;
        // Attribute the dissolution tithe to the abandonment month.
        final abandonMonth = _abandonMonth(cfg.questId);
        _addChest(tithe, abandonMonth);
        final distributable = balance - tithe;
        final shares = _proportional(distributable, contrib);
        shares.forEach(_addVault);
        balance = 0;
      }

      questStates[cfg.questId] = QuestState(
        questId: cfg.questId,
        name: cfg.name,
        targetCents: cfg.targetCents,
        ownership: cfg.ownership,
        balanceCents: balance,
        contributions: contrib,
        completed: completed,
        abandoned: abandoned,
        sliceHint: cfg.sliceHint,
        customSpriteSha256: cfg.customSpriteSha256,
      );
    }

    // Emergency funds and ransacks (chronological per fund).
    final fundStates = <String, EmergencyFundState>{};
    final allFundIds = {...fundCfg.keys, ...fundSchedule.keys};
    for (final e in emergencyPurchases) {
      allFundIds.add((e.target as EmergencyCharge).fundId);
    }
    for (final fundId in allFundIds) {
      final items = <_FundTimelineItem>[
        ...(fundSchedule[fundId] ?? [])
            .map((c) => _FundTimelineItem.contribution(c.instant, c.amount)),
        ...emergencyPurchases
            .where((e) => (e.target as EmergencyCharge).fundId == fundId)
            .map(_FundTimelineItem.purchase),
      ]..sort();

      var running = 0;
      for (final item in items) {
        if (item.isContribution) {
          running += item.amount;
        } else {
          final purchase = item.purchase!;
          if (purchase.amountCents <= running) {
            running -= purchase.amountCents;
          } else {
            final excess = purchase.amountCents - running;
            running = 0;
            ransacks.add(RansackRecord(
              fundId: fundId,
              excessCents: excess,
              purpose: purchase.note ?? purchase.merchant ?? '',
              occurredAt: purchase.occurredAt,
            ));
            _addChest(-excess, purchase.occurredMonth);
          }
        }
      }

      final cfg = fundCfg[fundId];
      fundStates[fundId] = EmergencyFundState(
        fundId: fundId,
        name: cfg?.name ?? fundId,
        balanceCents: running,
        petId: cfg?.petId,
      );
    }

    // Clamp vaults at zero, flagging inconsistencies.
    final vaultOut = <String, int>{};
    final inconsistent = <String>{};
    for (final entry in vault.entries) {
      if (entry.value < 0) {
        inconsistent.add(entry.key);
        vaultOut[entry.key] = 0;
      } else {
        vaultOut[entry.key] = entry.value;
      }
    }

    // Members. Legacy PetSet events reduce as pet members; an explicit
    // MemberSet with the same id (last writer) overrides.
    final members = <String, MemberState>{};
    for (final p in petCfg.values) {
      members[p.petId] = MemberState(
        memberId: p.petId,
        name: p.name,
        role: MemberRole.pet,
        active: true,
        customSpriteSha256: p.customSpriteSha256,
      );
    }
    for (final m in memberCfg.values) {
      members[m.memberId] = MemberState(
        memberId: m.memberId,
        name: m.name,
        role: m.role,
        active: m.active,
        customSpriteSha256: m.customSpriteSha256,
        descriptionText: m.descriptionText,
      );
    }

    // Pets are the active pet-role members (the display-level party pets).
    final pets = <String, PetState>{
      for (final m in members.values)
        if (m.role == MemberRole.pet && m.active)
          m.memberId: PetState(
            petId: m.memberId,
            name: m.name,
            customSpriteSha256: m.customSpriteSha256,
          ),
    };

    // Net worth. Every account with either a config declaration or at least one
    // recorded balance surfaces. Savings/debt accrue interest since the last
    // recording; investments are never auto-changed but go stale past their
    // update cadence. Transfers adjust the balance from the last recording.
    final accountIds = <String>{...accountCfg.keys, ...accounts.keys};
    final transfersByAccount = <String, List<AccountTransferRecorded>>{};
    for (final t in accountTransfers) {
      transfersByAccount.putIfAbsent(t.accountId, () => []).add(t);
    }
    final accountBalances = <String, AccountBalance>{};
    for (final id in accountIds) {
      final cfg = accountCfg[id];
      final rec = accounts[id];
      // Config wins for name/kind; fall back to the latest balance's inline
      // fields (legacy AccountBalanceRecorded carried both).
      final kind = cfg?.kind ?? rec?.kind ?? AccountKind.savings;
      final name = cfg?.name ?? rec?.accountName ?? id;
      final recordedCents = rec?.balanceCents ?? 0;
      final recordedAt = rec?.occurredAt;

      // Transfers after the last recording adjust the base value.
      var netTransfers = 0;
      for (final t in transfersByAccount[id] ?? const <AccountTransferRecorded>[]) {
        if (recordedAt == null || t.occurredAt.isAfter(recordedAt)) {
          netTransfers += t.direction == TransferDirection.deposit
              ? t.amountCents
              : -t.amountCents;
        }
      }
      final base = recordedCents + netTransfers;

      final interest = kind == AccountKind.investment
          ? 0
          : _accruedInterest(base, cfg?.aprBps, cfg?.accrualCadence, recordedAt);
      final stale = kind == AccountKind.investment &&
          _isStale(cfg?.updateCadence, recordedAt);

      accountBalances[id] = AccountBalance(
        accountId: id,
        name: name,
        kind: kind,
        balanceCents: recordedCents,
        currentValueCents: base + interest,
        accruedInterestCents: interest,
        aprBps: cfg?.aprBps,
        accrualCadence: cfg?.accrualCadence,
        updateCadence: cfg?.updateCadence,
        minPaymentCents: cfg?.minPaymentCents,
        lastRecordedAt: recordedAt,
        stale: stale,
      );
    }
    final netWorthTotal =
        accountBalances.values.fold(0, (a, x) => a + x.signedCents);
    final netWorth = NetWorthState(
      accounts: accountBalances,
      totalCents: netWorthTotal,
      show: settings.showNetWorth,
    );

    // Tax-deductible list per calendar year.
    final deductibleByYear = <int, List<DeductiblePurchase>>{};
    for (final acc in purchases.values) {
      if (acc.voided) {
        continue;
      }
      final e = acc.event;
      final target = e.target;
      final sliceCfg = target is SliceCharge ? slices[target.sliceId] : null;
      final sliceDefault = sliceCfg?.taxDeductibleByDefault ?? false;
      final effective = e.taxDeductible ?? sliceDefault;
      if (!effective) {
        continue;
      }
      final year = e.occurredMonth.year;
      deductibleByYear.putIfAbsent(year, () => []).add(DeductiblePurchase(
            purchaseId: e.purchaseId,
            userId: e.userId,
            sliceName: sliceCfg?.name ?? _targetLabel(target),
            amountCents: e.amountCents,
            shared: e.shared,
            occurredAt: e.occurredAt,
            receiptShas: acc.receipts.keys.toList(),
            merchant: e.merchant,
            note: e.note,
          ));
    }

    // War chest goal progress.
    GoalProgress? goal;
    if (goalTarget != null && range != null) {
      final target = goalTarget!;
      final remaining = warChest < target ? target - warChest : 0;
      final asOfMonth = Month.fromInstant(now);
      final trailing = [
        asOfMonth,
        asOfMonth.prev(),
        asOfMonth.prev().prev(),
      ];
      final sum = trailing.fold(
        0,
        (a, mm) => a + (chestMonthlyNet[mm.toKey()] ?? 0),
      );
      final avg = sum / 3.0;
      goal = GoalProgress(
        targetCents: target,
        pctComplete: target == 0 ? 1.0 : warChest / target,
        remainingCents: remaining,
        avgNetInflowCents: avg,
        estMonthsRemaining: avg > 0 ? remaining / avg : null,
      );
    }

    final purchaseStates = <String, PurchaseState>{
      for (final acc in purchases.values)
        acc.event.purchaseId: PurchaseState(
          purchaseId: acc.event.purchaseId,
          userId: acc.event.userId,
          target: acc.event.target,
          amountCents: acc.event.amountCents,
          month: acc.event.occurredMonth,
          occurredAt: acc.event.occurredAt,
          shared: acc.event.shared,
          voided: acc.voided,
          receipts: acc.receipts.values.toList(),
          merchant: acc.event.merchant,
          taxDeductible: acc.event.taxDeductible,
          note: acc.event.note,
        ),
    };

    // Main categories: seed the documented defaults, then apply any
    // MainCategorySet overrides/additions (last-writer-wins by id).
    final mainCategories = <String, MainCategory>{
      for (final d in defaultMainCategories) d.id: d,
    };
    for (final e in mainCategoryCfg.values) {
      mainCategories[e.id] = MainCategory(
        id: e.id,
        name: e.name,
        colorArgb: e.colorArgb,
        sortOrder: e.sortOrder,
      );
    }

    // Default incomes per user, sorted ascending by the month they take effect.
    final incomeDefaultsByUser = <String, List<DefaultIncome>>{};
    for (final d in defaultIncomeCfg.values) {
      incomeDefaultsByUser.putIfAbsent(d.forUserId, () => []).add(
            DefaultIncome(
              effectiveFromMonth: d.effectiveFromMonth,
              amountCents: d.amountCents,
            ),
          );
    }
    for (final list in incomeDefaultsByUser.values) {
      list.sort((a, b) => a.effectiveFromMonth.compareTo(b.effectiveFromMonth));
    }

    return HouseholdState(
      settings: settings,
      userIds: userIds,
      members: members,
      mainCategories: mainCategories,
      slices: slices,
      sliceMonths: sliceMonths,
      quests: questStates,
      emergencyFunds: fundStates,
      pets: pets,
      withdrawals: withdrawals,
      warChest: WarChestState(
        balanceCents: warChest,
        targetCents: goalTarget,
        goal: goal,
      ),
      vaultCents: vaultOut,
      inconsistentVaults: inconsistent,
      ransacks: ransacks,
      purchases: purchaseStates,
      netWorth: netWorth,
      deductibleByYear: deductibleByYear,
      recurringByUserMonth: recurringByUserMonth,
      incomeByUserMonth: income,
      incomeDefaultsByUser: incomeDefaultsByUser,
      recurringExpenses: {
        for (final r in recurringCfg.values)
          r.expenseId: RecurringExpenseState(
            expenseId: r.expenseId,
            name: r.name,
            ownership: r.ownership,
            kind: r.kind,
            amountCents: r.amountCents,
            startMonth: r.startMonth,
            endMonth: r.endMonth,
          ),
        // Debt minimum payments as read-only shared fixed recurring expenses.
        for (final d in derivedRecurring)
          d.expenseId: RecurringExpenseState(
            expenseId: d.expenseId,
            name: d.name,
            ownership: const SharedParty(),
            kind: RecurringKind.fixed,
            amountCents: d.amountCents,
            startMonth: range?.$1 ?? Month.fromInstant(now),
          ),
      },
      variableActuals: Map<String, int>.from(variableActuals),
    );
  }

  String _targetLabel(ChargeTarget t) => switch (t) {
        SliceCharge() => t.sliceId,
        VaultCharge() => 'vault',
        QuestCharge() => t.questId,
        EmergencyCharge() => t.fundId,
      };

  Month _abandonMonth(String questId) {
    // The abandonment occurredMonth was captured on the QuestAbandoned event;
    // fall back to the asOf month if unavailable.
    final at = _abandonInstants[questId];
    return at != null ? Month.fromInstant(at) : Month.fromInstant(now);
  }

  final Map<String, DateTime> _abandonInstants = {};

  /// Splits [amount] across recipients proportionally to their [weights],
  /// using largest-remainder so the parts sum exactly to [amount].
  Map<String, int> _proportional(int amount, Map<String, int> weights) {
    final totalWeight = weights.values.fold(0, (a, b) => a + b);
    if (amount <= 0 || totalWeight <= 0) {
      return {for (final k in weights.keys) k: 0};
    }
    final base = <String, int>{};
    final remainders = <String, int>{}; // numerator of the fractional part
    var assigned = 0;
    for (final entry in weights.entries) {
      final numerator = amount * entry.value;
      final share = numerator ~/ totalWeight;
      base[entry.key] = share;
      remainders[entry.key] = numerator % totalWeight;
      assigned += share;
    }
    var leftover = amount - assigned;
    final order = weights.keys.toList()
      ..sort((a, b) {
        final c = remainders[b]!.compareTo(remainders[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    for (final k in order) {
      if (leftover <= 0) {
        break;
      }
      base[k] = base[k]! + 1;
      leftover--;
    }
    return base;
  }

  /// The inclusive month range to sweep, or null when there are no anchors.
  (Month, Month)? _monthRange() {
    Month? min;
    Month? max;
    void consider(Month m) {
      if (min == null || m.isBefore(min!)) {
        min = m;
      }
      if (max == null || m.isAfter(max!)) {
        max = m;
      }
    }

    for (final acc in purchases.values) {
      consider(acc.event.occurredMonth);
    }
    for (final cfg in slices.values) {
      consider(cfg.createdMonth);
    }
    for (final r in recurringCfg.values) {
      consider(r.startMonth);
      if (r.endMonth != null) {
        consider(r.endMonth!);
      }
    }
    for (final a in allocations.values) {
      consider(a.month);
    }

    final asOfMonth = Month.fromInstant(now);
    // A surfaced debt minimum payment anchors the sweep at the current month so
    // it enters the plan even with no budget categories yet.
    if (derivedRecurring.isNotEmpty) {
      consider(asOfMonth);
    }
    if (min == null) {
      return null;
    }
    consider(asOfMonth); // ensure we sweep up to (at least) the current month
    return (min!, max!);
  }
}

/// A recurring expense derived from a tracked account (a debt's minimum
/// payment), rather than from a `RecurringExpenseSet` event.
class _DerivedRecurring {
  _DerivedRecurring({
    required this.expenseId,
    required this.name,
    required this.amountCents,
  });

  final String expenseId;
  final String name;
  final int amountCents;
}

/// Accumulates a purchase and its live receipt references.
class _PurchaseAcc {
  _PurchaseAcc(this.event);

  final PurchaseAdded event;
  bool voided = false;
  final Map<String, ReceiptRef> receipts = {};
}

/// A scheduled monthly emergency-fund contribution.
class _FundContribution {
  _FundContribution(this.instant, this.amount, this.month);

  final DateTime instant;
  final int amount;
  final Month month;
}

/// A merged item on a fund's contribution/spend timeline. Contributions sort
/// before purchases at the same instant so a same-month contribution funds a
/// purchase before it can ransack the war chest.
class _FundTimelineItem implements Comparable<_FundTimelineItem> {
  _FundTimelineItem.contribution(this.instant, this.amount)
      : isContribution = true,
        purchase = null;

  _FundTimelineItem.purchase(PurchaseAdded p)
      : isContribution = false,
        instant = p.occurredAt,
        amount = p.amountCents,
        purchase = p;

  final DateTime instant;
  final int amount;
  final bool isContribution;
  final PurchaseAdded? purchase;

  @override
  int compareTo(_FundTimelineItem other) {
    final c = instant.compareTo(other.instant);
    if (c != 0) {
      return c;
    }
    if (isContribution == other.isContribution) {
      return 0;
    }
    return isContribution ? -1 : 1;
  }
}
