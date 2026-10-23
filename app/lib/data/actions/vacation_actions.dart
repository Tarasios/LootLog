part of '../actions.dart';

/// Vacation sub-budgets: opening, amending and closing them.
mixin _VacationActions on _HouseholdActionsCore {
  /// Opens or amends a vacation (last-writer-wins by [vacationId]). Reuse the id
  /// to edit; categories keep their ids so in-progress spending stays attributed.
  Future<String> setVacation({
    String? vacationId,
    required String name,
    required VacationFund fund,
    required DateTime startDate,
    required DateTime endDate,
    required List<VacationCategory> categories,
  }) async {
    final now = DateTime.now().toUtc();
    final id = vacationId ?? uuidv7();
    await append(
      VacationSet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        vacationId: id,
        name: name,
        fund: fund,
        startDate: startDate,
        endDate: endDate,
        categories: categories,
      ),
    );
    return id;
  }

  /// Closes a vacation, returning its unspent budget to the source fund.
  Future<void> closeVacation(String vacationId) async {
    final now = DateTime.now().toUtc();
    await append(
      VacationClosed(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        vacationId: vacationId,
      ),
    );
  }
}
