part of '../event.dart';

/// Declares or amends a tracked net-worth account (last-writer-wins by
/// [accountId]). Carries the account's configuration — kind, optional interest
/// rate and cadences, and a debt's minimum payment. Balances themselves arrive
/// as separate [AccountBalanceRecorded] events; a [TrackedAccountSet] is not
/// required before recording a balance (a bare balance implies a minimal
/// account), but it is where interest and staleness inputs live.
class TrackedAccountSet extends Event {
  const TrackedAccountSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.accountId,
    required this.name,
    required this.kind,
    this.aprBps,
    this.accrualCadence,
    this.updateCadence,
    this.minPaymentCents,
  });

  final String accountId;
  final String name;
  final AccountKind kind;

  /// Annual interest rate in basis points (100 bps = 1%). Drives savings/debt
  /// accrual when paired with [accrualCadence].
  final int? aprBps;
  final AccountCadence? accrualCadence;

  /// How often a manual value is expected to be refreshed; past this cadence an
  /// investment is flagged stale.
  final AccountCadence? updateCadence;

  /// A debt's minimum monthly payment, surfaced automatically as a recurring
  /// expense so it enters the monthly plan.
  final int? minPaymentCents;

  @override
  String get type => 'TrackedAccountSet';

  @override
  Map<String, dynamic> payload() => {
    'accountId': accountId,
    'name': name,
    'kind': kind.name,
    if (aprBps != null) 'aprBps': aprBps,
    if (accrualCadence != null) 'accrualCadence': accrualCadence!.name,
    if (updateCadence != null) 'updateCadence': updateCadence!.name,
    if (minPaymentCents != null) 'minPaymentCents': minPaymentCents,
  };
}

class AccountBalanceRecorded extends Event {
  const AccountBalanceRecorded({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.accountId,
    required this.accountName,
    required this.kind,
    required this.balanceCents,
  });

  final String accountId;
  final String accountName;
  final AccountKind kind;
  final int balanceCents;

  @override
  String get type => 'AccountBalanceRecorded';

  @override
  Map<String, dynamic> payload() => {
    'accountId': accountId,
    'accountName': accountName,
    'kind': kind.name,
    'balanceCents': balanceCents,
  };
}

/// Records a deposit into or withdrawal out of a tracked account. Adjusts the
/// account's balance from its last recorded value at read time; interest still
/// accrues from the last [AccountBalanceRecorded], not from the transfer.
class AccountTransferRecorded extends Event {
  const AccountTransferRecorded({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.accountId,
    required this.amountCents,
    required this.direction,
    this.note,
  });

  final String accountId;
  final int amountCents;
  final TransferDirection direction;
  final String? note;

  @override
  String get type => 'AccountTransferRecorded';

  @override
  Map<String, dynamic> payload() => {
    'accountId': accountId,
    'amountCents': amountCents,
    'direction': direction.name,
    if (note != null) 'note': note,
  };
}
