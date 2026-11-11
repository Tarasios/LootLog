import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';

import 'game_fixtures.dart';

final _loot = Loot(
  gems: 12,
  materials: MaterialBundle({MaterialKind.lumber: 5, MaterialKind.crystal: 1}),
  tokens: 1,
);

/// One fully-populated sample of every game event type.
final List<GameEvent> _samples = [
  granted('e1',
      when: at(0),
      gems: 3,
      materials: MaterialBundle({MaterialKind.herbs: 2}),
      tokens: 1,
      reasonCode: 'log.daily'),
  claimed('e2', 'reward-e1', when: at(1)),
  collected('e3', 'plot-0', MaterialBundle({MaterialKind.stone: 4}), when: at(2)),
  unlocked('e4', 3, when: at(3), gemCost: 25),
  built('e5', 3, BuildingType.arcaneWell,
      when: at(4), tier: 2, cost: _loot, completesAt: at(64)),
  gearUpgraded('e6', when: at(5), slot: 'armor', gearType: 'leather', tier: 3,
      cost: _loot),
  customized('e7', 'hairColor', 'auburn', when: at(6)),
  expeditionStarted('e8', ExpeditionRegion.subscriptionSwamp,
      when: at(7), minutes: 240),
  expeditionResolved('e9', ExpeditionRegion.subscriptionSwamp,
      MaterialBundle({MaterialKind.hide: 3, MaterialKind.essence: 1}),
      when: at(8)),
  chestGranted('e10', 'chest-1', ChestType.party, when: at(9)),
  chestOpened('e11', 'chest-1', _loot, when: at(10)),
  freezeUsed('e12', const GameDay(2026, 9, 30), when: at(11)),
  ritualStep('e13', const Month(2026, 9), RitualStep.reconcile, when: at(12)),
  bossFight('e14', const Month(2026, 9), when: at(13), won: false, rewards: _loot),
  partyJoined('e15', 'party-1', when: at(14)),
  partyLeft('e16', 'party-1', when: at(15)),
  ItemAcquired(
    eventId: 'e17',
    deviceId: 'dev-1',
    actorId: robin,
    occurredAt: at(16),
    createdAt: at(16),
    acquisitionId: 'chest-1',
    itemId: 'rug_round',
    source: DecorSource.chest,
    toTown: true,
  ),
  ItemPurchased(
    eventId: 'e18',
    deviceId: 'dev-1',
    actorId: robin,
    occurredAt: at(17),
    createdAt: at(17),
    itemId: 'bed_simple',
    gemCost: 8,
  ),
  ItemPlaced(
    eventId: 'e19',
    deviceId: 'dev-1',
    actorId: robin,
    occurredAt: at(18),
    createdAt: at(18),
    placementId: 'p1',
    itemId: 'rug_round',
    space: DecorSpace.room,
    column: 3,
    row: 4,
    rotation: 1,
  ),
  ItemStored(
    eventId: 'e20',
    deviceId: 'dev-1',
    actorId: robin,
    occurredAt: at(19),
    createdAt: at(19),
    placementId: 'p1',
  ),
  ItemEquipped(
    eventId: 'e21',
    deviceId: 'dev-1',
    actorId: robin,
    occurredAt: at(20),
    createdAt: at(20),
    itemId: 'outfit_ranger',
  ),
  DailyEventOffered(
    eventId: 'e22',
    deviceId: 'dev-1',
    actorId: robin,
    occurredAt: at(21),
    createdAt: at(22),
    offerId: 'daily.event:$robin:2026-10-01',
    day: const GameDay(2026, 10, 1),
    kind: DailyEventKind.trader,
    gives: MaterialBundle({MaterialKind.lumber: 20}),
    receives: Loot(gems: 1, materials: MaterialBundle({MaterialKind.ore: 8})),
    flavourKey: 'trader.2',
    plotIndex: 4,
  ),
  DailyEventResolved(
    eventId: 'e23',
    deviceId: 'dev-1',
    actorId: robin,
    occurredAt: at(23),
    createdAt: at(23),
    offerId: 'daily.event:$robin:2026-10-01',
    accepted: true,
    paid: MaterialBundle({MaterialKind.lumber: 20}),
    received: Loot(materials: MaterialBundle({MaterialKind.ore: 8})),
  ),
  FestivalHeld(
    eventId: 'e24',
    deviceId: 'dev-1',
    actorId: robin,
    occurredAt: at(24),
    createdAt: at(24),
    week: const GameDay(2026, 9, 28),
    tier: FestivalTier.fair,
    weekdaysLogged: 4,
  ),
  TownsSplit(
    eventId: 'e25',
    deviceId: 'dev-1',
    actorId: robin,
    occurredAt: at(25),
    createdAt: at(25),
    ownerId: robin,
    welcome: MaterialBundle({MaterialKind.lumber: 40, MaterialKind.stone: 40}),
  ),
  GiftSent(
    eventId: 'e26',
    deviceId: 'dev-1',
    actorId: robin,
    occurredAt: at(26),
    createdAt: at(26),
    toPersonId: sam,
    bundle: MaterialBundle({MaterialKind.ore: 12}),
  ),
];

void main() {
  test('the samples cover every known game event type', () {
    expect({for (final e in _samples) e.type}, kGameEventTypes.toSet());
  });

  for (final event in _samples) {
    test('${event.type} round-trips through JSON text', () {
      final json = event.toJson();
      final decoded =
          GameEvent.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);

      expect(decoded.runtimeType, event.runtimeType);
      expect(decoded.toJson(), json);
      expect(decoded.eventId, event.eventId);
      expect(decoded.actorId, event.actorId);
      expect(decoded.occurredAt, event.occurredAt);
      expect(decoded.schemaVersion, kGameEventSchemaVersion);
    });
  }

  test('the envelope mirrors the ledger: ISO-8601 UTC instants, type + payload',
      () {
    final json = _samples.first.toJson();
    expect(json.keys, containsAll(<String>[
      'eventId',
      'deviceId',
      'actorId',
      'occurredAt',
      'createdAt',
      'schemaVersion',
      'type',
      'payload',
    ]));
    expect(json['occurredAt'], '2026-10-01T19:00:00.000Z');
    expect(json['schemaVersion'], 1);
  });

  test('an unknown event type decodes as UnknownGameEvent and relays verbatim',
      () {
    final raw = {
      'eventId': 'x1',
      'deviceId': 'dev-9',
      'actorId': robin,
      'occurredAt': '2026-10-01T19:00:00.000Z',
      'createdAt': '2026-10-01T19:00:00.000Z',
      'schemaVersion': 7,
      'type': 'PetAdopted',
      'payload': {'petId': 'p1', 'nested': {'a': 1}},
    };
    final decoded = GameEvent.fromJson(raw);
    expect(decoded, isA<UnknownGameEvent>());
    expect(decoded.toJson(), raw);
  });

  test('a known type carrying a value this build does not know is preserved '
      'as UnknownGameEvent rather than throwing', () {
    final raw = expeditionStarted('x2', ExpeditionRegion.oldRoads, when: at(0))
        .toJson();
    (raw['payload'] as Map<String, dynamic>)['region'] = 'frostPeaks';
    final decoded = GameEvent.fromJson(raw);
    expect(decoded, isA<UnknownGameEvent>());
    expect(decoded.type, 'ExpeditionStarted');
    expect(decoded.toJson(), raw);
  });

  test('a daily event of a kind this build lacks is kept as UnknownGameEvent',
      () {
    final raw = _samples.whereType<DailyEventOffered>().single.toJson();
    (raw['payload'] as Map<String, dynamic>)['kind'] = 'fireworks';
    final decoded = GameEvent.fromJson(raw);
    expect(decoded, isA<UnknownGameEvent>());
    expect(decoded.toJson(), raw);
  });

  test('an older build sees the daily event types as UnknownGameEvent', () {
    // An older build has no case for these types: it takes the default
    // branch, exactly like any type it has never heard of.
    for (final event in _samples.where((sample) =>
        sample is DailyEventOffered || sample is DailyEventResolved)) {
      final raw = event.toJson()..['type'] = 'Future${event.type}';
      final decoded = GameEvent.fromJson(raw);
      expect(decoded, isA<UnknownGameEvent>());
      expect(decoded.toJson(), raw);
    }
  });

  test('a festival of a tier this build lacks is kept as UnknownGameEvent, '
      'and an older build sees the type as unknown', () {
    final raw = _samples.whereType<FestivalHeld>().single.toJson();
    final newerTier = {
      ...raw,
      'payload': {...raw['payload'] as Map<String, dynamic>, 'tier': 'carnival'},
    };
    expect(GameEvent.fromJson(newerTier), isA<UnknownGameEvent>());
    final olderBuild = {...raw, 'type': 'FutureFestivalHeld'};
    final decoded = GameEvent.fromJson(olderBuild);
    expect(decoded, isA<UnknownGameEvent>());
    expect(decoded.toJson(), olderBuild);
  });

  test('an older build sees the town split as UnknownGameEvent and relays it '
      'verbatim', () {
    final raw = _samples.whereType<TownsSplit>().single.toJson();
    expect((raw['payload'] as Map<String, dynamic>)['splitId'], 'towns.split');
    final olderBuild = {...raw, 'type': 'FutureTownsSplit'};
    final decoded = GameEvent.fromJson(olderBuild);
    expect(decoded, isA<UnknownGameEvent>());
    expect(decoded.toJson(), olderBuild);
  });

  test('an older build sees a gift as UnknownGameEvent and relays it verbatim',
      () {
    final raw = _samples.whereType<GiftSent>().single.toJson();
    final olderBuild = {...raw, 'type': 'FutureGiftSent'};
    final decoded = GameEvent.fromJson(olderBuild);
    expect(decoded, isA<UnknownGameEvent>());
    expect(decoded.toJson(), olderBuild);
  });

  test('a split naming a material this build lacks is kept as UnknownGameEvent',
      () {
    final raw = _samples.whereType<TownsSplit>().single.toJson();
    final newer = {
      ...raw,
      'payload': {
        ...raw['payload'] as Map<String, dynamic>,
        'welcome': {'moonstone': 3},
      },
    };
    expect(GameEvent.fromJson(newer), isA<UnknownGameEvent>());
  });

  test('a windfall-free offer omits its plot, and a decline its amounts', () {
    final offer = DailyEventOffered(
      eventId: 'x4',
      deviceId: 'dev-1',
      actorId: robin,
      occurredAt: at(0),
      createdAt: at(0),
      offerId: 'daily.event:$robin:2026-10-01',
      day: const GameDay(2026, 10, 1),
      kind: DailyEventKind.visitor,
      gives: const MaterialBundle.empty(),
      receives: const Loot(gems: 2),
      flavourKey: 'visitor.1',
    );
    final decoded = GameEvent.fromJson(offer.toJson()) as DailyEventOffered;
    expect(decoded.plotIndex, isNull);
    final decline = GameEvent.fromJson({
      ...DailyEventResolved(
        eventId: 'x5',
        deviceId: 'dev-1',
        actorId: robin,
        occurredAt: at(0),
        createdAt: at(0),
        offerId: offer.offerId,
        accepted: false,
      ).toJson(),
    }) as DailyEventResolved;
    expect(decline.paid.isEmpty, isTrue);
    expect(decline.received, Loot.none);
  });

  test('a missing schemaVersion reads as version 1', () {
    final raw = partyJoined('x3', 'party-1', when: at(0)).toJson()
      ..remove('schemaVersion');
    expect(GameEvent.fromJson(raw).schemaVersion, 1);
  });

  group('value types', () {
    test('MaterialBundle drops zero entries and serializes by name', () {
      final b = MaterialBundle({MaterialKind.ore: 0, MaterialKind.trophy: 2});
      expect(b.toJson(), {'trophy': 2});
      expect(b[MaterialKind.ore], 0);
      expect(MaterialBundle.fromJson(b.toJson()), b);
    });

    test('GameDay keys and parses as yyyy-MM-dd in the household timezone', () {
      // 2026-10-02 05:00 UTC is still Oct 1 in Vancouver (PDT, UTC-7).
      final day = GameDay.fromInstant(DateTime.utc(2026, 10, 2, 5));
      expect(day, const GameDay(2026, 10, 1));
      expect(day.toKey(), '2026-10-01');
      expect(GameDay.parse('2026-10-01'), day);
      expect(day.next(), const GameDay(2026, 10, 2));
      expect(const GameDay(2026, 3, 1).previous(), const GameDay(2026, 2, 28));
    });
  });
}
