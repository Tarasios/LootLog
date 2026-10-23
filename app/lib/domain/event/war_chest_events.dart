part of '../event.dart';

class GiftReceived extends Event {
  const GiftReceived({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.forUserId,
    required this.amountCents,
    this.note,
  });

  final String forUserId;
  final int amountCents;
  final String? note;

  @override
  String get type => 'GiftReceived';

  @override
  Map<String, dynamic> payload() => {
    'forUserId': forUserId,
    'amountCents': amountCents,
    if (note != null) 'note': note,
  };
}

class PoolContributionMade extends Event {
  const PoolContributionMade({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.fromUserId,
    required this.amountCents,
  });

  final String fromUserId;
  final int amountCents;

  @override
  String get type => 'PoolContributionMade';

  @override
  Map<String, dynamic> payload() => {
    'fromUserId': fromUserId,
    'amountCents': amountCents,
  };
}

class PoolWithdrawalProposed extends Event {
  const PoolWithdrawalProposed({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.proposalId,
    required this.byUserId,
    required this.amountCents,
    required this.purpose,
    required this.destination,
  });

  final String proposalId;
  final String byUserId;
  final int amountCents;
  final String purpose;
  final WithdrawalDestination destination;

  @override
  String get type => 'PoolWithdrawalProposed';

  @override
  Map<String, dynamic> payload() => {
    'proposalId': proposalId,
    'byUserId': byUserId,
    'amountCents': amountCents,
    'purpose': purpose,
    'destination': destination.toJson(),
  };
}

class PoolWithdrawalApproved extends Event {
  const PoolWithdrawalApproved({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.proposalId,
    required this.byUserId,
  });

  final String proposalId;
  final String byUserId;

  @override
  String get type => 'PoolWithdrawalApproved';

  @override
  Map<String, dynamic> payload() => {
    'proposalId': proposalId,
    'byUserId': byUserId,
  };
}

class PoolWithdrawalCancelled extends Event {
  const PoolWithdrawalCancelled({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.proposalId,
  });

  final String proposalId;

  @override
  String get type => 'PoolWithdrawalCancelled';

  @override
  Map<String, dynamic> payload() => {'proposalId': proposalId};
}

class TaxRefundRecorded extends Event {
  const TaxRefundRecorded({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.amountCents,
    this.note,
  });

  final int amountCents;
  final String? note;

  @override
  String get type => 'TaxRefundRecorded';

  @override
  Map<String, dynamic> payload() => {
    'amountCents': amountCents,
    if (note != null) 'note': note,
  };
}

/// Sets the war chest's savings target.
class GoalSet extends Event {
  const GoalSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.targetCents,
  });

  final int targetCents;

  @override
  String get type => 'GoalSet';

  @override
  Map<String, dynamic> payload() => {'targetCents': targetCents};
}
