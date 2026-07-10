import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/sync/sync_service.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase memDb() => AppDatabase(NativeDatabase.memory());

PurchaseAdded buy(String id, String device) => PurchaseAdded(
      eventId: id,
      deviceId: device,
      userId: 'u1',
      occurredAt: DateTime.utc(2026, 7, 4, 18),
      createdAt: DateTime.utc(2026, 7, 4, 18),
      purchaseId: 'p-$id',
      target: const SliceCharge('s'),
      amountCents: 100,
    );

ReceiptAttached attach(String id, String purchaseId, String sha, int size) =>
    ReceiptAttached(
      eventId: id,
      deviceId: 'd',
      userId: 'u1',
      occurredAt: DateTime.utc(2026, 7, 4, 18),
      createdAt: DateTime.utc(2026, 7, 4, 18),
      purchaseId: purchaseId,
      sha256: sha,
      mimeType: 'image/jpeg',
      sizeBytes: size,
    );

/// A device: an in-memory DB, a temp-dir blob store, and its SyncService.
class Device {
  Device(this.name, Directory tmp)
      : db = memDb(),
        blobs = BlobStore(Directory('${tmp.path}/$name-blobs')) {
    service = SyncService(
      db: db,
      blobs: blobs,
      deviceName: name,
      onStatus: (_) {},
    );
  }

  final String name;
  final AppDatabase db;
  final BlobStore blobs;
  late final SyncService service;

  Future<Set<String>> eventIds() async =>
      {for (final e in await db.eventsDao.allEvents()) e.eventId};
}

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('merge-');
  });
  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('two offline devices exchanging exports converge; re-import is a no-op',
      () async {
    final a = Device('a', tmp);
    final b = Device('b', tmp);
    addTearDown(() async {
      await a.service.dispose();
      await b.service.dispose();
      await a.db.close();
      await b.db.close();
    });

    // Each device works offline, authoring DISJOINT events, one with a receipt.
    final aBytes = utf8.encode('a-receipt');
    final aSha = sha256.convert(aBytes).toString();
    await a.blobs.save(aBytes);
    await a.db.eventsDao.appendEvents([
      buy('a1', 'a'),
      buy('a2', 'a'),
      attach('a3', 'p-a1', aSha, aBytes.length),
    ]);

    final bBytes = utf8.encode('b-receipt');
    final bSha = sha256.convert(bBytes).toString();
    await b.blobs.save(bBytes);
    await b.db.eventsDao.appendEvents([
      buy('b1', 'b'),
      buy('b2', 'b'),
      attach('b3', 'p-b1', bSha, bBytes.length),
    ]);

    // A -> file -> B. B previews (all new), then applies.
    final fileFromA = await a.service.exportArchive();
    final previewOnB = await b.service.prepareImportArchive(fileFromA);
    expect(previewOnB.preview.newEvents, 3);
    expect(previewOnB.preview.presentEvents, 0);
    expect(previewOnB.preview.newReceipts, 1);
    expect(previewOnB.preview.describe(), '3 new events, 1 receipt');
    final appliedOnB = await b.service.applyImport(previewOnB);
    expect(appliedOnB.newEvents, 3);
    expect(await b.blobs.exists(aSha), isTrue);

    // B now holds all six events; its export carries them plus both receipts.
    final fileFromB = await b.service.exportArchive();
    final previewOnA = await a.service.prepareImportArchive(fileFromB);
    // A already has its own 3; B's 3 are new.
    expect(previewOnA.preview.newEvents, 3);
    expect(previewOnA.preview.presentEvents, 3);
    expect(previewOnA.preview.newReceipts, 1); // b's receipt is new to A
    expect(previewOnA.preview.presentReceipts, 1); // a's own receipt
    await a.service.applyImport(previewOnA);

    // Both devices have converged to the same six events and both receipts.
    final ids = {'a1', 'a2', 'a3', 'b1', 'b2', 'b3'};
    expect(await a.eventIds(), ids);
    expect(await b.eventIds(), ids);
    expect(await a.blobs.exists(bSha), isTrue);
    expect(await b.blobs.exists(aSha), isTrue);

    // Re-importing the same file changes nothing: a true no-op.
    final again = await a.service.prepareImportArchive(fileFromB);
    expect(again.preview.isNoOp, isTrue);
    expect(again.preview.newEvents, 0);
    final reapplied = await a.service.applyImport(again);
    expect(reapplied.isNoOp, isTrue);
    expect(await a.eventIds(), ids);
  });

  test('.dbevents (no zip) round-trips and converges too', () async {
    final a = Device('a', tmp);
    final b = Device('b', tmp);
    addTearDown(() async {
      await a.service.dispose();
      await b.service.dispose();
      await a.db.close();
      await b.db.close();
    });

    await a.db.eventsDao.appendEvents([buy('a1', 'a'), buy('a2', 'a')]);
    final jsonl = exportJsonlOf(await a.db.eventsDao.allEvents());

    final prepared = await b.service.prepareImportJsonl(jsonl);
    expect(prepared.preview.newEvents, 2);
    expect(prepared.preview.newReceipts, 0);
    await b.service.applyImport(prepared);
    expect(await b.eventIds(), {'a1', 'a2'});

    // Re-import is a no-op.
    final again = await b.service.prepareImportJsonl(jsonl);
    expect(again.preview.isNoOp, isTrue);
  });

  group('export since last export', () {
    test('sends only what has arrived since the previous export', () async {
      final a = Device('a', tmp);
      addTearDown(() async {
        await a.service.dispose();
        await a.db.close();
      });

      await a.db.eventsDao.appendEvents([buy('a1', 'a'), buy('a2', 'a')]);
      final first = await a.service.exportSinceLastExport();
      expect(first, isNotNull);
      expect(first!.eventCount, 2);

      // Nothing new yet.
      expect(await a.service.exportSinceLastExport(), isNull);

      // A new local event is picked up on the next incremental export.
      await a.db.eventsDao.appendEvents([buy('a3', 'a')]);
      final second = await a.service.exportSinceLastExport();
      expect(second!.eventCount, 1);
      expect(await a.service.exportSinceLastExport(), isNull);
    });

    test('a full export advances the cursor', () async {
      final a = Device('a', tmp);
      addTearDown(() async {
        await a.service.dispose();
        await a.db.close();
      });

      await a.db.eventsDao.appendEvents([buy('a1', 'a')]);
      await a.service.exportArchive();
      // Full export consumed everything, so there is nothing new to send.
      expect(await a.service.exportSinceLastExport(), isNull);
    });

    test('imported events are relayed by a later incremental export', () async {
      // The cursor rides SQLite rowid (local insertion order), so events merged
      // in from another device are included in a subsequent "export new" — the
      // property that makes the shortcut safe to relay through a third device.
      final a = Device('a', tmp);
      final b = Device('b', tmp);
      addTearDown(() async {
        await a.service.dispose();
        await b.service.dispose();
        await a.db.close();
        await b.db.close();
      });

      await a.db.eventsDao.appendEvents([buy('a1', 'a')]);
      await a.service.exportArchive(); // cursor now past a1

      // B hands A a disjoint event via a file; A imports it.
      await b.db.eventsDao.appendEvents([buy('b1', 'b')]);
      final fromB = await b.service.exportArchive();
      await a.service.applyImport(await a.service.prepareImportArchive(fromB));

      // A's incremental export relays the imported b1 even though b1 was created
      // before A's last export.
      final relay = await a.service.exportSinceLastExport();
      expect(relay, isNotNull);
      expect(relay!.eventCount, 1);
    });
  });
}

String exportJsonlOf(List<Event> events) {
  final b = StringBuffer();
  for (final e in events) {
    b.writeln(jsonEncode(e.toJson()));
  }
  return b.toString();
}
