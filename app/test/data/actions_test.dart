import 'dart:io';

import 'package:drift/native.dart';
import 'package:lootlog/data/actions.dart';
import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/state.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late HouseholdActions actions;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    actions = HouseholdActions(
      db: db,
      blobs: BlobStore(Directory.systemTemp.createTempSync('lootlog_test')),
      deviceId: 'dev',
      meUserId: 'u1',
    );
  });

  tearDown(() => db.close());

  Future<HouseholdState> currentState() async =>
      reduce(await db.eventsDao.allEvents());

  test('addPurchase appends a PurchaseAdded the reducer sees', () async {
    final id = await actions.addPurchase(
      target: const VaultCharge(),
      amountCents: 1299,
      merchant: 'Corner Store',
    );

    final purchase = (await currentState()).purchases[id]!;
    expect(purchase.amountCents, 1299);
    expect(purchase.merchant, 'Corner Store');
    expect(purchase.voided, isFalse);
  });

  test('shared is forced off for quest/emergency targets', () async {
    final id = await actions.addPurchase(
      target: const QuestCharge('q1'),
      amountCents: 500,
      shared: true,
    );
    expect((await currentState()).purchases[id]!.shared, isFalse);
  });

  test('amendPurchase voids the old purchase, edits fields, keeps receipts',
      () async {
    final oldId = await actions.addPurchase(
      target: const VaultCharge(),
      amountCents: 1000,
      merchant: 'Old Name',
    );

    // Attach a receipt reference directly (no image encoding needed here).
    final now = DateTime.now().toUtc();
    await db.eventsDao.appendEvents([
      ReceiptAttached(
        eventId: 'r1',
        deviceId: 'dev',
        userId: 'u1',
        occurredAt: now,
        createdAt: now,
        purchaseId: oldId,
        sha256: 'a' * 64,
        mimeType: 'image/jpeg',
        sizeBytes: 42,
      ),
    ]);

    final old = (await currentState()).purchases[oldId]!;
    expect(old.receipts, hasLength(1));

    final newId = await actions.amendPurchase(old, merchant: 'New Name');

    final state = await currentState();
    expect(state.purchases[oldId]!.voided, isTrue);
    final updated = state.purchases[newId]!;
    expect(updated.voided, isFalse);
    expect(updated.merchant, 'New Name');
    expect(updated.amountCents, 1000); // unchanged
    expect(updated.receipts.map((r) => r.sha256), ['a' * 64]);
  });

  test('detachReceipt removes the reference from the purchase', () async {
    final id = await actions.addPurchase(
      target: const VaultCharge(),
      amountCents: 100,
    );
    final now = DateTime.now().toUtc();
    await db.eventsDao.appendEvents([
      ReceiptAttached(
        eventId: 'r1',
        deviceId: 'dev',
        userId: 'u1',
        occurredAt: now,
        createdAt: now,
        purchaseId: id,
        sha256: 'b' * 64,
        mimeType: 'image/jpeg',
        sizeBytes: 10,
      ),
    ]);
    expect((await currentState()).purchases[id]!.receipts, hasLength(1));

    await actions.detachReceipt(id, 'b' * 64);
    expect((await currentState()).purchases[id]!.receipts, isEmpty);
  });
}
