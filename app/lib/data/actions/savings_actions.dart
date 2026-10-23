part of '../actions.dart';

/// The savings economy: adopting the rules, covering shortfalls, and
/// allowance advances that need another adult's approval.
mixin _SavingsEconomyActions on _HouseholdActionsCore {
  /// Adopts the savings rules (category savings, general pool, advances) from
  /// [fromMonth], or changes the general rate from that month on. Stored as a
  /// setting so older app versions ignore it rather than failing to sync.
  Future<void> adoptSavingsRules({
    required Month fromMonth,
    required int generalTithePct,
  }) => changeSetting('savingsRules', {
    'fromMonth': fromMonth.toKey(),
    'generalTithePct': generalTithePct,
  });

  /// Covers part of [purchaseId] from the general pool or (for a quest-goal
  /// purchase) one of this adult's category savings pools.
  Future<void> coverShortfall({
    required String purchaseId,
    required CoverSource source,
    required int amountCents,
  }) async {
    final now = DateTime.now().toUtc();
    await append(
      ShortfallCovered(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        purchaseId: purchaseId,
        source: source,
        amountCents: amountCents,
      ),
    );
  }

  /// Asks to borrow [amountCents] from [sliceId]'s next [months] allowances.
  /// Another adult approves (auto-approved in a one-adult household).
  Future<String> proposeAdvance({
    required String sliceId,
    required int amountCents,
    required int months,
    String? purchaseId,
  }) async {
    final now = DateTime.now().toUtc();
    final id = uuidv7();
    await append(
      AllowanceAdvanceProposed(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        advanceId: id,
        byUserId: meUserId,
        sliceId: sliceId,
        amountCents: amountCents,
        months: months,
        purchaseId: purchaseId,
      ),
    );
    return id;
  }

  /// Signs another adult's advance request (the reducer rejects self-approval).
  Future<void> approveAdvance(String advanceId) async {
    final now = DateTime.now().toUtc();
    await append(
      AllowanceAdvanceApproved(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        advanceId: advanceId,
        byUserId: meUserId,
      ),
    );
  }

  /// Withdraws a pending advance request.
  Future<void> cancelAdvance(String advanceId) async {
    final now = DateTime.now().toUtc();
    await append(
      AllowanceAdvanceCancelled(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        advanceId: advanceId,
      ),
    );
  }
}
