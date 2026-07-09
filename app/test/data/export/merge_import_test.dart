import 'package:duobudget/data/export/merge_import.dart';
import 'package:duobudget/domain/event.dart';
import 'package:duobudget/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

PurchaseAdded buy(String id) => PurchaseAdded(
      eventId: id,
      deviceId: 'd',
      userId: 'u1',
      occurredAt: DateTime.utc(2026, 7, 4, 18),
      createdAt: DateTime.utc(2026, 7, 4, 18),
      purchaseId: 'p-$id',
      target: const SliceCharge('s'),
      amountCents: 100,
    );

void main() {
  group('computeMergePreview', () {
    test('counts new vs already-present events and receipts', () {
      final preview = computeMergePreview(
        incomingEvents: [buy('a'), buy('b'), buy('c')],
        existingEventIds: {'a'}, // one already present
        incomingBlobShas: ['sha1', 'sha2'],
        existingBlobShas: {'sha2'}, // one already present
      );
      expect(preview.newEvents, 2);
      expect(preview.presentEvents, 1);
      expect(preview.newReceipts, 1);
      expect(preview.presentReceipts, 1);
      expect(preview.totalEvents, 3);
      expect(preview.isNoOp, isFalse);
    });

    test('a fully-overlapping file is a no-op', () {
      final preview = computeMergePreview(
        incomingEvents: [buy('a'), buy('b')],
        existingEventIds: {'a', 'b'},
        incomingBlobShas: const ['sha1'],
        existingBlobShas: {'sha1'},
      );
      expect(preview.newEvents, 0);
      expect(preview.newReceipts, 0);
      expect(preview.isNoOp, isTrue);
    });

    test('duplicate ids/shas within the file are counted once', () {
      final preview = computeMergePreview(
        incomingEvents: [buy('a'), buy('a'), buy('b')],
        existingEventIds: const {},
        incomingBlobShas: const ['sha1', 'sha1'],
        existingBlobShas: const {},
      );
      expect(preview.newEvents, 2);
      expect(preview.newReceipts, 1);
    });
  });

  group('MergePreview.describe', () {
    test('matches the CLAUDE.md example shape', () {
      const preview = MergePreview(
        newEvents: 14,
        presentEvents: 210,
        newReceipts: 3,
        presentReceipts: 0,
      );
      expect(preview.describe(), '14 new events, 3 receipts — 210 already present');
    });

    test('omits receipts when none are new and singularizes counts', () {
      const preview = MergePreview(
        newEvents: 1,
        presentEvents: 0,
        newReceipts: 0,
        presentReceipts: 5,
      );
      expect(preview.describe(), '1 new event');
    });

    test('shows the already-present tail with no new receipts', () {
      const preview = MergePreview(
        newEvents: 0,
        presentEvents: 12,
        newReceipts: 0,
        presentReceipts: 0,
      );
      expect(preview.describe(), '0 new events — 12 already present');
    });
  });
}
