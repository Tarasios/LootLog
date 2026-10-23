import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/actions.dart';
import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/game_rewards.dart';
import 'package:lootlog/data/sync/sync_service.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/ids.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/sync/sync_status.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';

void main() {
  late AppDatabase db;
  late BlobStore blobs;
  late GameRewardRunner runner;
  late HouseholdActions actions;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    blobs = BlobStore(Directory.systemTemp.createTempSync('lootlog_rewards'));
    runner = GameRewardRunner(db: db, deviceId: 'dev');
    actions = HouseholdActions(
      db: db,
      blobs: blobs,
      deviceId: 'dev',
      meUserId: 'u1',
      gameRewards: runner,
    );
  });

  tearDown(() => db.close());

  Future<List<Event>> ledger() => db.eventsDao.allEvents();
  /// Rewards run in the background after a write; wait for them to settle.
  Future<List<GameEvent>> gameLog() async {
    await runner.run();
    return db.gameEventsDao.allGameEvents();
  }
  Future<GameState> game() async => projectGameState(await gameLog());

  Future<void> adopt() => actions.adoptSavingsRules(
        fromMonth: Month.fromInstant(DateTime.now()),
        generalTithePct: 20,
      );

  final today = CalendarDay.fromInstant(DateTime.now());

  test('a logged purchase grants the day pouch right away', () async {
    await actions.addPurchase(target: const VaultCharge(), amountCents: 500);
    final me = (await game()).person('u1');
    expect(me.unclaimedRewards.keys, contains('log.daily:u1:${today.toKey()}'));
    expect(me.streak.loggedDays, {today});
  });

  test('rewards live in the game log, never the ledger', () async {
    await actions.addPurchase(target: const VaultCharge(), amountCents: 500);
    expect(await gameLog(), isNotEmpty);
    expect((await ledger()).whereType<PurchaseAdded>(), hasLength(1));
    expect(await ledger(), hasLength(1));
  });

  test('an edit is marked as one and grants nothing', () async {
    final id =
        await actions.addPurchase(target: const VaultCharge(), amountCents: 500);
    final before = (await gameLog()).length;
    final old = reduce(await ledger()).purchases[id]!;
    final newId = await actions.amendPurchase(old, amountCents: 700);
    final amended = (await ledger())
        .whereType<PurchaseAdded>()
        .singleWhere((p) => p.purchaseId == newId);
    expect(amended.amendsPurchaseId, id);
    expect((await gameLog()).length, before);
  });

  test('voiding a purchase leaves its rewards in place', () async {
    final id =
        await actions.addPurchase(target: const VaultCharge(), amountCents: 500);
    final before = (await game()).person('u1');
    await actions.voidPurchase(id);
    final after = (await game()).person('u1');
    expect(after.seenRewardIds, before.seenRewardIds);
    expect(after.unclaimedRewards.keys, before.unclaimedRewards.keys);
  });

  test('running again after a write adds nothing', () async {
    await actions.addPurchase(target: const VaultCharge(), amountCents: 500);
    final before = (await gameLog()).length;
    expect(await runner.run(), 0);
    expect((await gameLog()).length, before);
  });

  group('the new ledger events', () {
    test('are refused until the household adopts the savings rules',
        () async {
      expect(await actions.checkInNoSpend(), isFalse);
      expect(await actions.completeReconcile(today), isFalse);
      expect(await ledger(), isEmpty);
    });

    test('a no-spend check-in is a ledger event that opens the day',
        () async {
      await adopt();
      expect(await actions.checkInNoSpend(), isTrue);
      expect((await ledger()).whereType<NoSpendCheckedIn>(), hasLength(1));
      expect((await game()).person('u1').streak.loggedDays, {today});
    });

    test('a completed reconcile earns the iron chest and 10 gems', () async {
      await adopt();
      expect(await actions.completeReconcile(today), isTrue);
      final me = (await game()).person('u1');
      expect(me.unopenedChests.values, [ChestType.iron]);
      expect(me.unclaimedRewards.values.single.loot.gems, 10);
    });
  });

  test('a sync merge rewards what arrived', () async {
    final sync = SyncService(
      db: db,
      blobs: blobs,
      deviceName: 'phone',
      onStatus: (SyncStatus _) {},
      afterMerge: runner.run,
    );
    final now = DateTime.now().toUtc();
    final partnerBuy = PurchaseAdded(
      eventId: uuidv7(),
      deviceId: 'partner-phone',
      userId: 'u2',
      occurredAt: now,
      createdAt: now,
      purchaseId: 'p-u2',
      target: const VaultCharge(),
      amountCents: 900,
    );
    await sync.importJsonl(jsonEncode(partnerBuy.toJson()));
    expect((await game()).person('u2').seenRewardIds,
        contains('log.daily:u2:${today.toKey()}'));
  });
}
