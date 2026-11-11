/// The town-growth game events: prosperity peaks and tiers reached (see
/// `town/prosperity.dart`), districts bought and built on
/// (`town/districts.dart`), and food harvested and eaten (`town/food.dart`).
/// Part of `game_event.dart` so they join the sealed [GameEvent] hierarchy
/// while that file stays readable.
///
/// Every type here is new to stage 2, so an older build decodes it as an
/// [UnknownGameEvent] and relays it verbatim; none adds a value to an enum
/// an older build parses inside an event it already knows. District and
/// building keys are plain strings, so a district a newer build adds still
/// decodes here and the projection sets it aside.
part of 'game_event.dart';

/// The growth event types this build understands (in [kGameEventTypes]).
const List<String> _kGrowthEventTypes = [
  'ProsperityReached',
  'TierReached',
  'DistrictPurchased',
  'DistrictBuildingStarted',
  'FoodHarvested',
  'FoodConsumed',
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
    case 'DistrictPurchased':
      return DistrictPurchased(
        eventId: eventId, deviceId: deviceId, actorId: actorId,
        occurredAt: occurredAt, createdAt: createdAt, schemaVersion: schemaVersion,
        districtId: payload['districtId'] as String,
        cost: _loot(payload['cost']),
      );
    case 'DistrictBuildingStarted':
      return DistrictBuildingStarted(
        eventId: eventId, deviceId: deviceId, actorId: actorId,
        occurredAt: occurredAt, createdAt: createdAt, schemaVersion: schemaVersion,
        districtId: payload['districtId'] as String,
        plotIndex: payload['plotIndex'] as int,
        buildingKey: payload['buildingKey'] as String,
        tier: payload['tier'] as int,
        cost: _loot(payload['cost']),
        completesAt: DateTime.parse(payload['completesAt'] as String).toUtc(),
      );
    case 'FoodHarvested':
      return FoodHarvested(
        eventId: eventId, deviceId: deviceId, actorId: actorId,
        occurredAt: occurredAt, createdAt: createdAt, schemaVersion: schemaVersion,
        districtId: payload['districtId'] as String,
        plotIndex: payload['plotIndex'] as int,
        amount: payload['amount'] as int,
      );
    case 'FoodConsumed':
      return FoodConsumed(
        eventId: eventId, deviceId: deviceId, actorId: actorId,
        occurredAt: occurredAt, createdAt: createdAt, schemaVersion: schemaVersion,
        day: GameDay.parse(payload['day'] as String),
        amount: payload['amount'] as int,
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

/// [actorId] bought district [districtId] for [cost] (gems from their
/// wallet, materials from their town). A second purchase of an owned
/// district is charged nothing.
class DistrictPurchased extends GameEvent {
  const DistrictPurchased({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.districtId,
    required this.cost,
  });

  final String districtId;
  final Loot cost;

  @override
  String get type => 'DistrictPurchased';

  @override
  Map<String, dynamic> payload() => {'districtId': districtId, 'cost': cost.toJson()};
}

/// Construction (or an upgrade to [tier]) of [buildingKey] began on plot
/// [plotIndex] of district [districtId], beyond the outpost. Like
/// `BuildingStarted`, but it names the district and building by key so
/// later districts need no new event type.
class DistrictBuildingStarted extends GameEvent {
  const DistrictBuildingStarted({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.districtId,
    required this.plotIndex,
    required this.buildingKey,
    required this.tier,
    required this.cost,
    required this.completesAt,
  });

  final String districtId;
  final int plotIndex;
  final String buildingKey;
  final int tier;
  final Loot cost;

  /// When construction finishes (computed when the command ran).
  final DateTime completesAt;

  @override
  String get type => 'DistrictBuildingStarted';

  @override
  Map<String, dynamic> payload() => {
        'districtId': districtId,
        'plotIndex': plotIndex,
        'buildingKey': buildingKey,
        'tier': tier,
        'cost': cost.toJson(),
        'completesAt': completesAt.toUtc().toIso8601String(),
      };
}

/// [amount] food harvested from the farm on plot [plotIndex] of
/// [districtId], computed when the command ran (working shift, granary
/// room) and added to the town's stores.
class FoodHarvested extends GameEvent {
  const FoodHarvested({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.districtId,
    required this.plotIndex,
    required this.amount,
  });

  final String districtId;
  final int plotIndex;
  final int amount;

  @override
  String get type => 'FoodHarvested';

  @override
  Map<String, dynamic> payload() =>
      {'districtId': districtId, 'plotIndex': plotIndex, 'amount': amount};
}

/// [actorId]'s residents ate [amount] food on household [day], written by
/// the reward engine after the day ends. Idempotent per day: a copy for a
/// day already eaten eats only what a larger copy adds; the stores never go
/// below zero.
class FoodConsumed extends GameEvent {
  const FoodConsumed({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.day,
    required this.amount,
  });

  final GameDay day;
  final int amount;

  @override
  String get type => 'FoodConsumed';

  @override
  Map<String, dynamic> payload() => {'day': day.toKey(), 'amount': amount};
}
