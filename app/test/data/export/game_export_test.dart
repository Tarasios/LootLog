import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/export/event_export.dart';
import 'package:lootlog/data/export/merge_import.dart';
import 'package:lootlog/data/sync/sync_service.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/domain/game_event.dart';

PartyJoined joined(String id, {int minute = 0}) => PartyJoined(
      eventId: id,
      deviceId: 'dev',
      actorId: 'u1',
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

class Device {
  Device(String name, Directory tmp)
      : db = AppDatabase(NativeDatabase.memory()),
        blobs = BlobStore(Directory('${tmp.path}/$name')) {
    service =
        SyncService(db: db, blobs: blobs, deviceName: name, onStatus: (_) {});
  }

  final AppDatabase db;
  final BlobStore blobs;
  late final SyncService service;

  Future<Set<String>> gameIds() async =>
      {for (final e in await db.gameEventsDao.allGameEvents()) e.eventId};

  Future<void> dispose() async {
    await service.dispose();
    await db.close();
  }
}

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('game-export-');
  });
  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('.dbevents.zip', () {
    test('carries game events in their own entry, leaving events.jsonl '
        'ledger-only for older readers', () async {
      final blobs = BlobStore(Directory('${tmp.path}/b'));
      final bytes = await exportEventsZip([buy('e1')], blobs,
          gameEvents: [joined('g2', minute: 1), joined('g1')]);

      final archive = ZipDecoder().decodeBytes(bytes);
      final ledgerText =
          utf8.decode(archive.findFile(kEventsEntryName)!.content as List<int>);
      expect(importEventsJsonl(ledgerText).map((e) => e.eventId), ['e1']);
      expect(archive.findFile(kGameEventsEntryName), isNotNull);

      final read = readEventsZip(bytes);
      expect(read.events.map((e) => e.eventId), ['e1']);
      expect(read.gameEvents.map((e) => e.eventId), ['g1', 'g2'],
          reason: 'canonical order');
    });

    test('an archive from before game sync reads with no game events', () {
      final archive = Archive()
        ..addFile(ArchiveFile.bytes(
            kEventsEntryName, utf8.encode(exportEventsJsonl([buy('e1')]))));
      final read = readEventsZip(ZipEncoder().encodeBytes(archive));
      expect(read.events, hasLength(1));
      expect(read.gameEvents, isEmpty);
    });

    test('a malformed game line is an ImportException', () {
      final archive = Archive()
        ..addFile(ArchiveFile.bytes(kEventsEntryName, utf8.encode('')))
        ..addFile(ArchiveFile.bytes(kGameEventsEntryName, utf8.encode('{nope')));
      expect(() => readEventsZip(ZipEncoder().encodeBytes(archive)),
          throwsA(isA<ImportException>()));
    });
  });

  test('the merge preview counts game events', () {
    final preview = computeMergePreview(
      incomingEvents: const [],
      existingEventIds: const {},
      incomingBlobShas: const [],
      existingBlobShas: const {},
      incomingGameEvents: [joined('g1'), joined('g2'), joined('g2')],
      existingGameEventIds: const {'g1'},
    );
    expect(preview.newGameEvents, 1);
    expect(preview.presentGameEvents, 1);
    expect(preview.isNoOp, isFalse);
    expect(preview.describe(), '0 new events, 1 game event — 1 already present');
  });

  group('SyncService file swap', () {
    test('a full archive moves game events to another device, idempotently',
        () async {
      final a = Device('a', tmp);
      final b = Device('b', tmp);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.db.eventsDao.appendEvents([buy('e1')]);
      await a.db.gameEventsDao.appendGameEvents([joined('g1'), joined('g2')]);

      final bytes = await a.service.exportArchive();
      final prepared = await b.service.prepareImportArchive(bytes);
      expect(prepared.preview.newGameEvents, 2);
      await b.service.applyImport(prepared);
      expect(await b.gameIds(), {'g1', 'g2'});

      final again = await b.service.importArchive(bytes);
      expect(again.newGameEvents, 0);
      expect(again.presentGameEvents, 2);
      expect(again.isNoOp, isTrue);
    });

    test('export-since-last-export includes only new game events, even when '
        'no ledger event is new', () async {
      final a = Device('a', tmp);
      addTearDown(a.dispose);
      await a.db.eventsDao.appendEvents([buy('e1')]);
      await a.db.gameEventsDao.appendGameEvents([joined('g1')]);
      await a.service.exportArchive();
      expect(await a.service.exportSinceLastExport(), isNull);

      await a.db.gameEventsDao.appendGameEvents([joined('g2', minute: 1)]);
      final inc = await a.service.exportSinceLastExport();
      expect(inc, isNotNull);
      expect(inc!.eventCount, 0);
      expect(inc.gameEventCount, 1);
      expect(readEventsZip(inc.bytes).gameEvents.map((e) => e.eventId), ['g2']);
      expect(await a.service.exportSinceLastExport(), isNull);
    });
  });
}
