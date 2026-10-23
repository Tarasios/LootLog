part of '../event.dart';

/// A cosmetic setting for the adventure skin. Domain-inert.
class CosmeticSet extends Event {
  const CosmeticSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.key,
    required this.value,
  });

  final String key;
  final Object? value;

  @override
  String get type => 'CosmeticSet';

  @override
  Map<String, dynamic> payload() => {'key': key, 'value': value};
}

/// A cosmetic reward the game layer has granted — a defeated-quest trophy, a
/// streak title, or a habit badge. Recorded as an event so rewards sync across
/// devices like everything else. It is part of the firewall: the money reducer
/// ignores it entirely (a ledger with every cosmetic event stripped reduces to
/// identical balances). [rewardId] is deterministic so re-granting the same
/// reward is idempotent; [sourceRef] points at what earned it (a questId, a
/// streak-threshold key, a month); [grantedAt] is when the game recognised it.
class GameRewardGranted extends Event {
  const GameRewardGranted({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.rewardId,
    required this.kind,
    required this.sourceRef,
    required this.grantedAt,
  });

  final String rewardId;
  final RewardKind kind;
  final String sourceRef;
  final DateTime grantedAt;

  @override
  String get type => 'GameRewardGranted';

  @override
  Map<String, dynamic> payload() => {
    'rewardId': rewardId,
    'kind': kind.name,
    'sourceRef': sourceRef,
    'grantedAt': grantedAt.toUtc().toIso8601String(),
  };
}

/// "Nothing spent today": the author's daily check-in on a day with no
/// purchases. Money-inert (the reducer ignores it); it exists so an honest
/// zero-spend day counts as showing up. The day is the household-timezone date
/// of [createdAt].
class NoSpendCheckedIn extends Event {
  const NoSpendCheckedIn({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
  });

  @override
  String get type => 'NoSpendCheckIn';

  @override
  Map<String, dynamic> payload() => const {};
}

/// The author finished reconciling the Monday-to-Sunday week starting
/// [weekStart] (checked the week's purchases against what really happened).
/// Money-inert: corrections themselves are ordinary purchase events.
class ReconcileCompleted extends Event {
  const ReconcileCompleted({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.weekStart,
  });

  final CalendarDay weekStart;

  @override
  String get type => 'ReconcileCompleted';

  @override
  Map<String, dynamic> payload() => {'weekStart': weekStart.toKey()};
}
