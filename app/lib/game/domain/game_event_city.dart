/// The long road's game events: civic buildings in the Guard Post,
/// Residential Quarter, Park and Market Row (`town/quarters.dart`), refined
/// goods (`town/goods.dart`) and the Castle's stages (`town/castle.dart`).
/// Part of `game_event.dart` so they join the sealed [GameEvent] hierarchy
/// while that file stays readable.
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
  'RefiningStarted',
  'GoodsCollected',
  'CastleStageStarted',
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
        goods: _goods(payload['goods']),
        completesAt: DateTime.parse(payload['completesAt'] as String).toUtc(),
      );
    case 'RefiningStarted':
      return RefiningStarted(
        eventId: eventId, deviceId: deviceId, actorId: actorId,
        occurredAt: occurredAt, createdAt: createdAt, schemaVersion: schemaVersion,
        districtId: payload['districtId'] as String,
        plotIndex: payload['plotIndex'] as int,
        recipeId: payload['recipeId'] as String,
        batches: payload['batches'] as int,
        input: _materials(payload['input']),
        output: _goods(payload['output']),
        completesAt: DateTime.parse(payload['completesAt'] as String).toUtc(),
      );
    case 'GoodsCollected':
      return GoodsCollected(
        eventId: eventId, deviceId: deviceId, actorId: actorId,
        occurredAt: occurredAt, createdAt: createdAt, schemaVersion: schemaVersion,
        districtId: payload['districtId'] as String,
        plotIndex: payload['plotIndex'] as int,
        jobId: payload['jobId'] as String,
        goods: _goods(payload['goods']),
      );
    case 'CastleStageStarted':
      return CastleStageStarted(
        eventId: eventId, deviceId: deviceId, actorId: actorId,
        occurredAt: occurredAt, createdAt: createdAt, schemaVersion: schemaVersion,
        stage: payload['stage'] as int,
        stageKey: payload['stageKey'] as String,
        cost: _loot(payload['cost']),
        goods: _goods(payload['goods']),
        completesAt: DateTime.parse(payload['completesAt'] as String).toUtc(),
      );
  }
  return null;
}

GoodsBundle _goods(Object? json) => GoodsBundle.fromJson((json as Map? ?? const {}).cast());

/// Construction (or an upgrade to [tier]) of civic building [buildingKey]
/// began on plot [plotIndex] of district [districtId] (the Guard Post,
/// Residential Quarter, Park or Market Row), for [cost] and [goods].
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
    this.goods = const GoodsBundle.empty(),
    required this.completesAt,
  });

  final String districtId;
  final int plotIndex;
  final String buildingKey;
  final int tier;
  final Loot cost;

  /// Refined goods it took (the top tiers).
  final GoodsBundle goods;

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
        'goods': goods.toJson(),
        'completesAt': completesAt.toUtc().toIso8601String(),
      };
}

/// A Market Row workshop on plot [plotIndex] of [districtId] began a job of
/// [batches] batches of recipe [recipeId]: [input] left the town's stores
/// and [output] is ready at [completesAt], both settled when the command
/// ran. The job's id is this event's id. A second job on a busy workshop
/// (typically from another device) is ignored and charged nothing.
class RefiningStarted extends GameEvent {
  const RefiningStarted({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.districtId,
    required this.plotIndex,
    required this.recipeId,
    required this.batches,
    required this.input,
    required this.output,
    required this.completesAt,
  });

  final String districtId;
  final int plotIndex;
  final String recipeId;
  final int batches;
  final MaterialBundle input;
  final GoodsBundle output;
  final DateTime completesAt;

  @override
  String get type => 'RefiningStarted';

  @override
  Map<String, dynamic> payload() => {
        'districtId': districtId,
        'plotIndex': plotIndex,
        'recipeId': recipeId,
        'batches': batches,
        'input': input.toJson(),
        'output': output.toJson(),
        'completesAt': completesAt.toUtc().toIso8601String(),
      };
}

/// The finished job [jobId] on the workshop at plot [plotIndex] of
/// [districtId] was collected. The projection credits the job's stored
/// output ([goods] repeats it for the log) once: a second device's copy is
/// ignored.
class GoodsCollected extends GameEvent {
  const GoodsCollected({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.districtId,
    required this.plotIndex,
    required this.jobId,
    required this.goods,
  });

  final String districtId;
  final int plotIndex;
  final String jobId;
  final GoodsBundle goods;

  @override
  String get type => 'GoodsCollected';

  @override
  Map<String, dynamic> payload() => {
        'districtId': districtId,
        'plotIndex': plotIndex,
        'jobId': jobId,
        'goods': goods.toJson(),
      };
}

/// Work began on Castle stage [stage] (1-based, named [stageKey]) for
/// [cost] and [goods]; it finishes at [completesAt], settled when the
/// command ran. Stages go in order, one at a time; a second copy of a stage
/// already begun (typically from another device) is ignored and charged
/// nothing. Never taken back.
class CastleStageStarted extends GameEvent {
  const CastleStageStarted({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.stage,
    required this.stageKey,
    required this.cost,
    required this.goods,
    required this.completesAt,
  });

  final int stage;
  final String stageKey;
  final Loot cost;
  final GoodsBundle goods;
  final DateTime completesAt;

  @override
  String get type => 'CastleStageStarted';

  @override
  Map<String, dynamic> payload() => {
        'stage': stage,
        'stageKey': stageKey,
        'cost': cost.toJson(),
        'goods': goods.toJson(),
        'completesAt': completesAt.toUtc().toIso8601String(),
      };
}
