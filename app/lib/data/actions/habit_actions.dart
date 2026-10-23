part of '../actions.dart';

/// Habit markers that count as activity without moving money.
mixin _HabitActions on _HouseholdActionsCore {
  /// "Nothing spent today": counts today as an active day without a purchase.
  /// Returns false (and records nothing) until the household accepts newer
  /// event types — older devices could not sync it.
  Future<bool> checkInNoSpend() async {
    if (!await acceptsNewEventTypes()) return false;
    final now = DateTime.now().toUtc();
    await _commit([
      NoSpendCheckedIn(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
      ),
    ]);
    return true;
  }

  /// Marks the Monday-to-Sunday week containing [day] as reconciled. Returns
  /// false (and records nothing) until the household accepts newer event types.
  Future<bool> completeReconcile(CalendarDay day) async {
    if (!await acceptsNewEventTypes()) return false;
    final now = DateTime.now().toUtc();
    await _commit([
      ReconcileCompleted(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        weekStart: day.weekStart,
      ),
    ]);
    return true;
  }
}
