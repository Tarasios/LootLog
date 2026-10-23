part of '../state.dart';

/// Derived configuration of a recurring expense ("equipment maintenance").
/// Exposed on the read-model so the dashboard's equipment-maintenance summary
/// and the spoils ritual's variable-actual step read it from the reducer rather
/// than re-deriving it from the event log.
class RecurringExpenseState {
  const RecurringExpenseState({
    required this.expenseId,
    required this.name,
    required this.ownership,
    required this.kind,
    required this.amountCents,
    required this.startMonth,
    this.endMonth,
    this.cadence = RecurringCadence.monthly,
    this.dueDay = 1,
    this.dueMonth,
    this.reserveCents = 0,
    this.lastReconciliation,
  });

  final String expenseId;
  final String name;
  final PartyOwnership ownership;
  final RecurringKind kind;

  /// The fixed amount, or the estimate for a variable expense. For an annual
  /// expense this is the full annual figure (accrued 1/12 monthly).
  final int amountCents;
  final Month startMonth;
  final Month? endMonth;

  /// Monthly (full amount each month) or annual (1/12 accrued monthly).
  final RecurringCadence cadence;

  /// Day of the month the bill is due (clamped to the month's length).
  final int dueDay;

  /// For an annual expense, the calendar month (1..12) it comes due; null for
  /// monthly expenses.
  final int? dueMonth;

  /// The reserve accrued toward an annual expense as of the read-time month
  /// (money set aside since the last due month). Always 0 for monthly.
  final int reserveCents;

  /// The most recent due-month reconciliation for an annual expense at or
  /// before the read-time month, or null when none has occurred yet.
  final AnnualDueReconciliation? lastReconciliation;

  bool get isShared => ownership is SharedParty;

  bool get isAnnual => cadence == RecurringCadence.annual;

  String? get ownerUserId =>
      ownership is PersonalParty ? (ownership as PersonalParty).userId : null;

  /// Whether this expense is expected to run in [month].
  bool activeIn(Month month) =>
      !startMonth.isAfter(month) &&
      (endMonth == null || !month.isAfter(endMonth!));

  /// The next due date at or after [from], in the household-local calendar,
  /// clamped to each month's length (so a `dueDay` of 31 lands on the last day).
  DateTime nextDueDate(DateTime from) {
    final fromDay = DateTime(from.year, from.month, from.day);
    int lastDay(int year, int monthNumber) =>
        DateTime(year, monthNumber + 1, 0).day;
    DateTime forMonth(int year, int monthNumber) => DateTime(
      year,
      monthNumber,
      dueDay > lastDay(year, monthNumber) ? lastDay(year, monthNumber) : dueDay,
    );
    if (isAnnual && dueMonth != null) {
      var candidate = forMonth(fromDay.year, dueMonth!);
      if (candidate.isBefore(fromDay)) {
        candidate = forMonth(fromDay.year + 1, dueMonth!);
      }
      return candidate;
    }
    var candidate = forMonth(fromDay.year, fromDay.month);
    if (candidate.isBefore(fromDay)) {
      final nextYear = fromDay.month == 12 ? fromDay.year + 1 : fromDay.year;
      final nextMonthNumber = fromDay.month == 12 ? 1 : fromDay.month + 1;
      candidate = forMonth(nextYear, nextMonthNumber);
    }
    return candidate;
  }

  /// Whole days from [from] to the next due date (0 when due today).
  int daysUntilDue(DateTime from) => nextDueDate(
    from,
  ).difference(DateTime(from.year, from.month, from.day)).inDays;
}

/// The reconciliation of an annual expense in its due month: the real amount is
/// applied against the reserve accumulated that far. A positive [deltaCents] is
/// a surplus (over-reserved), a negative one a shortfall (under-reserved,
/// typically a partial first year).
class AnnualDueReconciliation {
  const AnnualDueReconciliation({
    required this.month,
    required this.dueAmountCents,
    required this.reserveBeforeCents,
  });

  final Month month;
  final int dueAmountCents;

  /// The reserve balance the instant before the bill was applied.
  final int reserveBeforeCents;

  int get deltaCents => reserveBeforeCents - dueAmountCents;

  int get shortfallCents => deltaCents < 0 ? -deltaCents : 0;

  int get surplusCents => deltaCents > 0 ? deltaCents : 0;
}

/// A user's default monthly income, effective from [effectiveFromMonth] and
/// carried forward until a later default supersedes it.
class DefaultIncome {
  const DefaultIncome({
    required this.effectiveFromMonth,
    required this.amountCents,
    this.estimatedHighCents,
  });

  final Month effectiveFromMonth;

  /// The planning figure — the low end of the range for a variable earner.
  final int amountCents;

  /// The optimistic top of an estimated range (display only), or null for a
  /// fixed salary.
  final int? estimatedHighCents;

  bool get isRange =>
      estimatedHighCents != null && estimatedHighCents! > amountCents;
}
