import 'dart:async';

import 'package:drift/native.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/providers.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/state.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

BudgetSliceSet _slice(String id) => BudgetSliceSet(
      eventId: 'slice-$id',
      deviceId: 'dev',
      userId: 'u1',
      occurredAt: _day(2026, 3, 1),
      createdAt: _day(2026, 3, 1),
      sliceId: id,
      name: id,
      ownership: const PersonalSlice('u1'),
      limitCents: 100000,
      poolTithePct: 0,
      defaultLeftoverPolicy: const Discretionary(),
      taxDeductibleByDefault: false,
    );

PurchaseAdded _buy(String id, String slice, int cents) => PurchaseAdded(
      eventId: 'buy-$id',
      deviceId: 'dev',
      userId: 'u1',
      occurredAt: _day(2026, 3, 15),
      createdAt: _day(2026, 3, 15),
      purchaseId: id,
      target: SliceCharge(slice),
      amountCents: cents,
    );

AppDatabase _memoryDb() => AppDatabase(NativeDatabase.memory());

void main() {
  group('EventsDao', () {
    test('appendEvents then watch/replay reflects the new state', () async {
      final db = _memoryDb();
      addTearDown(db.close);

      // The reduced state derived from the live event stream.
      final states = db.eventsDao.watchAllEvents().map(reduce);
      final expectation = expectLater(
        states,
        emitsThrough(
          predicate<HouseholdState>(
            (s) =>
                s.slices.containsKey('s1') &&
                s.sliceMonth('s1', const Month(2026, 3))?.spentCents == 500,
          ),
        ),
      );

      await db.eventsDao.appendEvents([_slice('s1'), _buy('p1', 's1', 500)]);
      await expectation;
    });

    test('appendEvents is idempotent on eventId', () async {
      final db = _memoryDb();
      addTearDown(db.close);

      final slice = _slice('s1');
      await db.eventsDao.appendEvents([slice]);
      // Re-appending the same event (a re-sync / replay) is a no-op.
      await db.eventsDao.appendEvents([slice, slice]);

      final all = await db.eventsDao.allEvents();
      expect(all, hasLength(1));
      expect(all.single.eventId, 'slice-s1');
    });

    test('round-trips an event losslessly through the row encoding', () async {
      final db = _memoryDb();
      addTearDown(db.close);

      final original = PurchaseAdded(
        eventId: 'buy-x',
        deviceId: 'dev',
        userId: 'u1',
        occurredAt: DateTime.utc(2026, 3, 15, 18, 30, 45, 123),
        createdAt: DateTime.utc(2026, 3, 15, 18, 30, 46, 789),
        purchaseId: 'x',
        target: const SliceCharge('s1'),
        amountCents: 1234,
        merchant: 'Corner Store',
        note: 'snacks',
      );
      await db.eventsDao.appendEvents([original]);

      final loaded = (await db.eventsDao.allEvents()).single as PurchaseAdded;
      expect(loaded.occurredAt, original.occurredAt);
      expect(loaded.createdAt, original.createdAt);
      expect(loaded.amountCents, 1234);
      expect(loaded.merchant, 'Corner Store');
      expect(loaded.note, 'snacks');
    });
  });

  group('SyncDao', () {
    test('pull cursor defaults to 0 and is updatable per hub', () async {
      final db = _memoryDb();
      addTearDown(db.close);

      expect(await db.syncDao.pullCursor('hubA'), 0);
      await db.syncDao.setPullCursor('hubA', 42);
      await db.syncDao.setPullCursor('hubB', 7);
      expect(await db.syncDao.pullCursor('hubA'), 42);
      expect(await db.syncDao.pullCursor('hubB'), 7);
    });

    test('tracks unpushed events per hub independently', () async {
      final db = _memoryDb();
      addTearDown(db.close);

      await db.eventsDao.appendEvents([_slice('s1'), _buy('p1', 's1', 500)]);

      // Nothing pushed yet: both events are pending for every hub.
      final pendingA = await db.syncDao.unpushedEventsForHub('hubA');
      expect(pendingA.map((e) => e.eventId), ['slice-s1', 'buy-p1']);

      // Push one event to hubA only.
      await db.syncDao.markPushed('hubA', ['slice-s1']);
      expect(
        (await db.syncDao.unpushedEventsForHub('hubA')).map((e) => e.eventId),
        ['buy-p1'],
      );
      // hubB is unaffected — still needs both.
      expect(
        (await db.syncDao.unpushedEventsForHub('hubB')).map((e) => e.eventId),
        ['slice-s1', 'buy-p1'],
      );

      // markPushed is idempotent.
      await db.syncDao.markPushed('hubA', ['slice-s1', 'buy-p1']);
      await db.syncDao.markPushed('hubA', ['buy-p1']);
      expect(await db.syncDao.unpushedEventsForHub('hubA'), isEmpty);
    });
  });

  group('householdStateProvider', () {
    test('emits reduced state that updates when events are appended', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final completer = Completer<HouseholdState>();
      final sub = container.listen<AsyncValue<HouseholdState>>(
        householdStateProvider,
        (_, next) {
          final v = next.value;
          if (v != null &&
              v.slices.containsKey('s1') &&
              !completer.isCompleted) {
            completer.complete(v);
          }
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await db.eventsDao.appendEvents([_slice('s1'), _buy('p1', 's1', 500)]);

      final state = await completer.future.timeout(const Duration(seconds: 5));
      expect(state.sliceMonth('s1', const Month(2026, 3))?.spentCents, 500);
    });
  });
}
