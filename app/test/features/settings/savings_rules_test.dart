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
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/settings/savings_rules_card.dart';

final _t = DateTime.utc(2026, 7, 1);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<HouseholdState> state(WidgetTester tester) async =>
      reduce(await tester.runAsync(db.eventsDao.allEvents) ?? []);

  Future<void> pump(WidgetTester tester, {List<Event> seed = const []}) async {
    await tester.runAsync(() async {
      await db.eventsDao.appendEvents([
        MemberSet(
          eventId: 'm1',
          deviceId: 'd',
          userId: 'u1',
          occurredAt: _t,
          createdAt: _t,
          memberId: 'u1',
          name: 'Alex',
          role: MemberRole.adult,
        ),
        ...seed,
      ]);
      await db.localSetupDao.save(LocalSetup(
        timezone: 'America/Vancouver',
        user1: const UserProfile(userId: 'u1', name: 'Alex'),
        user2: const UserProfile(userId: 'u1', name: 'Alex'),
        meUserId: 'u1',
      ));
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('test-device'),
        blobStoreProvider.overrideWithValue(
            BlobStore(Directory.systemTemp.createTempSync('lootlog_rules'))),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: SavingsRulesCard())),
      ),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  Future<void> tapReal(WidgetTester tester, Finder f) async {
    await tester.runAsync(() async {
      await tester.tap(f);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('adopting turns the savings rules on from this month',
      (tester) async {
    await pump(tester);
    expect(find.textContaining('Update LootLog on every device'), findsOneWidget);

    await tapReal(tester, find.text('Adopt from this month'));

    final rules = (await state(tester)).savingsRules!;
    final now = Month.fromInstant(DateTime.now());
    expect(rules.fromMonth, now);
    expect(rules.generalRateFor(now), kDefaultGeneralTithePct);
    await done(tester);
  });

  testWidgets('a custom general rate is used when adopting', (tester) async {
    await pump(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'General savings tax'), '30');
    await tapReal(tester, find.text('Adopt from this month'));

    final now = Month.fromInstant(DateTime.now());
    expect((await state(tester)).savingsRules!.generalRateFor(now), 30);
    await done(tester);
  });

  testWidgets('once adopted it shows when the rules started', (tester) async {
    await pump(tester, seed: [
      SettingChanged(
        eventId: 'r1',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _t,
        createdAt: _t,
        key: 'savingsRules',
        value: {'fromMonth': '2026-07', 'generalTithePct': 25},
      ),
    ]);
    expect(find.textContaining('Active since July 2026'), findsOneWidget);
    expect(find.textContaining('25%'), findsOneWidget);
    expect(find.text('Adopt from this month'), findsNothing);
    await done(tester);
  });
}
