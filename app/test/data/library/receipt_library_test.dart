/// Unit tests for the receipt-library path/naming projection (pure logic).
/// Confirms deterministic naming, filesystem-safe sanitization, `_2`-style
/// de-duplication, and that rebuilding from scratch produces identical content.
library;

import 'dart:io';

import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/library/receipt_library.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

int _n = 0;
String _id() => 'e${(_n++).toString().padLeft(4, '0')}';

DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

BudgetSliceSet _slice(String id, String name) => BudgetSliceSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 1, 1),
      createdAt: _day(2026, 1, 1),
      sliceId: id,
      name: name,
      ownership: const GroupSlice(),
      limitCents: 100000,
      poolTithePct: 0,
      defaultLeftoverPolicy: const Discretionary(),
      taxDeductibleByDefault: false,
    );

PurchaseAdded _buy({
  required String id,
  required ChargeTarget target,
  required int amount,
  String? merchant,
  required DateTime at,
}) =>
    PurchaseAdded(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: at,
      createdAt: at,
      purchaseId: id,
      target: target,
      amountCents: amount,
      merchant: merchant,
    );

ReceiptAttached _receipt(
  String purchaseId,
  String sha, {
  String mime = 'image/jpeg',
  required DateTime at,
}) =>
    ReceiptAttached(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: at,
      createdAt: at,
      purchaseId: purchaseId,
      sha256: sha,
      mimeType: mime,
      sizeBytes: 10,
    );

void main() {
  group('sanitizeSegment', () {
    test('replaces path-unsafe characters with underscore', () {
      expect(sanitizeSegment('a/b\\c:d*e?f"g<h>i|j'), 'a_b_c_d_e_f_g_h_i_j');
    });

    test('trims edge whitespace and dots and collapses underscores', () {
      expect(sanitizeSegment('  ..Safe  way..  '), 'Safe way');
      expect(sanitizeSegment('a///b'), 'a_b');
    });

    test('falls back when nothing safe remains', () {
      expect(sanitizeSegment('///', fallback: 'x'), 'x');
      expect(sanitizeSegment(''), 'receipt');
    });
  });

  group('extensionForMime', () {
    test('maps known types', () {
      expect(extensionForMime('image/jpeg'), 'jpg');
      expect(extensionForMime('image/png'), 'png');
      expect(extensionForMime('application/pdf'), 'pdf');
    });

    test('degrades gracefully on unknown types', () {
      expect(extensionForMime('application/octet-stream'), 'octetstream');
      expect(extensionForMime('garbage'), 'garbage');
    });
  });

  group('planReceiptLibrary', () {
    test('names a receipt <year>/<slice>/<date>_<merchant>_<amount>.<ext>', () {
      final events = <Event>[
        _slice('groceries', 'Groceries'),
        _buy(
          id: 'p1',
          target: const SliceCharge('groceries'),
          amount: 4210,
          merchant: 'Safeway',
          at: _day(2026, 7, 4),
        ),
        _receipt('p1', 'sha_a', at: _day(2026, 7, 4)),
      ];
      final plan = planReceiptLibrary(reduce(events));
      expect(plan, hasLength(1));
      expect(plan.single.sha256, 'sha_a');
      expect(
        plan.single.relativePath,
        '2026/Groceries/2026-07-04_Safeway_42.10.jpg',
      );
    });

    test("uses 'receipt' when the purchase has no merchant", () {
      final events = <Event>[
        _slice('groceries', 'Groceries'),
        _buy(
          id: 'p1',
          target: const SliceCharge('groceries'),
          amount: 500,
          at: _day(2026, 7, 4),
        ),
        _receipt('p1', 'sha_a', at: _day(2026, 7, 4)),
      ];
      final plan = planReceiptLibrary(reduce(events));
      expect(plan.single.relativePath,
          '2026/Groceries/2026-07-04_receipt_5.00.jpg');
    });

    test('sanitizes merchant and slice name into safe segments', () {
      final events = <Event>[
        _slice('s', 'Pet/Care'),
        _buy(
          id: 'p1',
          target: const SliceCharge('s'),
          amount: 1000,
          merchant: 'A:B*Store',
          at: _day(2026, 7, 4),
        ),
        _receipt('p1', 'sha_a', at: _day(2026, 7, 4)),
      ];
      final plan = planReceiptLibrary(reduce(events));
      expect(plan.single.relativePath,
          '2026/Pet_Care/2026-07-04_A_B_Store_10.00.jpg');
    });

    test('de-duplicates colliding paths with _2, _3 suffixes', () {
      // Two purchases identical in slice/date/merchant/amount, plus a second
      // receipt on one of them: three files collide on the same base name.
      final events = <Event>[
        _slice('groceries', 'Groceries'),
        _buy(
          id: 'p1',
          target: const SliceCharge('groceries'),
          amount: 1000,
          merchant: 'Store',
          at: _day(2026, 7, 4),
        ),
        _receipt('p1', 'sha_a', at: _day(2026, 7, 4)),
        _receipt('p1', 'sha_b', at: _day(2026, 7, 4)),
        _buy(
          id: 'p2',
          target: const SliceCharge('groceries'),
          amount: 1000,
          merchant: 'Store',
          at: _day(2026, 7, 4),
        ),
        _receipt('p2', 'sha_c', at: _day(2026, 7, 4)),
      ];
      final plan = planReceiptLibrary(reduce(events));
      final paths = plan.map((e) => e.relativePath).toList()..sort();
      expect(paths, [
        '2026/Groceries/2026-07-04_Store_10.00.jpg',
        '2026/Groceries/2026-07-04_Store_10.00_2.jpg',
        '2026/Groceries/2026-07-04_Store_10.00_3.jpg',
      ]);
    });

    test('is deterministic: rebuilding yields identical content', () {
      final events = <Event>[
        _slice('groceries', 'Groceries'),
        _slice('fun', 'Fun'),
        _buy(
          id: 'p1',
          target: const SliceCharge('groceries'),
          amount: 1000,
          merchant: 'Store',
          at: _day(2026, 7, 4),
        ),
        _receipt('p1', 'sha_a', at: _day(2026, 7, 4)),
        _receipt('p1', 'sha_b', at: _day(2026, 7, 4)),
        _buy(
          id: 'p2',
          target: const SliceCharge('fun'),
          amount: 2599,
          merchant: 'Arcade',
          at: _day(2026, 8, 1),
        ),
        _receipt('p2', 'sha_c', at: _day(2026, 8, 1)),
      ];
      final first = planReceiptLibrary(reduce(events));
      // Reduce a shuffled copy of the log; the projection must be identical.
      final shuffled = events.reversed.toList();
      final second = planReceiptLibrary(reduce(shuffled));
      String render(List<ReceiptLibraryEntry> p) => (p
              .map((e) => '${e.relativePath}<-${e.sha256}')
              .toList()
            ..sort())
          .join('\n');
      expect(render(second), render(first));
    });

    test('excludes voided purchases and routes non-slice targets by label', () {
      final events = <Event>[
        _slice('groceries', 'Groceries'),
        _buy(
          id: 'p1',
          target: const SliceCharge('groceries'),
          amount: 1000,
          merchant: 'Store',
          at: _day(2026, 7, 4),
        ),
        _receipt('p1', 'sha_a', at: _day(2026, 7, 4)),
        PurchaseVoided(
          eventId: _id(),
          deviceId: 'd',
          userId: 'u1',
          occurredAt: _day(2026, 7, 5),
          createdAt: _day(2026, 7, 5),
          purchaseId: 'p1',
        ),
        _buy(
          id: 'p2',
          target: const VaultCharge(),
          amount: 700,
          merchant: 'Coffee',
          at: _day(2026, 7, 6),
        ),
        _receipt('p2', 'sha_v', at: _day(2026, 7, 6)),
      ];
      final plan = planReceiptLibrary(reduce(events));
      expect(plan, hasLength(1));
      expect(plan.single.sha256, 'sha_v');
      expect(plan.single.relativePath,
          '2026/Vault/2026-07-06_Coffee_7.00.jpg');
    });
  });

  group('projection writes', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('receipt-lib-');
    });
    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    test('re-projecting leaves an already-correct file untouched, and '
        'restores an edited one', () async {
      final blobs = BlobStore(Directory('${tmp.path}/blobs'));
      final bytes = [1, 2, 3, 4];
      final sha = await blobs.save(bytes);
      final events = <Event>[
        _slice('s', 'Food'),
        _buy(
          id: 'p1',
          target: const SliceCharge('s'),
          amount: 1000,
          merchant: 'Store',
          at: _day(2026, 7, 4),
        ),
        _receipt('p1', sha, at: _day(2026, 7, 4)),
      ];
      final state = reduce(events);
      final root = '${tmp.path}/library';

      final first = await projectReceiptLibrary(root, state, blobs);
      expect(first, hasLength(1));
      final file = File('$root/${first.single}');
      final mtime = (await file.stat()).modified;

      // Second projection: content already matches, nothing is written.
      final second = await projectReceiptLibrary(root, state, blobs);
      expect(second, isEmpty);
      expect((await file.stat()).modified, mtime);

      // A user edit inside the folder is restored (projection, not source).
      await file.writeAsBytes([9, 9, 9], flush: true);
      final third = await projectReceiptLibrary(root, state, blobs);
      expect(third, hasLength(1));
      expect(await file.readAsBytes(), bytes);
    });
  });
}
