part of '../reducer.dart';

/// Vacation mode: self-contained sub-budgets reserved off a quest or an
/// emergency fund.
extension _VacationDerivation on _HouseholdStateBuilder {
  /// Vacation fund reservations. Each vacation reserves off its source fund:
  /// the full declared budget while open, or the actual spend once closed (the
  /// leftover having been returned). Quest-backed reservations draw down the
  /// quest (added to [spending]'s quest drawdown); emergency-backed ones are
  /// returned per fund (fundId -> reserved) and subtracted from the fund
  /// balance later.
  Map<String, int> _reserveVacationFunds(_PurchaseSpending spending) {
    final vacationDrawByFund = <String, int>{};
    for (final vacation in vacationConfigs.values) {
      final reserved = _vacationReservation(vacation, spending);
      switch (vacation.fund) {
        case VacationFundQuest(:final questId):
          spending.questDrawdown[questId] =
              (spending.questDrawdown[questId] ?? 0) + reserved;
        case VacationFundEmergency(:final fundId):
          vacationDrawByFund[fundId] =
              (vacationDrawByFund[fundId] ?? 0) + reserved;
      }
    }
    return vacationDrawByFund;
  }

  /// What [vacation] holds off its fund: the declared budget while open, the
  /// actual spend once closed.
  int _vacationReservation(VacationSet vacation, _PurchaseSpending spending) {
    final budget = vacation.categories.fold(
      0,
      (sum, category) => sum + category.limitCents,
    );
    final spent = spending.vacationTotalSpent[vacation.vacationId] ?? 0;
    return closedVacations.contains(vacation.vacationId) ? spent : budget;
  }

  /// Vacations. Per-category and total spend come from vacation charges; the
  /// backing fund's post-reservation balance is read from the quest / fund
  /// states already computed. Daily-allowance figures derive from the trip's
  /// calendar bounds and the read instant.
  Map<String, VacationState> _vacationStates(
    _PurchaseSpending spending,
    Map<String, QuestState> questStates,
    Map<String, EmergencyFundState> fundStates,
  ) {
    final vacationStates = <String, VacationState>{};
    for (final vacation in vacationConfigs.values) {
      final categories = <VacationCategoryState>[
        for (final category in vacation.categories)
          VacationCategoryState(
            categoryId: category.categoryId,
            name: category.name,
            limitCents: category.limitCents,
            spentCents:
                spending
                    .vacationCategorySpent['${vacation.vacationId}|${category.categoryId}'] ??
                0,
          ),
      ];
      final fundBalance = switch (vacation.fund) {
        VacationFundQuest(:final questId) =>
          questStates[questId]?.balanceCents ?? 0,
        VacationFundEmergency(:final fundId) =>
          fundStates[fundId]?.balanceCents ?? 0,
      };
      final (daysTotal, daysRemaining) = _vacationDays(
        vacation.startDate,
        vacation.endDate,
      );
      vacationStates[vacation.vacationId] = VacationState(
        vacationId: vacation.vacationId,
        name: vacation.name,
        fund: vacation.fund,
        startDate: vacation.startDate,
        endDate: vacation.endDate,
        closed: closedVacations.contains(vacation.vacationId),
        categories: categories,
        fundBalanceCents: fundBalance,
        reservedFromFundCents: _vacationReservation(vacation, spending),
        daysTotal: daysTotal,
        daysRemaining: daysRemaining,
      );
    }
    return vacationStates;
  }

  /// Whole days in a trip and days remaining as of [now]. Both bounds are taken
  /// as calendar dates; the total is inclusive of both endpoints (at least 1),
  /// and the remaining count includes the current day while the trip is live —
  /// the full total before it starts, and 0 once it has ended.
  (int, int) _vacationDays(DateTime start, DateTime end) {
    DateTime dateOnly(DateTime instant) =>
        DateTime.utc(instant.year, instant.month, instant.day);
    final startDate = dateOnly(start);
    final endDate = dateOnly(end);
    final today = dateOnly(now);
    var total = endDate.difference(startDate).inDays + 1;
    if (total < 1) {
      total = 1;
    }
    int remaining;
    if (today.isBefore(startDate)) {
      remaining = total;
    } else if (today.isAfter(endDate)) {
      remaining = 0;
    } else {
      remaining = endDate.difference(today).inDays + 1;
    }
    if (remaining > total) {
      remaining = total;
    }
    return (total, remaining);
  }
}
