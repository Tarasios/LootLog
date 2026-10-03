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
import 'package:lootlog/domain/state.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/quests/quests_screen.dart';
import 'package:lootlog/features/settings/recurring_screen.dart';

final _t = DateTime.utc(2026, 7, 1);
var _n = 0;

MemberSet _adult(String id, String name) => MemberSet(
      eventId: 'e${(_n++).toString().padLeft(4, '0')}',
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _t,
      createdAt: _t,
      memberId: id,
      name: name,
      role: MemberRole.adult,
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<HouseholdState> state(WidgetTester tester) async =>
      reduce(await tester.runAsync(db.eventsDao.allEvents) ?? []);

  Future<void> pump(WidgetTester tester, List<MemberSet> adults,
      Widget screen) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await db.eventsDao.appendEvents(adults);
      final other = adults.length > 1 ? adults[1] : adults[0];
      await db.localSetupDao.save(LocalSetup(
        timezone: 'America/Vancouver',
        user1: UserProfile(userId: adults[0].memberId, name: adults[0].name),
        user2: UserProfile(userId: other.memberId, name: other.name),
        meUserId: adults[0].memberId,
      ));
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('test-device'),
        blobStoreProvider.overrideWithValue(
            BlobStore(Directory.systemTemp.createTempSync('lootlog_owner'))),
      ],
      child: MaterialApp(home: screen),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester, String label) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, label));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  final three = [_adult('u1', 'Alex'), _adult('u2', 'Blair'), _adult('u3', 'Casey')];

  testWidgets('a savings goal can belong to a third adult', (tester) async {
    await pump(tester, three, const QuestEditorScreen());
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Canoe');
    await tester.enterText(find.widgetWithText(TextField, 'Target'), '1300');
    await tester.tap(find.text('Casey'));
    await tester.pumpAndSettle();
    await tapSave(tester, 'Save goal');

    final q = (await state(tester)).quests.values.single;
    expect((q.ownership as PersonalParty).userId, 'u3');
    await done(tester);
  });

  testWidgets('a recurring expense can belong to a third adult',
      (tester) async {
    await pump(tester, three, const RecurringEditorScreen());
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Gym');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '40');
    await tester.tap(find.text('Casey'));
    await tester.pumpAndSettle();
    await tapSave(tester, 'Save');

    final r = (await state(tester)).recurringExpenses.values.single;
    expect((r.ownership as PersonalParty).userId, 'u3');
    await done(tester);
  });

  testWidgets('a single-adult household sees itself once', (tester) async {
    await pump(tester, [_adult('u1', 'Solo')], const RecurringEditorScreen());
    expect(find.text('Solo'), findsOneWidget);
    await done(tester);
  });
}
