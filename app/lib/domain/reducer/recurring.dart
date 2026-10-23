part of '../reducer.dart';

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

/// Recurring expenses ("equipment maintenance"): the monthly off-the-top
/// burden per adult, annual accrual reserves, variable-bill variance and the
/// debt minimum payments surfaced from tracked accounts.
extension _RecurringExpenses on _HouseholdStateBuilder {
  /// A debt's minimum payment surfaces automatically as a shared recurring
  /// expense — the single, reminder-only crossover where a tracked account
  /// touches the monthly plan (it never enters category math).
  void _deriveDebtMinimumPayments() {
    for (final config in accountConfigs.values) {
      if (config.kind == AccountKind.debt &&
          (config.minPaymentCents ?? 0) > 0) {
        derivedRecurring.add(
          _DerivedRecurring(
            expenseId: 'debt:${config.accountId}',
            name: '${config.name} — minimum payment',
            amountCents: config.minPaymentCents!,
          ),
        );
      }
    }
  }

  /// Recurring-expense burden for [month]: every active expense, then the
  /// debt minimum payments (shared, ongoing every swept month).
  void _chargeRecurringForMonth(Month month, SavingsRules? rules) {
    for (final expense in recurringConfigs.values) {
      final active =
          !expense.startMonth.isAfter(month) &&
          (expense.endMonth == null || !month.isAfter(expense.endMonth!));
      if (!active) {
        continue;
      }
      final amount = _recurringChargeFor(expense, month, rules);
      final ownership = expense.ownership;
      if (ownership is PersonalParty) {
        _addRecurringBurden(ownership.userId, month, amount);
      } else {
        // Shared: split by the adults' share table for this month,
        // deterministically (largest remainder — there is no purchaser).
        final parts = _splitShares(amount, _sharesFor(month));
        parts.forEach((adultId, shareCents) {
          _addRecurringBurden(adultId, month, shareCents);
        });
      }
    }

    for (final derived in derivedRecurring) {
      final parts = _splitShares(derived.amountCents, _sharesFor(month));
      parts.forEach((adultId, shareCents) {
        _addRecurringBurden(adultId, month, shareCents);
      });
    }
  }

  void _addRecurringBurden(String userId, Month month, int cents) {
    final burdenKey = HouseholdState.monthKey(userId, month);
    recurringByUserMonth[burdenKey] =
        (recurringByUserMonth[burdenKey] ?? 0) + cents;
  }

  /// [expense]'s off-the-top charge in [month]. Annual expenses accrue 1/12
  /// monthly; variable ones use the recorded actual when there is one, and
  /// under the savings rules their estimate-vs-actual difference flows
  /// through savings.
  int _recurringChargeFor(
    RecurringExpenseSet expense,
    Month month,
    SavingsRules? rules,
  ) {
    final actualKey = '${expense.expenseId}|${month.toKey()}';
    if (expense.cadence == RecurringCadence.annual) {
      // Off-the-top burden is 1/12 of the annual amount, with the
      // integer-cents remainder landing in the due month so the twelve
      // charges sum exactly.
      final monthlyBase = expense.amountCents ~/ 12;
      final isDue = expense.dueMonth != null && month.month == expense.dueMonth;
      final amount = monthlyBase + (isDue ? expense.amountCents % 12 : 0);
      // Advance the reserve only for months that have already started;
      // future accruals (reached because the sweep runs past `now`) have
      // not happened yet. The due month reconciles the real amount.
      if (!month.startInstantUtc().isAfter(now)) {
        var reserve = (annualReserveByExpense[expense.expenseId] ?? 0) + amount;
        if (isDue) {
          final dueAmount = variableActuals[actualKey] ?? expense.amountCents;
          annualReconByExpense[expense.expenseId] = AnnualDueReconciliation(
            month: month,
            dueAmountCents: dueAmount,
            reserveBeforeCents: reserve,
          );
          // Pay the bill from the reserve: carry any surplus forward; a
          // shortfall is covered externally and leaves the reserve empty.
          reserve = reserve >= dueAmount ? reserve - dueAmount : 0;
        }
        annualReserveByExpense[expense.expenseId] = reserve;
      }
      return amount;
    }

    final amount = expense.kind == RecurringKind.variable
        ? (variableActuals[actualKey] ?? expense.amountCents)
        : expense.amountCents;
    if (rules != null &&
        rules.appliesTo(month) &&
        expense.kind == RecurringKind.variable &&
        !month.startInstantUtc().isAfter(now)) {
      final actual = variableActuals[actualKey];
      if (actual != null) {
        _applyBillVariance(expense, month, expense.amountCents - actual);
      }
    }
    return amount;
  }

  /// A variable bill's estimate-vs-actual difference flows through savings:
  /// shared bills through the war chest, personal ones through the owner's
  /// general pool; a personal over-run the pool can't cover becomes a
  /// provisions top-up debt (never a monster, never a lock).
  void _applyBillVariance(
    RecurringExpenseSet expense,
    Month month,
    int estimateMinusActual,
  ) {
    if (estimateMinusActual == 0) return;
    final ownership = expense.ownership;
    if (ownership is! PersonalParty) {
      _addChest(estimateMinusActual, month);
      return;
    }
    final ownerId = ownership.userId;
    if (estimateMinusActual > 0) {
      _creditVaultDuringSweep(ownerId, estimateMinusActual);
      return;
    }
    final needed = -estimateMinusActual;
    final available = availableVault[ownerId] ?? 0;
    final usable = available > 0 ? available : 0;
    final taken = needed < usable ? needed : usable;
    if (taken > 0) {
      availableVault[ownerId] = available - taken;
      _addVault(ownerId, -taken);
    }
    final uncovered = needed - taken;
    if (uncovered > 0) {
      final debtKey = 'provisions:${expense.expenseId}';
      _accrueDebt(debtKey, ownerId, uncovered);
      debtKind[debtKey] = DebtKind.provisions;
    }
  }

  /// Every recurring expense's read-model, plus the debt minimum payments as
  /// read-only shared fixed recurring expenses.
  Map<String, RecurringExpenseState> _recurringExpenseStates(
    (Month, Month)? range,
  ) {
    return {
      for (final expense in recurringConfigs.values)
        expense.expenseId: RecurringExpenseState(
          expenseId: expense.expenseId,
          name: expense.name,
          ownership: expense.ownership,
          kind: expense.kind,
          amountCents: expense.amountCents,
          startMonth: expense.startMonth,
          endMonth: expense.endMonth,
          cadence: expense.cadence,
          dueDay: expense.dueDay,
          dueMonth: expense.dueMonth,
          reserveCents: annualReserveByExpense[expense.expenseId] ?? 0,
          lastReconciliation: annualReconByExpense[expense.expenseId],
        ),
      for (final derived in derivedRecurring)
        derived.expenseId: RecurringExpenseState(
          expenseId: derived.expenseId,
          name: derived.name,
          ownership: const SharedParty(),
          kind: RecurringKind.fixed,
          amountCents: derived.amountCents,
          startMonth: range?.$1 ?? Month.fromInstant(now),
        ),
    };
  }
}
