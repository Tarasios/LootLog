part of '../reducer.dart';

/// Inputs and running state shared by every month of the chronological sweep.
class _SweepContext {
  _SweepContext({
    required this.rules,
    required this.spending,
    required this.questCoversBySliceMonth,
    required this.sortedSlices,
  });

  final SavingsRules? rules;
  final _PurchaseSpending spending;

  /// Category-savings covers on quest purchases, keyed "sliceId|yyyy-MM".
  final Map<String, List<_QuestSavingsCover>> questCoversBySliceMonth;

  /// Every category, in sliceId order.
  final List<SliceConfig> sortedSlices;

  /// sliceId -> legacy carry into the month being swept.
  final Map<String, int> carryIntoMonth = {};

  /// Emergency-fund contributions accrued so far, per fundId.
  final Map<String, List<_FundContribution>> fundSchedule = {};
}

/// One personal category's figures for one swept month, buffered between the
/// sweep's phases (locks -> close settlement -> ritual allocations).
class _PersonalCategoryMonth {
  _PersonalCategoryMonth(
    this.config,
    this.ownerId,
    this.carryIn,
    this.locked,
    this.effectiveLimit,
    this.spent,
    this.leftover,
    this.overspend, {
    this.fromSavings = 0,
    this.savingsAfter = 0,
    this.savingsTaxPaid = 0,
    this.covered = 0,
    this.trimmed = 0,
    this.underSavingsRules = false,
  });

  final SliceConfig config;
  final String ownerId;
  final int carryIn;
  final int locked;
  final int effectiveLimit;
  final int spent;
  final int leftover;
  final int overspend;

  // Savings rules only.
  final int fromSavings;
  final int savingsAfter;
  final int savingsTaxPaid;
  final int covered;
  final int trimmed;
  final bool underSavingsRules;
}

/// The chronological month sweep: category figures and locks, close-time
/// settlement, the spoils ritual, the recurring burden and the
/// emergency-contribution schedule, month by month.
extension _MonthSweep on _HouseholdStateBuilder {
  /// The inclusive month range to sweep, or null when there are no anchors.
  (Month, Month)? _monthRange() {
    Month? earliest;
    Month? latest;
    void consider(Month month) {
      if (earliest == null || month.isBefore(earliest!)) {
        earliest = month;
      }
      if (latest == null || month.isAfter(latest!)) {
        latest = month;
      }
    }

    for (final accumulator in purchases.values) {
      consider(accumulator.event.occurredMonth);
    }
    for (final config in slices.values) {
      consider(config.createdMonth);
    }
    for (final expense in recurringConfigs.values) {
      consider(expense.startMonth);
      if (expense.endMonth != null) {
        consider(expense.endMonth!);
      }
    }
    for (final allocation in allocations.values) {
      consider(allocation.month);
    }
    for (final proposal in advanceProposals.values) {
      consider(proposal.occurredMonth);
    }

    final asOfMonth = Month.fromInstant(now);
    // A surfaced debt minimum payment anchors the sweep at the current month so
    // it enters the plan even with no budget categories yet.
    if (derivedRecurring.isNotEmpty) {
      consider(asOfMonth);
    }
    if (earliest == null) {
      return null;
    }
    consider(asOfMonth); // ensure we sweep up to (at least) the current month
    return (earliest!, latest!);
  }

  /// Sweeps every month in [range] in order and returns the emergency-fund
  /// contribution schedule it accrued.
  Map<String, List<_FundContribution>> _sweepMonths(
    (Month, Month) range,
    _SweepContext sweep,
  ) {
    var month = range.$1;
    final last = range.$2;
    while (!month.isAfter(last)) {
      _sweepMonth(month, sweep);
      month = month.next();
    }
    return sweep.fundSchedule;
  }

  void _sweepMonth(Month month, _SweepContext sweep) {
    final carryOut = <String, int>{};
    final closed = _isClosed(month);

    // This month's external vault flows enter the availability model.
    (vaultFlowByMonth[month.toKey()] ?? const {}).forEach((userId, cents) {
      availableVault[userId] = (availableVault[userId] ?? 0) + cents;
    });

    final figures = _figureCategories(month, closed, sweep);
    if (closed) {
      _seizeOverspendAtClose(figures);
    }
    _resolveSpoils(month, figures, sweep.rules, carryOut);
    _chargeRecurringForMonth(month, sweep.rules);

    sweep.carryIntoMonth
      ..clear()
      ..addAll(carryOut);
  }

  /// Phase 1: per-category figures. An outstanding OVERBUDGET debt locks the
  /// category: its funding is withheld to cover the debt (effective limit
  /// shrinks, to zero if needed) and pays it immediately — but only once this
  /// month's ritual window (start + grace days) has passed, so during the
  /// ritual the monster stands at full HP for leftovers to attack, and
  /// afterwards the withheld funding fells it on its own. Group categories
  /// settle here; personal figures are returned for the later phases.
  List<_PersonalCategoryMonth> _figureCategories(
    Month month,
    bool closed,
    _SweepContext sweep,
  ) {
    final lockGate = month.startInstantUtc().add(
      Duration(days: settings.spoilsGraceDays),
    );
    final lockActive = now.isAfter(lockGate);
    final figures = <_PersonalCategoryMonth>[];
    for (final config in sweep.sortedSlices) {
      if (config.createdMonth.isAfter(month)) {
        continue;
      }
      if (config.isGroup) {
        _settleGroupCategory(config, month, closed, sweep.spending);
      } else {
        figures.add(_figurePersonalCategory(config, month, lockActive, sweep));
      }
      _scheduleEmergencyContribution(config, month, sweep.fundSchedule);
    }
    return figures;
  }

  /// Group leftovers flow fully to the chest — and a group overflow draws
  /// straight back out of it — but only once the month has closed; the
  /// current, open month is still provisional.
  void _settleGroupCategory(
    SliceConfig config,
    Month month,
    bool closed,
    _PurchaseSpending spending,
  ) {
    final effectiveLimit = config.baseEffectiveLimitCents;
    final spent =
        spending.groupSpent['${config.sliceId}|${month.toKey()}'] ?? 0;
    final leftover = spent < effectiveLimit ? effectiveLimit - spent : 0;
    final overspend = spent > effectiveLimit ? spent - effectiveLimit : 0;
    if (closed) {
      _addChest(leftover - overspend, month);
    }
    sliceMonths[HouseholdState.monthKey(config.sliceId, month)] = SliceMonth(
      sliceId: config.sliceId,
      month: month,
      isGroup: true,
      ownerUserId: null,
      effectiveLimitCents: effectiveLimit,
      spentCents: spent,
      leftoverCents: leftover,
      carryInCents: 0,
      carryOutCents: 0,
      overspendCents: overspend,
      resolved: closed,
    );
  }

  /// A personal category's funding (carry, advance trims and debt lock
  /// applied) and spend for [month]. Under the savings rules, spending draws
  /// the allowance first, then the category's savings; the rest is overspend.
  _PersonalCategoryMonth _figurePersonalCategory(
    SliceConfig config,
    Month month,
    bool lockActive,
    _SweepContext sweep,
  ) {
    final ownerId = config.ownerUserId!;
    final rules = sweep.rules;
    final spentKey = '${config.sliceId}|${month.toKey()}';
    final underSavingsRules = rules != null && rules.appliesTo(month);
    final carryIn = (!underSavingsRules || month == rules.fromMonth)
        ? (sweep.carryIntoMonth[config.sliceId] ?? 0)
        : 0;
    final trimmed = underSavingsRules
        ? _takeAdvanceTrim(config, month, carryIn)
        : 0;
    final funding = config.baseEffectiveLimitCents + carryIn - trimmed;
    final outstanding = lockActive ? (debtBySlice[config.sliceId] ?? 0) : 0;
    final lockable = funding > 0 ? funding : 0;
    final locked = outstanding < lockable ? outstanding : lockable;
    if (locked > 0) {
      debtBySlice[config.sliceId] = outstanding - locked;
    }
    final effectiveLimit = funding - locked;
    final rawSpent = sweep.spending.personalSpent[spentKey] ?? 0;
    if (!underSavingsRules) {
      final leftover = rawSpent < effectiveLimit
          ? effectiveLimit - rawSpent
          : 0;
      final overspend = rawSpent > effectiveLimit
          ? rawSpent - effectiveLimit
          : 0;
      return _PersonalCategoryMonth(
        config,
        ownerId,
        carryIn,
        locked,
        effectiveLimit,
        rawSpent,
        leftover,
        overspend,
      );
    }

    final covered = coverBySliceMonth[spentKey] ?? 0;
    final spentNet = rawSpent > covered ? rawSpent - covered : 0;
    final fromAllowance = spentNet < effectiveLimit ? spentNet : effectiveLimit;
    _coverQuestsFromCategorySavings(
      config,
      ownerId,
      month,
      rules,
      sweep.questCoversBySliceMonth[spentKey] ?? const <_QuestSavingsCover>[],
    );

    var pool = savings[config.sliceId] ?? TaxedBalance.zero;
    final wanted = spentNet - fromAllowance;
    final fromSavings = wanted < pool.balanceCents ? wanted : pool.balanceCents;
    pool = spendFrom(pool, fromSavings);
    savings[config.sliceId] = pool;
    return _PersonalCategoryMonth(
      config,
      ownerId,
      carryIn,
      locked,
      effectiveLimit,
      rawSpent,
      effectiveLimit - fromAllowance,
      spentNet - fromAllowance - fromSavings,
      fromSavings: fromSavings,
      savingsAfter: pool.balanceCents,
      savingsTaxPaid: pool.taxPaidCents,
      covered: covered,
      trimmed: trimmed,
      underSavingsRules: true,
    );
  }
}
