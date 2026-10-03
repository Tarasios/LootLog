import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/sync/hub_server.dart';
import 'package:lootlog/data/sync/sync_client.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

AppDatabase memDb() => AppDatabase(NativeDatabase.memory());

PartyJoined joined(String id, {String actor = 'u1', int minute = 0}) =>
    PartyJoined(
      eventId: id,
      deviceId: 'dev',
      actorId: actor,
      occurredAt: DateTime.utc(2026, 10, 1, 18, minute),
      createdAt: DateTime.utc(2026, 10, 1, 18, minute),
      partyId: 'party-1',
    );

PurchaseAdded buy(String id) => PurchaseAdded(
      eventId: id,
      deviceId: 'dev',
      userId: 'u1',
      occurredAt: DateTime.utc(2026, 10, 1, 18),
      createdAt: DateTime.utc(2026, 10, 1, 18),
      purchaseId: 'p-$id',
      target: const VaultCharge(),
      amountCents: 100,
    );

/// A raw game event from a newer release this build cannot interpret.
GameEvent fromTheFuture(String id) => GameEvent.fromJson({
      'eventId': id,
      'deviceId': 'dev-new',
      'actorId': 'u2',
      'occurredAt': '2026-10-01T19:00:00.000Z',
      'createdAt': '2026-10-01T19:00:00.000Z',
      'schemaVersion': 3,
      'type': 'PetAdopted',
      'payload': {'petId': 'p1', 'nested': {'a': 1}},
    });

Future<Set<String>> gameIds(AppDatabase db) async =>
    {for (final e in await db.gameEventsDao.allGameEvents()) e.eventId};

Future<Set<String>> ledgerIds(AppDatabase db) async =>
    {for (final e in await db.eventsDao.allEvents()) e.eventId};

void main() {
  group('GameSyncDao hub sequencing', () {
    test('assigns a stable seq in arrival order and pages after a cursor',
        () async {
      final db = memDb();
      addTearDown(db.close);
      await db.gameEventsDao.appendGameEvents([joined('g1'), joined('g2')]);
      expect(await db.gameSyncDao.assignHostedSeqs(), 2);
      await db.gameEventsDao.appendGameEvents([joined('g0', minute: 0)]);
      expect(await db.gameSyncDao.assignHostedSeqs(), 3);
      expect(await db.gameSyncDao.assignHostedSeqs(), 3, reason: 'idempotent');

      final page = await db.gameSyncDao.hostedAfter(2);
      expect(page.events.map((e) => e.eventId), ['g0']);
      expect(page.cursor, 3);
      final first = await db.gameSyncDao.hostedAfter(0, limit: 1);
      expect(first.events.map((e) => e.eventId), ['g1']);
      expect(first.cursor, 1);
    });

    test('game seqs are independent of the ledger seqs', () async {
      final db = memDb();
      addTearDown(db.close);
      await db.eventsDao.appendEvents([buy('e1'), buy('e2')]);
      await db.gameEventsDao.appendGameEvents([joined('g1')]);
      expect(await db.hubHostDao.assignSeqs(), 2);
      expect(await db.gameSyncDao.assignHostedSeqs(), 1);
    });
  });

  group('game events over the LAN hub', () {
    late Directory tmp;
    final cleanups = <Future<void> Function()>[];
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('game-sync-');
    });
    tearDown(() async {
      for (final c in cleanups.reversed) {
        await c();
      }
      cleanups.clear();
      await tmp.delete(recursive: true);
    });

    /// Hosts a hub; [gameRoutes] false simulates a hub from a release that
    /// predates game sync (its router 404s the unknown paths).
    Future<(AppDatabase, String)> hostHub({bool gameRoutes = true}) async {
      final db = memDb();
      final hub = HubServer(
        db: db,
        blobs: BlobStore(Directory('${tmp.path}/hub-${cleanups.length}')),
        hubId: 'hub-${cleanups.length}',
        pairingSecret: 'secret',
      );
      await hub.ready();
      Handler handler = hub.handler;
      if (!gameRoutes) {
        handler = (req) => req.url.path.startsWith('game-events')
            ? Response.notFound('{"error":"not found"}')
            : hub.handler(req);
      }
      final server = await shelf_io.serve(handler, '127.0.0.1', 0);
      cleanups.add(() async {
        await server.close(force: true);
        await db.close();
      });
      return (db, 'http://127.0.0.1:${server.port}');
    }

    Future<(AppDatabase, SyncClient)> device(String name) async {
      final db = memDb();
      final client = SyncClient(
        db: db,
        blobs: BlobStore(Directory('${tmp.path}/$name')),
        deviceName: name,
      );
      cleanups.add(() async {
        client.close();
        await db.close();
      });
      return (db, client);
    }

    test('two devices converge their game logs through one hub, apart from '
        'the ledger', () async {
      final (hubDb, url) = await hostHub();
      final (db1, c1) = await device('one');
      final (db2, c2) = await device('two');
      await c1.pair(url, 'secret');
      await c2.pair(url, 'secret');

      await db1.eventsDao.appendEvents([buy('e1')]);
      await db1.gameEventsDao.appendGameEvents([joined('g1'), joined('g2')]);
      await db2.gameEventsDao
          .appendGameEvents([joined('g3', actor: 'u2', minute: 5)]);

      final r1 = await c1.syncOnce();
      expect(r1.allOk, isTrue);
      expect(r1.hubs.single.gamePushed, 2);
      final r2 = await c2.syncOnce();
      expect(r2.hubs.single.gamePushed, 1);
      // Like the ledger, a pull page also echoes the device's own just-pushed
      // event back (an idempotent no-op), so count at least the two new ones.
      expect(r2.hubs.single.gamePulled, greaterThanOrEqualTo(2));
      await c1.syncOnce();

      for (final db in [db1, db2, hubDb]) {
        expect(await gameIds(db), {'g1', 'g2', 'g3'});
      }
      expect(await ledgerIds(db2), {'e1'});
      expect(await ledgerIds(hubDb), {'e1'},
          reason: 'game events never enter the ledger log');

      // Steady state: nothing is re-pushed or re-pulled.
      final again = await c1.syncOnce();
      expect(again.hubs.single.gamePushed, 0);
      expect(again.hubs.single.gamePulled, 0);
    });

    test('game events authored on the hub device reach its clients', () async {
      final (hubDb, url) = await hostHub();
      final (db1, c1) = await device('one');
      await c1.pair(url, 'secret');

      await hubDb.gameEventsDao.appendGameEvents([joined('g-hub')]);
      final r = await c1.syncOnce();
      expect(r.hubs.single.gamePulled, 1);
      expect(await gameIds(db1), {'g-hub'});
    });

    test('a game event from a newer release relays byte-identically', () async {
      final (_, url) = await hostHub();
      final (db1, c1) = await device('one');
      final (db2, c2) = await device('two');
      await c1.pair(url, 'secret');
      await c2.pair(url, 'secret');

      final future = fromTheFuture('g-new');
      await db1.gameEventsDao.appendGameEvents([future]);
      await c1.syncOnce();
      await c2.syncOnce();

      final relayed = (await db2.gameEventsDao.allGameEvents()).single;
      expect(relayed, isA<UnknownGameEvent>());
      expect(relayed.toJson(), future.toJson());
    });

    test('a hub that predates game sync keeps the ledger syncing and holds '
        'game events until it is updated', () async {
      final (oldHubDb, url) = await hostHub(gameRoutes: false);
      final (db1, c1) = await device('one');
      await c1.pair(url, 'secret');

      await db1.eventsDao.appendEvents([buy('e1')]);
      await db1.gameEventsDao.appendGameEvents([joined('g1')]);
      final r = await c1.syncOnce();
      expect(r.allOk, isTrue, reason: 'an old hub is not a sync failure');
      expect(r.hubs.single.gameSupported, isFalse);
      expect(r.hubs.single.gamePushed, 0);
      expect(await ledgerIds(oldHubDb), {'e1'});

      // The same device later pairs with an updated hub: the held game
      // events go out (they were never marked pushed anywhere).
      final (newHubDb, newUrl) = await hostHub();
      await c1.pair(newUrl, 'secret');
      final r2 = await c1.syncOnce();
      expect(r2.allOk, isTrue);
      expect(await gameIds(newHubDb), {'g1'});
    });

    test('a hub rejects a malformed game event batch without storing it',
        () async {
      final (hubDb, url) = await hostHub();
      final client = HttpClient();
      addTearDown(client.close);
      final (_, c1) = await device('one');
      await c1.pair(url, 'secret');
      final token = (await c1.db.pairedHubDao.all()).single.deviceToken;

      final req = await client.postUrl(Uri.parse('$url/game-events'));
      req.headers
        ..set('authorization', 'Bearer $token')
        ..contentType = ContentType.json;
      req.write('{"events": "nope"}');
      final res = await req.close();
      await res.drain<void>();
      expect(res.statusCode, 400);
      expect(await gameIds(hubDb), isEmpty);
    });
  });
}
