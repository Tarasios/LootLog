part of '../state.dart';

/// Derived state of one category inside a vacation's sub-budget.
class VacationCategoryState {
  const VacationCategoryState({
    required this.categoryId,
    required this.name,
    required this.limitCents,
    required this.spentCents,
  });

  final String categoryId;
  final String name;
  final int limitCents;
  final int spentCents;

  int get leftoverCents =>
      spentCents < limitCents ? limitCents - spentCents : 0;

  int get overspendCents =>
      spentCents > limitCents ? spentCents - limitCents : 0;

  bool get overspent => overspendCents > 0;
}

/// Derived state of a **vacation**: a self-contained sub-budget for a trip,
/// backed by a source fund. Its budget is reserved off the fund while open and
/// the unspent leftover is returned on close, so [fundBalanceCents] reflects the
/// source fund *after* this vacation's reservation. Daily-allowance figures are
/// computed at read time from the trip's calendar bounds and the read instant.
class VacationState {
  const VacationState({
    required this.vacationId,
    required this.name,
    required this.fund,
    required this.startDate,
    required this.endDate,
    required this.closed,
    required this.categories,
    required this.fundBalanceCents,
    required this.reservedFromFundCents,
    required this.daysTotal,
    required this.daysRemaining,
  });

  final String vacationId;
  final String name;
  final VacationFund fund;
  final DateTime startDate;
  final DateTime endDate;
  final bool closed;

  /// Categories in the order they were declared.
  final List<VacationCategoryState> categories;

  /// The source fund's balance after this vacation's reservation is applied.
  final int fundBalanceCents;

  /// What this vacation currently draws off the source fund: the full budget
  /// while open, or the actual total spent once closed (leftover returned).
  final int reservedFromFundCents;

  /// Whole days in the trip, inclusive of both endpoints (at least 1).
  final int daysTotal;

  /// Whole days left in the trip as of the read instant, including today; the
  /// full [daysTotal] before the trip starts, and 0 once it has ended.
  final int daysRemaining;

  bool get isOpen => !closed;

  /// The id of the backing fund (a questId or emergency fundId).
  String get fundSourceId => switch (fund) {
    VacationFundQuest(:final questId) => questId,
    VacationFundEmergency(:final fundId) => fundId,
  };

  int get totalLimitCents =>
      categories.fold(0, (sum, category) => sum + category.limitCents);

  int get totalSpentCents =>
      categories.fold(0, (sum, category) => sum + category.spentCents);

  int get totalLeftoverCents {
    final leftover = totalLimitCents - totalSpentCents;
    return leftover > 0 ? leftover : 0;
  }

  int get totalOverspendCents {
    final overspend = totalSpentCents - totalLimitCents;
    return overspend > 0 ? overspend : 0;
  }

  bool get overspent => totalOverspendCents > 0;

  /// The average daily budget across the whole trip.
  int get dailyAllowanceBaselineCents =>
      daysTotal > 0 ? totalLimitCents ~/ daysTotal : 0;

  /// What remains spendable per day for the rest of the trip: the leftover
  /// budget spread across the days still to come (0 once the trip is over).
  int get dailyAllowanceRemainingCents =>
      daysRemaining > 0 ? totalLeftoverCents ~/ daysRemaining : 0;
}
