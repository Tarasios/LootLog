/// The long road's game events: civic buildings in the Guard Post,
/// Residential Quarter, Park and Market Row (`town/quarters.dart`). Part of
/// `game_event.dart` so they join the sealed [GameEvent] hierarchy while
/// that file stays readable.
///
/// Every type here is new to stage 3, so an older build decodes it as an
/// [UnknownGameEvent] and relays it verbatim (a stage-2 build would drop a
/// field it does not know from an event it does, so nothing new rides in an
/// older type). Building keys are plain strings, so a building a newer
/// build adds still decodes here and the projection sets it aside.
part of 'game_event.dart';

/// The long road's event types this build understands (in
/// [kGameEventTypes]).
const List<String> _kCityEventTypes = [
  'CivicBuildingStarted',
];

/// Decodes a long-road event, or returns null for a type that is not one.
GameEvent? _decodeCity(_Envelope envelope, String type, Map<String, dynamic> payload) {
  final eventId = envelope.eventId;
  final deviceId = envelope.deviceId;
  final actorId = envelope.actorId;
  final occurredAt = envelope.occurredAt;
  final createdAt = envelope.createdAt;
  final schemaVersion = envelope.schemaVersion;
  switch (type) {
    case 'CivicBuildingStarted':
      return CivicBuildingStarted(
        eventId: eventId, deviceId: deviceId, actorId: actorId,
        occurredAt: occurredAt, createdAt: createdAt, schemaVersion: schemaVersion,
        districtId: payload['districtId'] as String,
        plotIndex: payload['plotIndex'] as int,
        buildingKey: payload['buildingKey'] as String,
        tier: payload['tier'] as int,
        cost: _loot(payload['cost']),
        completesAt: DateTime.parse(payload['completesAt'] as String).toUtc(),
      );
  }
  return null;
}

/// Construction (or an upgrade to [tier]) of civic building [buildingKey]
/// began on plot [plotIndex] of district [districtId] (the Guard Post,
/// Residential Quarter, Park or Market Row), for [cost].
class CivicBuildingStarted extends GameEvent {
  const CivicBuildingStarted({
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
  String get type => 'CivicBuildingStarted';

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
