import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/data/drift_game_event_store.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_values.dart';

import '../domain/game_fixtures.dart';

/// Contract every [GameEventStore] must honour, run against each
/// implementation.
void storeContract(String name, Future<(GameEventStore, Future<void> Function())> Function() open) {
  group(name, () {
    late GameEventStore store;
    late Future<void> Function() close;
    setUp(() async {
      (store, close) = await open();
    });
    tearDown(() => close());

    test('append is idempotent on eventId', () async {
      final e = partyJoined('p1', 'party-1', when: at(0));
      await store.append([e]);
      await store.append([e, e]);
      expect((await store.all()).map((x) => x.eventId), ['p1']);
    });

    test('all() returns canonical (occurredAt, eventId) order', () async {
      await store.append([
        customized('c', 'hair', 'x', when: at(5)),
        customized('b', 'hair', 'x', when: at(0)),
        customized('a', 'hair', 'x', when: at(0)),
      ]);
      expect((await store.all()).map((x) => x.eventId), ['a', 'b', 'c']);
    });

    test('events round-trip with payload and schemaVersion intact', () async {
      final e = built('b1', 2, BuildingType.herbGarden,
          when: at(0),
          tier: 3,
          completesAt: at(240),
          cost: Loot(gems: 2, materials: MaterialBundle({MaterialKind.lumber: 9})));
      final unknown = GameEvent.fromJson({
        'eventId': 'z',
        'deviceId': 'dev-2',
        'actorId': sam,
        'occurredAt': '2026-10-01T20:00:00.000Z',
        'createdAt': '2026-10-01T20:01:00.000Z',
        'schemaVersion': 4,
        'type': 'FromTheFuture',
        'payload': {'k': 'v'},
      });
      await store.append([e, unknown]);
      final back = await store.all();
      expect(back.map((x) => x.toJson()), [e.toJson(), unknown.toJson()]);
    });

    test('watchAll emits the log as it grows', () async {
      final emissions = store.watchAll().map((l) => l.length);
      final expectation = expectLater(emissions, emitsThrough(2));
      await store.append([partyJoined('p1', 'party-1', when: at(0))]);
      await store.append([partyJoined('p2', 'party-1', when: at(1), actor: sam)]);
      await expectation;
    });
  });
}

void main() {
  storeContract('InMemoryGameEventStore', () async {
    final s = InMemoryGameEventStore();
    return (s as GameEventStore, s.dispose);
  });

  storeContract('DriftGameEventStore', () async {
    final db = AppDatabase(NativeDatabase.memory());
    return (DriftGameEventStore(db.gameEventsDao) as GameEventStore, db.close);
  });

  test('game events live apart from the ledger event log', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftGameEventStore(db.gameEventsDao);

    await db.eventsDao.appendEvents([
      MemberSet(
        eventId: 'm1',
        deviceId: 'dev-1',
        userId: robin,
        occurredAt: at(0),
        createdAt: at(0),
        memberId: robin,
        name: 'Robin',
        role: MemberRole.adult,
      ),
    ]);
    await store.append([partyJoined('p1', 'party-1', when: at(0))]);

    expect((await db.eventsDao.allEvents()).map((e) => e.eventId), ['m1']);
    expect((await store.all()).map((e) => e.eventId), ['p1']);
  });
}
