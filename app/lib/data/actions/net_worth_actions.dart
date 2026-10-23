part of '../actions.dart';

/// Tracked net-worth accounts (never budget money): declarations, recorded
/// balances and transfers.
mixin _NetWorthActions on _HouseholdActionsCore {
  /// Declares or amends a tracked net-worth account (last-writer-wins by
  /// [accountId]). Interest and staleness inputs live here; balances are
  /// recorded separately with [recordAccountBalance].
  Future<String> setTrackedAccount({
    String? accountId,
    required String name,
    required AccountKind kind,
    int? aprBps,
    AccountCadence? accrualCadence,
    AccountCadence? updateCadence,
    int? minPaymentCents,
  }) async {
    final now = DateTime.now().toUtc();
    final id = accountId ?? uuidv7();
    await append(
      TrackedAccountSet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        accountId: id,
        name: name,
        kind: kind,
        aprBps: aprBps,
        accrualCadence: accrualCadence,
        updateCadence: updateCadence,
        minPaymentCents: minPaymentCents,
      ),
    );
    return id;
  }

  /// Records a net-worth account balance (latest value wins).
  Future<String> recordAccountBalance({
    String? accountId,
    required String accountName,
    required AccountKind kind,
    required int balanceCents,
    DateTime? occurredAt,
  }) async {
    final now = DateTime.now().toUtc();
    final id = accountId ?? uuidv7();
    await append(
      AccountBalanceRecorded(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: occurredAt ?? now,
        createdAt: now,
        accountId: id,
        accountName: accountName,
        kind: kind,
        balanceCents: balanceCents,
      ),
    );
    return id;
  }

  /// Records a deposit into or withdrawal out of a tracked account.
  Future<void> recordAccountTransfer({
    required String accountId,
    required int amountCents,
    required TransferDirection direction,
    String? note,
    DateTime? occurredAt,
  }) async {
    final now = DateTime.now().toUtc();
    await append(
      AccountTransferRecorded(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: occurredAt ?? now,
        createdAt: now,
        accountId: accountId,
        amountCents: amountCents,
        direction: direction,
        note: note,
      ),
    );
  }
}
