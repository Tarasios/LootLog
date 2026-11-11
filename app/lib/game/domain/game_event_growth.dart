/// The town-growth game events: prosperity peaks and tiers reached (see
/// `town/prosperity.dart`). Part of `game_event.dart` so they join the
/// sealed [GameEvent] hierarchy while that file stays readable.
///
/// Every type here is new to stage 2, so an older build decodes it as an
/// [UnknownGameEvent] and relays it verbatim; none adds a value to an enum
/// an older build parses inside an event it already knows.
part of 'game_event.dart';

/// The growth event types this build understands (in [kGameEventTypes]).
const List<String> _kGrowthEventTypes = [
  'ProsperityReached',
  'TierReached',
];

/// Decodes a growth event, or returns null for a type that is not one.
GameEvent? _decodeGrowth(_Envelope envelope, String type, Map<String, dynamic> payload) {
  final eventId = envelope.eventId;
  final deviceId = envelope.deviceId;
  final actorId = envelope.actorId;
  final occurredAt = envelope.occurredAt;
  final createdAt = envelope.createdAt;
  final schemaVersion = envelope.schemaVersion;
  switch (type) {
    case 'ProsperityReached':
      return ProsperityReached(
        eventId: eventId, deviceId: deviceId, actorId: actorId,
        occurredAt: occurredAt, createdAt: createdAt, schemaVersion: schemaVersion,
        value: payload['value'] as int,
      );
    case 'TierReached':
      return TierReached(
        eventId: eventId, deviceId: deviceId, actorId: actorId,
        occurredAt: occurredAt, createdAt: createdAt, schemaVersion: schemaVersion,
        tier: gameEnumByName(TownTier.values, payload['tier'] as String, 'town tier'),
      );
  }
  return null;
}

/// [actorId]'s town reached a new peak prosperity of [value], written by
/// the reward engine whenever the town's prosperity rises past the stored
/// peak. The projection keeps the highest value seen, so copies from two
/// devices converge and a decoration stored away never lowers the peak.
class ProsperityReached extends GameEvent {
  const ProsperityReached({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.value,
  });

  final int value;

  @override
  String get type => 'ProsperityReached';

  @override
  Map<String, dynamic> payload() => {'value': value};
}

/// [actorId]'s town grew into [tier], written by the reward engine beside
/// the tier's reward (`RewardGranted` with id `tier:<who>:<tier>`). The
/// projection keeps the earliest instant per tier; the highest tier reached
/// is the town's tier. Never taken back.
class TierReached extends GameEvent {
  const TierReached({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.tier,
  });

  final TownTier tier;

  @override
  String get type => 'TierReached';

  @override
  Map<String, dynamic> payload() => {'tier': tier.name};
}
