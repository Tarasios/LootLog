import 'dart:io';
import 'dart:typed_data';

import 'package:duobudget/data/blobs/blob_store.dart';
import 'package:duobudget/domain/event.dart';
import 'package:duobudget/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int d) => DateTime.utc(2026, 3, d, 18);

ReceiptAttached _attach(String purchase, String sha, {int day = 1}) =>
    ReceiptAttached(
      eventId: 'att-$purchase-$sha',
      deviceId: 'dev',
      userId: 'u1',
      occurredAt: _at(day),
      createdAt: _at(day),
      purchaseId: purchase,
      sha256: sha,
      mimeType: 'image/jpeg',
      sizeBytes: 10,
    );

ReceiptDetached _detach(String purchase, String sha, {int day = 2}) =>
    ReceiptDetached(
      eventId: 'det-$purchase-$sha',
      deviceId: 'dev',
      userId: 'u1',
      occurredAt: _at(day),
      createdAt: _at(day),
      purchaseId: purchase,
      sha256: sha,
    );

QuestSet _quest(String id, String? sprite, {int day = 1}) => QuestSet(
      eventId: 'quest-$id-${sprite ?? 'none'}',
      deviceId: 'dev',
      userId: 'u1',
      occurredAt: _at(day),
      createdAt: _at(day),
      questId: id,
      name: id,
      targetCents: 1000,
      ownership: const PersonalParty('u1'),
      customSpriteSha256: sprite,
    );

void main() {
  late Directory tmp;
  late BlobStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('blobstore_test');
    store = BlobStore(Directory('${tmp.path}/blobs'));
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  group('save / read', () {
    test('round-trips bytes through a content-addressed file', () async {
      final bytes = Uint8List.fromList(List.generate(256, (i) => i));
      final sha = await store.save(bytes);

      expect(sha, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(await store.exists(sha), isTrue);
      expect(await store.read(sha), bytes);
      // The file is named exactly by its hash.
      expect(store.fileFor(sha).path, endsWith('/blobs/$sha'));
    });

    test('double-saving the same bytes is idempotent', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final sha1 = await store.save(bytes);
      final sha2 = await store.save(bytes);

      expect(sha1, sha2);
      final files = store.root.listSync().whereType<File>().toList();
      expect(files, hasLength(1));
      expect(await store.read(sha1), bytes);
    });

    test('distinct content yields distinct blobs', () async {
      final a = await store.save(Uint8List.fromList([1, 2, 3]));
      final b = await store.save(Uint8List.fromList([3, 2, 1]));
      expect(a, isNot(b));
      expect(store.root.listSync().whereType<File>(), hasLength(2));
    });
  });

  group('referencedBlobs', () {
    test('a live receipt attachment is referenced', () {
      final refs = BlobStore.referencedBlobs([_attach('p1', 'aa')]);
      expect(refs, {'aa'});
    });

    test('a detached receipt is no longer referenced', () {
      final refs = BlobStore.referencedBlobs([
        _attach('p1', 'aa'),
        _detach('p1', 'aa'),
      ]);
      expect(refs, isEmpty);
    });

    test('the same sha kept alive by another purchase stays referenced', () {
      final refs = BlobStore.referencedBlobs([
        _attach('p1', 'aa'),
        _attach('p2', 'aa'),
        _detach('p1', 'aa'),
      ]);
      expect(refs, {'aa'});
    });

    test('quest sprites are referenced; superseded ones are not', () {
      final refs = BlobStore.referencedBlobs([
        _quest('q1', 'old', day: 1),
        _quest('q1', 'new', day: 5),
        _quest('q2', null, day: 1),
      ]);
      expect(refs, {'new'});
    });

    test('cosmetic sprite hashes are referenced', () {
      final sha = 'a' * 64;
      final refs = BlobStore.referencedBlobs([
        CosmeticSet(
          eventId: 'c1',
          deviceId: 'dev',
          userId: 'u1',
          occurredAt: _at(1),
          createdAt: _at(1),
          key: 'avatar.u1',
          value: sha,
        ),
      ]);
      expect(refs, {sha});
    });
  });

  group('deletion never touches referenced blobs', () {
    test('delete() refuses a referenced blob but removes an orphan', () async {
      final keep = await store.save(Uint8List.fromList([9, 9, 9]));
      final orphan = await store.save(Uint8List.fromList([8, 8, 8]));

      expect(await store.delete(keep, referenced: {keep}), isFalse);
      expect(await store.exists(keep), isTrue);

      expect(await store.delete(orphan, referenced: {keep}), isTrue);
      expect(await store.exists(orphan), isFalse);
    });

    test('collectGarbage keeps referenced blobs and removes the rest', () async {
      final receiptBytes = Uint8List.fromList([1, 1, 1]);
      final spriteBytes = Uint8List.fromList([2, 2, 2]);
      final orphanBytes = Uint8List.fromList([3, 3, 3]);
      final receiptSha = await store.save(receiptBytes);
      final spriteSha = await store.save(spriteBytes);
      final orphanSha = await store.save(orphanBytes);

      final events = <Event>[
        _attach('p1', receiptSha),
        _quest('q1', spriteSha),
      ];

      final deleted = await store.collectGarbage(events);

      expect(deleted, [orphanSha]);
      expect(await store.exists(receiptSha), isTrue);
      expect(await store.exists(spriteSha), isTrue);
      expect(await store.exists(orphanSha), isFalse);
    });

    test('a blob whose only reference was detached is collectable', () async {
      final sha = await store.save(Uint8List.fromList([7, 7, 7]));
      final events = <Event>[_attach('p1', sha), _detach('p1', sha)];

      final deleted = await store.collectGarbage(events);
      expect(deleted, [sha]);
      expect(await store.exists(sha), isFalse);
    });
  });
}
