import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/blobs/receipt_offload.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/sync/hub_server.dart';
import 'package:lootlog/data/sync/sync_client.dart';
import 'package:lootlog/data/sync/sync_service.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase memDb() => AppDatabase(NativeDatabase.memory());

int _idc = 0;
PurchaseAdded buy(String device, int amount) {
  final id = 'e${(_idc++).toString().padLeft(4, '0')}';
  return PurchaseAdded(
    eventId: id,
    deviceId: device,
    userId: 'u1',
    occurredAt: DateTime.utc(2026, 7, 4, 18),
    createdAt: DateTime.utc(2026, 7, 4, 18),
    purchaseId: 'p-$id',
    target: const SliceCharge('s'),
    amountCents: amount,
  );
}

void main() {
  group('HubHostDao sequencing', () {
    test('assigns a stable, gap-free seq in arrival order', () async {
      final db = memDb();
      addTearDown(db.close);
      await db.eventsDao.appendEvents([buy('d', 1), buy('d', 2)]);
      final max1 = await db.hubHostDao.assignSeqs();
      expect(max1, 2);
      // A newly arrived event gets the next seq; existing seqs are untouched.
      await db.eventsDao.appendEvents([buy('d', 3)]);
      final max2 = await db.hubHostDao.assignSeqs();
      expect(max2, 3);
      final page = await db.hubHostDao.eventsAfter(2);
      expect(page.events.length, 1);
      expect(page.cursor, 3);
    });

    test('assignSeqs is idempotent', () async {
      final db = memDb();
      addTearDown(db.close);
      await db.eventsDao.appendEvents([buy('d', 1)]);
      expect(await db.hubHostDao.assignSeqs(), 1);
      expect(await db.hubHostDao.assignSeqs(), 1);
    });
  });

  group('hub server + sync client over loopback', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('sync-test-');
    });
    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    test('two clients converge through one hub, blobs included', () async {
      final hubDb = memDb();
      final hubBlobs = BlobStore(Directory('${tmp.path}/hub-blobs'));
      final hub = HubServer(
        db: hubDb,
        blobs: hubBlobs,
        hubId: 'hub',
        pairingSecret: 'secret',
      );
      final server = await hub.serve(port: 0);
      final url = 'http://127.0.0.1:${server.port}';
      addTearDown(() async {
        await server.close(force: true);
        await hubDb.close();
      });

      final db1 = memDb();
      final blobs1 = BlobStore(Directory('${tmp.path}/b1'));
      final c1 = SyncClient(db: db1, blobs: blobs1, deviceName: 'one');
      final db2 = memDb();
      final blobs2 = BlobStore(Directory('${tmp.path}/b2'));
      final c2 = SyncClient(db: db2, blobs: blobs2, deviceName: 'two');
      addTearDown(() async {
        c1.close();
        c2.close();
        await db1.close();
        await db2.close();
      });

      await c1.pair(url, 'secret');
      await c2.pair(url, 'secret');

      // Device one records a purchase with a receipt blob.
      final bytes = utf8Bytes('hello-receipt');
      final sha = sha256.convert(bytes).toString();
      await blobs1.save(bytes);
      await db1.eventsDao.appendEvents([
        buy('one', 500),
        ReceiptAttached(
          eventId: 'r1',
          deviceId: 'one',
          userId: 'u1',
          occurredAt: DateTime.utc(2026, 7, 4, 18),
          createdAt: DateTime.utc(2026, 7, 4, 18),
          purchaseId: 'p-e0000',
          sha256: sha,
          mimeType: 'image/jpeg',
          sizeBytes: bytes.length,
        ),
      ]);

      // Push from one, pull into two.
      final r1 = await c1.syncOnce();
      expect(r1.allOk, isTrue);
      expect(r1.hubs.single.pushed, 2);
      expect(r1.hubs.single.blobsPushed, 1);

      final r2 = await c2.syncOnce();
      expect(r2.hubs.single.pulled, 2);
      expect(r2.hubs.single.blobsPulled, 1);

      expect(await blobs2.exists(sha), isTrue);
      final got = await blobs2.read(sha);
      expect(sha256.convert(got).toString(), sha);

      // Re-syncing moves nothing (idempotent).
      final r2b = await c2.syncOnce();
      expect(r2b.hubs.single.pulled, 0);
    });

    test(
        'receipt offload deletes local copies once every hub holds them, '
        'skips re-pulling them, and fetches them back on demand', () async {
      final hubDb = memDb();
      final hub = HubServer(
        db: hubDb,
        blobs: BlobStore(Directory('${tmp.path}/hub-blobs')),
        hubId: 'hub',
        pairingSecret: 'secret',
      );
      final server = await hub.serve(port: 0);
      final url = 'http://127.0.0.1:${server.port}';
      addTearDown(() async {
        await server.close(force: true);
        await hubDb.close();
      });

      final db = memDb();
      final blobs = BlobStore(Directory('${tmp.path}/phone-blobs'));
      final offload =
          ReceiptOffloadStore(dir: () async => Directory(tmp.path));
      final service = SyncService(
        db: db,
        blobs: blobs,
        deviceName: 'phone',
        onStatus: (_) {},
        offload: offload,
      );
      addTearDown(() async {
        await service.dispose();
        await db.close();
      });

      await offload.setEnabled(true);
      await service.pair(url, 'secret');

      final bytes = utf8Bytes('space-hungry-receipt');
      final sha = sha256.convert(bytes).toString();
      await blobs.save(bytes);
      await db.eventsDao.appendEvents([
        buy('phone', 500),
        ReceiptAttached(
          eventId: 'r-off',
          deviceId: 'phone',
          userId: 'u1',
          occurredAt: DateTime.utc(2026, 7, 4, 18),
          createdAt: DateTime.utc(2026, 7, 4, 18),
          purchaseId: 'p-x',
          sha256: sha,
          mimeType: 'image/jpeg',
          sizeBytes: bytes.length,
        ),
      ]);

      // One cycle pushes the blob to the hub and then offloads the local copy.
      final r = await service.syncNow();
      expect(r.allOk, isTrue);
      expect(await blobs.exists(sha), isFalse);
      expect(await offload.shas(), contains(sha));

      // The next cycle must not quietly pull it back.
      await service.syncNow();
      expect(await blobs.exists(sha), isFalse);

      // Viewing the receipt fetches it back on demand and un-marks it.
      expect(await service.fetchBlob(sha), isTrue);
      expect(await blobs.exists(sha), isTrue);
      expect(await offload.shas(), isNot(contains(sha)));

      // With the switch off, nothing is offloaded even after a clean cycle.
      await offload.setEnabled(false);
      await service.syncNow();
      expect(await blobs.exists(sha), isTrue);
    });

    test('a bad pairing secret is rejected; a bad token is unauthorized',
        () async {
      final hubDb = memDb();
      final hub = HubServer(
        db: hubDb,
        blobs: BlobStore(Directory('${tmp.path}/h')),
        hubId: 'hub',
        pairingSecret: 'right',
      );
      final server = await hub.serve(port: 0);
      final url = 'http://127.0.0.1:${server.port}';
      addTearDown(() async {
        await server.close(force: true);
        await hubDb.close();
      });

      final db = memDb();
      final client =
          SyncClient(db: db, blobs: BlobStore(Directory('${tmp.path}/c')), deviceName: 'x');
      addTearDown(() async {
        client.close();
        await db.close();
      });

      await expectLater(
        client.pair(url, 'wrong'),
        throwsA(isA<SyncException>()),
      );
    });
  });
}

List<int> utf8Bytes(String s) => s.codeUnits;
