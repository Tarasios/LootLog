/// The sealed GameEvent hierarchy: everything that happens in the guild-hall
/// game layer, as immutable events in a log of their own, separate from the
/// ledger's `Event`s.
///
/// The envelope follows the ledger's conventions — UUIDv7 `eventId`,
/// `deviceId`, ISO-8601 UTC `occurredAt`/`createdAt`, a `type` discriminator
/// and a type-specific `payload` — with two differences: the author is the
/// `actorId` (the person acting), and every event carries a `schemaVersion`
/// so payload shapes can evolve. Decoding is forward-tolerant: an unknown type,
/// or a known type naming a value this build lacks, becomes an
/// [UnknownGameEvent] that is stored and relayed verbatim and ignored by the
/// projection.
///
/// Any amount that depends on elapsed time or randomness (production, loot,
/// chest contents) is computed once by the command and stored in the event;
/// the projection never recomputes it.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../domain/time.dart';
import 'game_values.dart';

/// The payload schema version this build writes. Bump it when a payload gains
/// or changes a field, and keep decoding older versions.
const int kGameEventSchemaVersion = 1;

/// Every event type this build understands.
const List<String> kGameEventTypes = [
  'RewardGranted',
  'RewardClaimed',
  'MaterialsCollected',
  'PlotUnlocked',
  'BuildingStarted',
  'GearUpgraded',
  'HeroCustomized',
  'ExpeditionStarted',
  'ExpeditionResolved',
  'ChestGranted',
  'ChestOpened',
  'StreakFreezeUsed',
  'RitualStepCompleted',
  'BossFightResolved',
  'PartyJoined',
  'PartyLeft',
];

/// Base class for every game event.
sealed class GameEvent {
  const GameEvent({
    required this.eventId,
    required this.deviceId,
    required this.actorId,
    required this.occurredAt,
    required this.createdAt,
    this.schemaVersion = kGameEventSchemaVersion,
  });

  /// UUIDv7 identity. Idempotency and the ordering tiebreak key off this.
  final String eventId;

  /// The device that recorded the event.
  final String deviceId;

  /// The person (member id) who acted. Wallet debits and personal state
  /// changes apply to this person unless the event names a hero.
  final String actorId;

  /// When the event happened; the projection orders by
  /// `(occurredAt, eventId)`.
  final DateTime occurredAt;

  /// When the event was actually recorded.
  final DateTime createdAt;

  /// The payload schema version the event was written with.
  final int schemaVersion;

  /// The discriminator string used in JSON.
  String get type;

  /// The type-specific payload (without the envelope).
  Map<String, dynamic> payload();

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'deviceId': deviceId,
        'actorId': actorId,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'schemaVersion': schemaVersion,
        'type': type,
        'payload': payload(),
      };

  /// Reconstructs an event from its JSON envelope.
  static GameEvent fromJson(Map<String, dynamic> json) {
    final env = _Envelope(
      eventId: json['eventId'] as String,
      deviceId: json['deviceId'] as String,
      actorId: json['actorId'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String).toUtc(),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      schemaVersion: json['schemaVersion'] as int? ?? 1,
    );
    final type = json['type'] as String;
    final p = (json['payload'] as Map).cast<String, dynamic>();
    try {
      return _decode(env, type, p);
    } on UnrecognizedGameValue {
      return UnknownGameEvent._(env, type, p);
    }
  }

  static GameEvent _decode(_Envelope env, String type, Map<String, dynamic> p) {
    final eventId = env.eventId;
    final deviceId = env.deviceId;
    final actorId = env.actorId;
    final occurredAt = env.occurredAt;
    final createdAt = env.createdAt;
    final schemaVersion = env.schemaVersion;

    switch (type) {
      case 'RewardGranted':
        return RewardGranted(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          rewardId: p['rewardId'] as String,
          kind: p['kind'] as String,
          gems: p['gems'] as int? ?? 0,
          materials: _materials(p['materials']),
          tokens: p['tokens'] as int? ?? 0,
          reasonCode: p['reasonCode'] as String,
          sourceLedgerEventIds:
              (p['sourceLedgerEventIds'] as List?)?.cast<String>() ?? const [],
        );
      case 'RewardClaimed':
        return RewardClaimed(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          rewardId: p['rewardId'] as String,
        );
      case 'MaterialsCollected':
        return MaterialsCollected(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          buildingId: p['buildingId'] as String,
          amounts: _materials(p['amounts']),
        );
      case 'PlotUnlocked':
        return PlotUnlocked(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          plotIndex: p['plotIndex'] as int,
          gemCost: p['gemCost'] as int? ?? 0,
        );
      case 'BuildingStarted':
        return BuildingStarted(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          plotIndex: p['plotIndex'] as int,
          buildingType: gameEnumByName(
              BuildingType.values, p['buildingType'] as String, 'building'),
          tier: p['tier'] as int,
          cost: _loot(p['cost']),
          completesAt: DateTime.parse(p['completesAt'] as String).toUtc(),
        );
      case 'GearUpgraded':
        return GearUpgraded(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          heroId: p['heroId'] as String,
          slot: p['slot'] as String,
          gearType: p['gearType'] as String,
          tier: p['tier'] as int,
          cost: _loot(p['cost']),
        );
      case 'HeroCustomized':
        return HeroCustomized(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          heroId: p['heroId'] as String,
          field: p['field'] as String,
          value: p['value'] as String,
        );
      case 'ExpeditionStarted':
        return ExpeditionStarted(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          heroId: p['heroId'] as String,
          region: _region(p['region']),
          durationMinutes: p['durationMinutes'] as int,
        );
      case 'ExpeditionResolved':
        return ExpeditionResolved(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          heroId: p['heroId'] as String,
          region: _region(p['region']),
          loot: _materials(p['loot']),
          reportLines: (p['reportLines'] as List?)?.cast<String>() ?? const [],
        );
      case 'ChestGranted':
        return ChestGranted(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          chestId: p['chestId'] as String,
          chestType: gameEnumByName(
              ChestType.values, p['chestType'] as String, 'chest type'),
          reasonCode: p['reasonCode'] as String,
        );
      case 'ChestOpened':
        return ChestOpened(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          chestId: p['chestId'] as String,
          contents: _loot(p['contents']),
        );
      case 'StreakFreezeUsed':
        return StreakFreezeUsed(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          date: GameDay.parse(p['date'] as String),
        );
      case 'RitualStepCompleted':
        return RitualStepCompleted(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          month: Month.parse(p['month'] as String),
          step: gameEnumByName(
              RitualStep.values, p['step'] as String, 'ritual step'),
        );
      case 'BossFightResolved':
        return BossFightResolved(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          month: Month.parse(p['month'] as String),
          bossKey: p['bossKey'] as String,
          won: p['won'] as bool,
          turns: p['turns'] as int,
          rewards: _loot(p['rewards']),
        );
      case 'PartyJoined':
        return PartyJoined(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          partyId: p['partyId'] as String,
        );
      case 'PartyLeft':
        return PartyLeft(
          eventId: eventId,
          deviceId: deviceId,
          actorId: actorId,
          occurredAt: occurredAt,
          createdAt: createdAt,
          schemaVersion: schemaVersion,
          partyId: p['partyId'] as String,
        );
      default:
        return UnknownGameEvent._(env, type, p);
    }
  }
}

MaterialBundle _materials(Object? json) =>
    MaterialBundle.fromJson((json as Map? ?? const {}).cast());

Loot _loot(Object? json) => Loot.fromJson((json as Map? ?? const {}).cast());

ExpeditionRegion _region(Object? name) =>
    gameEnumByName(ExpeditionRegion.values, name as String, 'region');

class _Envelope {
  const _Envelope({
    required this.eventId,
    required this.deviceId,
    required this.actorId,
    required this.occurredAt,
    required this.createdAt,
    required this.schemaVersion,
  });

  final String eventId;
  final String deviceId;
  final String actorId;
  final DateTime occurredAt;
  final DateTime createdAt;
  final int schemaVersion;
}

/// A reward the reward engine granted [actorId]. It waits unclaimed until a
/// [RewardClaimed] moves its gems to the wallet, materials to the shared pool
/// and tokens to the freeze-token count. [rewardId] is deterministic, so the
/// same reward granted twice (two devices noticing the same achievement) is
/// credited once.
class RewardGranted extends GameEvent {
  const RewardGranted({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.rewardId,
    required this.kind,
    required this.gems,
    required this.materials,
    required this.tokens,
    required this.reasonCode,
    required this.sourceLedgerEventIds,
  });

  final String rewardId;

  /// What sort of reward this is (open-ended; defined by the reward engine).
  final String kind;
  final int gems;
  final MaterialBundle materials;

  /// Streak-freeze tokens.
  final int tokens;

  /// Why it was granted (e.g. `log.daily`); see `GameReasonCodes`.
  final String reasonCode;

  /// The ledger events that earned it. Never used to claw anything back.
  final List<String> sourceLedgerEventIds;

  @override
  String get type => 'RewardGranted';

  @override
  Map<String, dynamic> payload() => {
        'rewardId': rewardId,
        'kind': kind,
        'gems': gems,
        'materials': materials.toJson(),
        'tokens': tokens,
        'reasonCode': reasonCode,
        'sourceLedgerEventIds': sourceLedgerEventIds,
      };
}

/// The person collected a granted reward (e.g. tapped the gem pouch).
class RewardClaimed extends GameEvent {
  const RewardClaimed({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.rewardId,
  });

  final String rewardId;

  @override
  String get type => 'RewardClaimed';

  @override
  Map<String, dynamic> payload() => {'rewardId': rewardId};
}

/// Materials a production building made since its last collection, computed
/// when the command ran, added to the shared pool.
class MaterialsCollected extends GameEvent {
  const MaterialsCollected({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.buildingId,
    required this.amounts,
  });

  /// The building's id (`plot-<index>`, see `buildingIdForPlot`).
  final String buildingId;
  final MaterialBundle amounts;

  @override
  String get type => 'MaterialsCollected';

  @override
  Map<String, dynamic> payload() => {
        'buildingId': buildingId,
        'amounts': amounts.toJson(),
      };
}

/// A hall plot was unlocked, paid in gems by the actor.
class PlotUnlocked extends GameEvent {
  const PlotUnlocked({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.plotIndex,
    required this.gemCost,
  });

  final int plotIndex;
  final int gemCost;

  @override
  String get type => 'PlotUnlocked';

  @override
  Map<String, dynamic> payload() => {
        'plotIndex': plotIndex,
        'gemCost': gemCost,
      };
}

/// Construction (or an upgrade to [tier]) began on a plot. Gems are paid by
/// the actor; materials come from the shared pool.
class BuildingStarted extends GameEvent {
  const BuildingStarted({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.plotIndex,
    required this.buildingType,
    required this.tier,
    required this.cost,
    required this.completesAt,
  });

  final int plotIndex;
  final BuildingType buildingType;
  final int tier;
  final Loot cost;

  /// When construction finishes (computed from the build timer at command
  /// time; equal to [occurredAt] for instant builds).
  final DateTime completesAt;

  @override
  String get type => 'BuildingStarted';

  @override
  Map<String, dynamic> payload() => {
        'plotIndex': plotIndex,
        'buildingType': buildingType.name,
        'tier': tier,
        'cost': cost.toJson(),
        'completesAt': completesAt.toUtc().toIso8601String(),
      };
}

/// A hero's gear slot was upgraded, paid by the actor (who may be a partner).
class GearUpgraded extends GameEvent {
  const GearUpgraded({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.heroId,
    required this.slot,
    required this.gearType,
    required this.tier,
    required this.cost,
  });

  /// The hero's owner (one hero per person, so this is a member id).
  final String heroId;
  final String slot;
  final String gearType;
  final int tier;
  final Loot cost;

  @override
  String get type => 'GearUpgraded';

  @override
  Map<String, dynamic> payload() => {
        'heroId': heroId,
        'slot': slot,
        'gearType': gearType,
        'tier': tier,
        'cost': cost.toJson(),
      };
}

/// A cosmetic hero field changed (hair, cloak, name plate...). Free.
class HeroCustomized extends GameEvent {
  const HeroCustomized({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.heroId,
    required this.field,
    required this.value,
  });

  final String heroId;
  final String field;
  final String value;

  @override
  String get type => 'HeroCustomized';

  @override
  Map<String, dynamic> payload() => {
        'heroId': heroId,
        'field': field,
        'value': value,
      };
}

/// A hero set out for [region] for [durationMinutes].
class ExpeditionStarted extends GameEvent {
  const ExpeditionStarted({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.heroId,
    required this.region,
    required this.durationMinutes,
  });

  final String heroId;
  final ExpeditionRegion region;
  final int durationMinutes;

  @override
  String get type => 'ExpeditionStarted';

  @override
  Map<String, dynamic> payload() => {
        'heroId': heroId,
        'region': region.name,
        'durationMinutes': durationMinutes,
      };
}

/// A hero returned. [loot] (materials only: gems come only from budgeting) was
/// rolled once at command time with the event-seeded RNG and goes to the pool.
class ExpeditionResolved extends GameEvent {
  const ExpeditionResolved({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.heroId,
    required this.region,
    required this.loot,
    required this.reportLines,
  });

  final String heroId;
  final ExpeditionRegion region;
  final MaterialBundle loot;
  final List<String> reportLines;

  @override
  String get type => 'ExpeditionResolved';

  @override
  Map<String, dynamic> payload() => {
        'heroId': heroId,
        'region': region.name,
        'loot': loot.toJson(),
        'reportLines': reportLines,
      };
}

/// A chest was awarded to [actorId] and waits unopened.
class ChestGranted extends GameEvent {
  const ChestGranted({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.chestId,
    required this.chestType,
    required this.reasonCode,
  });

  final String chestId;
  final ChestType chestType;
  final String reasonCode;

  @override
  String get type => 'ChestGranted';

  @override
  Map<String, dynamic> payload() => {
        'chestId': chestId,
        'chestType': chestType.name,
        'reasonCode': reasonCode,
      };
}

/// A chest was opened; [contents] were rolled at command time.
class ChestOpened extends GameEvent {
  const ChestOpened({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.chestId,
    required this.contents,
  });

  final String chestId;
  final Loot contents;

  @override
  String get type => 'ChestOpened';

  @override
  Map<String, dynamic> payload() => {
        'chestId': chestId,
        'contents': contents.toJson(),
      };
}

/// A freeze token covered a missed [date] in the actor's streak.
class StreakFreezeUsed extends GameEvent {
  const StreakFreezeUsed({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.date,
  });

  final GameDay date;

  @override
  String get type => 'StreakFreezeUsed';

  @override
  Map<String, dynamic> payload() => {'date': date.toKey()};
}

/// The actor completed one step of [month]'s spoils ritual.
class RitualStepCompleted extends GameEvent {
  const RitualStepCompleted({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.month,
    required this.step,
  });

  final Month month;
  final RitualStep step;

  @override
  String get type => 'RitualStepCompleted';

  @override
  Map<String, dynamic> payload() => {
        'month': month.toKey(),
        'step': step.name,
      };
}

/// The seasonal boss fight closing [month]'s ritual, resolved at command time.
class BossFightResolved extends GameEvent {
  const BossFightResolved({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.month,
    required this.bossKey,
    required this.won,
    required this.turns,
    required this.rewards,
  });

  final Month month;
  final String bossKey;
  final bool won;
  final int turns;
  final Loot rewards;

  @override
  String get type => 'BossFightResolved';

  @override
  Map<String, dynamic> payload() => {
        'month': month.toKey(),
        'bossKey': bossKey,
        'won': won,
        'turns': turns,
        'rewards': rewards.toJson(),
      };
}

/// The actor joined the adventuring party (an Adventure-mode adult).
class PartyJoined extends GameEvent {
  const PartyJoined({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.partyId,
  });

  final String partyId;

  @override
  String get type => 'PartyJoined';

  @override
  Map<String, dynamic> payload() => {'partyId': partyId};
}

/// The actor left the party (e.g. switched to Standard mode).
class PartyLeft extends GameEvent {
  const PartyLeft({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.partyId,
  });

  final String partyId;

  @override
  String get type => 'PartyLeft';

  @override
  Map<String, dynamic> payload() => {'partyId': partyId};
}

/// An event this build cannot interpret: an unknown type, or a known type
/// naming a value added by a newer release. Kept verbatim so it is stored,
/// relayed and exported unchanged; the projection ignores it.
class UnknownGameEvent extends GameEvent {
  UnknownGameEvent._(_Envelope env, this.type, Map<String, dynamic> rawPayload)
      : _payload = rawPayload,
        super(
          eventId: env.eventId,
          deviceId: env.deviceId,
          actorId: env.actorId,
          occurredAt: env.occurredAt,
          createdAt: env.createdAt,
          schemaVersion: env.schemaVersion,
        );

  @override
  final String type;

  final Map<String, dynamic> _payload;

  @override
  Map<String, dynamic> payload() => _payload;
}
