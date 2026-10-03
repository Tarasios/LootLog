import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/actions.dart';
import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/providers.dart';
import 'package:lootlog/data/setup/local_setup.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/categories/category_editor_screen.dart';

final _t = DateTime.utc(2026, 7, 1);
var _n = 0;
String _id() => 'e${(_n++).toString().padLeft(4, '0')}';

MemberSet _member(String id, String name, MemberRole role) => MemberSet(
  eventId: _id(),
  deviceId: 'd',
  userId: 'u1',
  occurredAt: _t,
  createdAt: _t,
  memberId: id,
  name: name,
  role: role,
);

BudgetSliceSet _litter() => BudgetSliceSet(
  eventId: _id(),
  deviceId: 'd',
  userId: 'u1',
  occurredAt: _t,
  createdAt: _t,
  sliceId: 'litter',
  name: 'Litter',
  ownership: const GroupSlice(),
  limitCents: 4000,
  poolTithePct: 0,
  defaultLeftoverPolicy: const Discretionary(),
  taxDeductibleByDefault: false,
  petOwnerIds: const ['cat1', 'cat2'],
);

void main() {
  late AppDatabase db;

  Future<void> pumpEditor(WidgetTester tester, {String? sliceId}) async {
    // Tall enough that the whole editor list is built (ListView is lazy).
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await db.eventsDao.appendEvents([
        _member('u1', 'Alex', MemberRole.adult),
        _member('u2', 'Blair', MemberRole.adult),
        _member('u3', 'Casey', MemberRole.adult),
        _member('cat1', 'Miso', MemberRole.pet),
        _member('cat2', 'Tofu', MemberRole.pet),
        _litter(),
      ]);
      // The legacy two-profile shape only knows about two adults.
      await db.localSetupDao.save(
        LocalSetup(
          timezone: 'America/Vancouver',
          user1: const UserProfile(userId: 'u1', name: 'Alex'),
          user2: const UserProfile(userId: 'u2', name: 'Blair'),
          meUserId: 'u1',
        ),
      );
    });
    final state = reduce(await tester.runAsync(db.eventsDao.allEvents) ?? []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('test-device'),
          blobStoreProvider.overrideWithValue(
            BlobStore(Directory.systemTemp.createTempSync('lootlog_cat')),
          ),
        ],
        child: MaterialApp(
          home: CategoryEditorScreen(
            existing: sliceId == null ? null : state.slices[sliceId],
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  // The save handler writes to drift, which needs real async; dispatch the tap
  // inside runAsync so the handler's futures run outside the fake clock.
  Future<void> save(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Save category'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  // Unmount so drift's stream-cancel timers fire before the binding checks for
  // pending timers.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('editing a pet-owned category keeps its pet owners', (
    tester,
  ) async {
    await pumpEditor(tester, sliceId: 'litter');

    await tester.enterText(
      find.widgetWithText(TextField, 'Monthly limit'),
      '45',
    );
    await tester.ensureVisible(find.text('Save category'));
    await save(tester);

    final state = reduce(await tester.runAsync(db.eventsDao.allEvents) ?? []);
    expect(state.slices['litter']!.limitCents, 4500);
    expect(state.slices['litter']!.petOwnerIds, ['cat1', 'cat2']);
    await done(tester);
  });

  testWidgets('pets can be chosen as owners of a group category', (
    tester,
  ) async {
    await pumpEditor(tester, sliceId: 'litter');

    expect(find.widgetWithText(FilterChip, 'Miso'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Tofu'));
    await tester.tap(find.widgetWithText(FilterChip, 'Tofu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save category'));
    await save(tester);

    final state = reduce(await tester.runAsync(db.eventsDao.allEvents) ?? []);
    expect(state.slices['litter']!.petOwnerIds, ['cat1']);
    await done(tester);
  });

  testWidgets('every active adult is offered as an owner, not just two', (
    tester,
  ) async {
    await pumpEditor(tester);

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Blair'), findsOneWidget);
    expect(find.text('Casey'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Books');
    await tester.enterText(
      find.widgetWithText(TextField, 'Monthly limit'),
      '30',
    );
    await tester.tap(find.text('Casey'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save category'));
    await save(tester);

    final state = reduce(await tester.runAsync(db.eventsDao.allEvents) ?? []);
    final books = state.slices.values.firstWhere((s) => s.name == 'Books');
    expect(books.ownerUserId, 'u3');
    await done(tester);
  });

  testWidgets('with the savings rules on, the tax field reads "Carry tax"', (
    tester,
  ) async {
    await tester.runAsync(
      () => db.eventsDao.appendEvents([
        SettingChanged(
          eventId: 'rules',
          deviceId: 'd',
          userId: 'u1',
          occurredAt: _t,
          createdAt: _t,
          key: 'savingsRules',
          value: {'fromMonth': '2026-01', 'generalTithePct': 20},
        ),
      ]),
    );
    await pumpEditor(tester);
    expect(find.widgetWithText(TextField, 'Carry tax %'), findsOneWidget);
    expect(find.text('Shared-savings cut %'), findsNothing);
    await done(tester);
  });
}
