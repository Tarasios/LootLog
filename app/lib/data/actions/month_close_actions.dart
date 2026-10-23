part of '../actions.dart';

/// The month-close ritual's writes: variable-bill actuals and leftover
/// allocations.
mixin _MonthCloseActions on _HouseholdActionsCore {
  /// Records a variable recurring expense's actual for [month] (spoils step 1).
  Future<void> recordVariableActual({
    required String expenseId,
    required Month month,
    required int actualCents,
  }) async {
    final now = DateTime.now().toUtc();
    await _commit([
      VariableExpenseRecorded(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        expenseId: expenseId,
        month: month,
        actualCents: actualCents,
      ),
    ]);
  }

  /// Records one slice's month-close allocation (spoils step 2). The
  /// [allocations] must sum to that slice's leftover; the reducer validates
  /// nothing beyond replaying them, so callers build them from the ritual.
  Future<void> allocateLeftover({
    required String forUserId,
    required Month month,
    required String sliceId,
    required List<Allocation> allocations,
  }) async {
    final now = DateTime.now().toUtc();
    await _commit([
      LeftoverAllocated(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        forUserId: forUserId,
        month: month,
        sliceId: sliceId,
        allocations: allocations,
      ),
    ]);
    // Closing a category can defeat a quest boss (a trophy) and extend the
    // on-time-ritual streak (a badge) — grant any newly-earned cosmetic rewards.
    await grantPendingRewards();
  }
}
