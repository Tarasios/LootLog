import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/export/event_export.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

PurchaseAdded buy(String id, int amount) => PurchaseAdded(
      eventId: id,
      deviceId: 'd',
      userId: 'u1',
      occurredAt: DateTime.utc(2026, 7, 4, 18),
      createdAt: DateTime.utc(2026, 7, 4, 18),
      purchaseId: 'p-$id',
      target: const SliceCharge('s'),
      amountCents: amount,
    );

void main() {
  test('.dbevents round-trips events losslessly', () {
    final events = [buy('e2', 200), buy('e1', 100)];
    final text = exportEventsJsonl(events);
    final back = importEventsJsonl(text);
    expect(back.length, 2);
    // Canonical order: e1 then e2 (same instant, id tie-break).
    expect(back[0].eventId, 'e1');
    expect(back.map((e) => (e as PurchaseAdded).amountCents), [100, 200]);
  });

  test('a corrupt .dbevents line raises ImportException', () {
    expect(
      () => importEventsJsonl('{"good": false}\nnot-json'),
      throwsA(isA<ImportException>()),
    );
  });

  test('.dbevents.zip carries and verifies referenced blobs', () async {
    final tmp = await Directory.systemTemp.createTemp('exp-');
    addTearDown(() => tmp.delete(recursive: true));
    final blobs = BlobStore(Directory('${tmp.path}/blobs'));
    final bytes = [1, 2, 3, 4, 5];
    final sha = await blobs.save(bytes);

    final events = [
      buy('e1', 100),
      ReceiptAttached(
        eventId: 'r1',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: DateTime.utc(2026, 7, 4, 18),
        createdAt: DateTime.utc(2026, 7, 4, 18),
        purchaseId: 'p-e1',
        sha256: sha,
        mimeType: 'application/octet-stream',
        sizeBytes: bytes.length,
      ),
    ];
    final zip = await exportEventsZip(events, blobs);

    final imported = readEventsZip(zip);
    expect(imported.events.length, 2);
    expect(imported.blobs.containsKey(sha), isTrue);
    expect(sha256.convert(imported.blobs[sha]!).toString(), sha);
  });

  test('a tampered blob raises BlobIntegrityException', () {
    // A zip that claims a blob hash but carries mutated bytes.
    final claimedSha = sha256.convert([9, 9, 9]).toString();
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('events.jsonl', utf8.encode('')))
      ..addFile(ArchiveFile.bytes('blobs/$claimedSha', [9, 9, 8]));
    final badZip = ZipEncoder().encodeBytes(archive);
    expect(
      () => readEventsZip(badZip),
      throwsA(isA<BlobIntegrityException>()),
    );
  });
}
