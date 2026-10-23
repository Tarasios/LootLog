part of '../actions.dart';

/// The shared war chest and vaults: gifts, contributions, refunds, the
/// chest's goal, and withdrawal writs that need another adult's signature.
mixin _WarChestActions on _HouseholdActionsCore {
  /// Records a gift into a user's vault (untithed).
  Future<void> recordGift({
    required String forUserId,
    required int amountCents,
    String? note,
  }) async {
    final now = DateTime.now().toUtc();
    await append(
      GiftReceived(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        forUserId: forUserId,
        amountCents: amountCents,
        note: note,
      ),
    );
  }

  /// Moves discretionary money from a user's vault into the war chest.
  Future<void> contributeToPool({
    required String fromUserId,
    required int amountCents,
  }) async {
    final now = DateTime.now().toUtc();
    await append(
      PoolContributionMade(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        fromUserId: fromUserId,
        amountCents: amountCents,
      ),
    );
  }

  /// Proposes a war-chest withdrawal (pending the other user's signature).
  Future<String> proposeWithdrawal({
    required int amountCents,
    required String purpose,
    required WithdrawalDestination destination,
  }) async {
    final now = DateTime.now().toUtc();
    final id = uuidv7();
    await append(
      PoolWithdrawalProposed(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        proposalId: id,
        byUserId: meUserId,
        amountCents: amountCents,
        purpose: purpose,
        destination: destination,
      ),
    );
    return id;
  }

  /// Signs a pending war-chest writ. The reducer rejects self-approval, so this
  /// is only meaningful when [meUserId] is not the proposer.
  Future<void> approveWithdrawal(String proposalId) async {
    final now = DateTime.now().toUtc();
    await _commit([
      PoolWithdrawalApproved(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        proposalId: proposalId,
        byUserId: meUserId,
      ),
    ]);
  }

  /// Cancels (declines) a pending war-chest writ.
  Future<void> cancelWithdrawal(String proposalId) async {
    final now = DateTime.now().toUtc();
    await _commit([
      PoolWithdrawalCancelled(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        proposalId: proposalId,
      ),
    ]);
  }

  /// Records a tax refund into the war chest.
  Future<void> recordTaxRefund({required int amountCents, String? note}) async {
    final now = DateTime.now().toUtc();
    await append(
      TaxRefundRecorded(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        amountCents: amountCents,
        note: note,
      ),
    );
  }

  /// Sets the war chest's savings target.
  Future<void> setGoal(int targetCents) async {
    final now = DateTime.now().toUtc();
    await append(
      GoalSet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        targetCents: targetCents,
      ),
    );
  }
}
