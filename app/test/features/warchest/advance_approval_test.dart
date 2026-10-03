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
import 'package:lootlog/features/warchest/warchest_screen.dart';

void main() {
  late AppDatabase db;
  final t = DateTime.now().toUtc();
  final month = '${t.year}-${t.month.toString().padLeft(2, '0')}';

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  MemberSet adult(String id, String name) => MemberSet(
        eventId: 'm-$id',
        deviceId: 'd',
        userId: id,
        occurredAt: t,
        createdAt: t,
        memberId: id,
        name: name,
        role: MemberRole.adult,
      );

  Future<void> pump(WidgetTester tester, {required String me}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await db.eventsDao.appendEvents([
        adult('u1', 'Alex'),
        adult('u2', 'Blair'),
        SettingChanged(
          eventId: 'rules',
          deviceId: 'd',
          userId: 'u1',
          occurredAt: t,
          createdAt: t,
          key: 'savingsRules',
          value: {'fromMonth': month, 'generalTithePct': 20},
        ),
        BudgetSliceSet(
          eventId: 'slice',
          deviceId: 'd',
          userId: 'u2',
          occurredAt: t,
          createdAt: t,
          sliceId: 'clothes',
          name: 'Clothing',
          ownership: const PersonalSlice('u2'),
          limitCents: 25000,
          poolTithePct: 10,
          defaultLeftoverPolicy: const CarryInSlice(),
          taxDeductibleByDefault: false,
        ),
        AllowanceAdvanceProposed(
          eventId: 'adv',
          deviceId: 'd',
          userId: 'u2',
          occurredAt: t,
          createdAt: t,
          advanceId: 'a1',
          byUserId: 'u2',
          sliceId: 'clothes',
          amountCents: 5000,
          months: 2,
        ),
      ]);
      await db.localSetupDao.save(LocalSetup(
        timezone: 'America/Vancouver',
        user1: UserProfile(userId: me, name: me == 'u1' ? 'Alex' : 'Blair'),
        user2: const UserProfile(userId: 'u2', name: 'Blair'),
        meUserId: me,
      ));
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('test-device'),
        blobStoreProvider.overrideWithValue(
            BlobStore(Directory.systemTemp.createTempSync('lootlog_adv'))),
      ],
      child: const MaterialApp(home: WarChestScreen()),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('another adult can approve a borrowing request', (tester) async {
    await pump(tester, me: 'u1');
    expect(find.textContaining('Clothing over 2 months'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    final s = reduce(await tester.runAsync(db.eventsDao.allEvents) ?? []);
    expect(s.advances['a1']!.status, WithdrawalStatus.approved);
    await done(tester);
  });

  testWidgets('the requester sees it waiting, with no approve button',
      (tester) async {
    await pump(tester, me: 'u2');
    expect(find.textContaining('Waiting for another adult'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Approve'), findsNothing);
    await done(tester);
  });
}
