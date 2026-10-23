part of '../event.dart';

/// Covers the gap on a purchase that exceeds what its target had available:
/// from the purchaser's general pool, or (when buying a quest's goal) from one
/// of their category savings pools. Ignored if the purchase is voided.
class ShortfallCovered extends Event {
  const ShortfallCovered({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.purchaseId,
    required this.source,
    required this.amountCents,
  });

  final String purchaseId;
  final CoverSource source;
  final int amountCents;

  @override
  String get type => 'ShortfallCovered';

  @override
  Map<String, dynamic> payload() => {
    'purchaseId': purchaseId,
    'source': source.toJson(),
    'amountCents': amountCents,
  };
}

/// Proposes borrowing [amountCents] from a category's next [months] monthly
/// allowances to cover a purchase now. Needs another adult's approval
/// (auto-approved in a one-adult household), exactly like a pool withdrawal.
class AllowanceAdvanceProposed extends Event {
  const AllowanceAdvanceProposed({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.advanceId,
    required this.byUserId,
    required this.sliceId,
    required this.amountCents,
    required this.months,
    this.purchaseId,
  });

  final String advanceId;
  final String byUserId;
  final String sliceId;
  final int amountCents;
  final int months;
  final String? purchaseId;

  @override
  String get type => 'AllowanceAdvanceProposed';

  @override
  Map<String, dynamic> payload() => {
    'advanceId': advanceId,
    'byUserId': byUserId,
    'sliceId': sliceId,
    'amountCents': amountCents,
    'months': months,
    if (purchaseId != null) 'purchaseId': purchaseId,
  };
}

class AllowanceAdvanceApproved extends Event {
  const AllowanceAdvanceApproved({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.advanceId,
    required this.byUserId,
  });

  final String advanceId;
  final String byUserId;

  @override
  String get type => 'AllowanceAdvanceApproved';

  @override
  Map<String, dynamic> payload() => {
    'advanceId': advanceId,
    'byUserId': byUserId,
  };
}

class AllowanceAdvanceCancelled extends Event {
  const AllowanceAdvanceCancelled({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.advanceId,
  });

  final String advanceId;

  @override
  String get type => 'AllowanceAdvanceCancelled';

  @override
  Map<String, dynamic> payload() => {'advanceId': advanceId};
}
