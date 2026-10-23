/// The Funds hub is a first-class destination on phone and desktop: the war
/// chest, emergency funds and vacations are reachable from the navigation bar,
/// never only through Manage. An open vacation leads the hub.
library;

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
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/settings/emergency_funds_screen.dart';
import 'package:lootlog/features/settings/play_mode_providers.dart';
import 'package:lootlog/features/shell/app_shell.dart';
import 'package:lootlog/features/tutorial/tutorial_prefs.dart';
import 'package:lootlog/features/vacation/vacation_screen.dart';
import 'package:lootlog/features/warchest/warchest_screen.dart';

/// Tour already seen, with no file I/O.
class _SeenTour extends TutorialProgressNotifier {
  @override
  TutorialProgress build() => TutorialProgress.done;
}

void main() {
  late AppDatabase db;
  final t = DateTime.now().toUtc();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    bool adventure = false,
    bool withVacation = false,
    ShellPane initialPane = ShellPane.dashboard,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await db.eventsDao.appendEvents([
        MemberSet(
          eventId: 'm-u1',
          deviceId: 'd',
          userId: 'u1',
          occurredAt: t,
          createdAt: t,
          memberId: 'u1',
          name: 'Alex',
          role: MemberRole.adult,
        ),
        EmergencyFundSet(
          eventId: 'fund',
          deviceId: 'd',
          userId: 'u1',
          occurredAt: t,
          createdAt: t,
          fundId: 'vet',
          name: 'Vet bills',
        ),
        if (withVacation)
          VacationSet(
            eventId: 'vac',
            deviceId: 'd',
            userId: 'u1',
            occurredAt: t,
            createdAt: t,
            vacationId: 'v1',
            name: 'Tofino',
            fund: const VacationFundEmergency('vet'),
            startDate: t.subtract(const Duration(days: 1)),
            endDate: t.add(const Duration(days: 5)),
            categories: const [
              VacationCategory(
                categoryId: 'food',
                name: 'Food',
                limitCents: 30000,
              ),
            ],
          ),
      ]);
      await db.localSetupDao.save(
        LocalSetup(
          timezone: 'America/Vancouver',
          user1: const UserProfile(userId: 'u1', name: 'Alex'),
          user2: const UserProfile(userId: 'u2', name: 'Blair'),
          meUserId: 'u1',
        ),
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('test-device'),
          blobStoreProvider.overrideWithValue(
            BlobStore(Directory.systemTemp.createTempSync('lootlog_nav')),
          ),
          tutorialProgressProvider.overrideWith(_SeenTour.new),
          isAdventureProvider.overrideWithValue(adventure),
        ],
        child: MaterialApp(home: AppShell(initialPane: initialPane)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> openFunds(WidgetTester tester, Finder nav) async {
    await tester.tap(find.descendant(of: nav, matching: find.text('Funds')));
    await settle(tester);
  }

  Future<void> backTo(WidgetTester tester) async {
    await tester.pageBack();
    await settle(tester);
  }

  Future<void> reachesEverything(WidgetTester tester, Finder nav) async {
    await openFunds(tester, nav);
    // The hub lists the war chest, emergency funds (with balances) and
    // vacations.
    expect(find.text('Shared savings'), findsOneWidget);
    expect(find.text('Emergency funds'), findsOneWidget);
    expect(find.text('Vet bills'), findsOneWidget);
    expect(find.text('Vacations'), findsOneWidget);

    await tester.tap(find.text('Emergency funds'));
    await settle(tester);
    expect(find.byType(EmergencyFundsScreen), findsOneWidget);
    await backTo(tester);

    await tester.tap(find.text('Vacations'));
    await settle(tester);
    expect(find.byType(VacationScreen), findsOneWidget);
    await backTo(tester);

    await tester.tap(find.text('Shared savings'));
    await settle(tester);
    expect(find.byType(WarChestScreen), findsOneWidget);
    await backTo(tester);
  }

  testWidgets('phone: the bottom bar has Funds, which reaches the war chest, '
      'emergency funds and vacations', (tester) async {
    await pump(tester, size: const Size(390, 844));
    final nav = find.byType(NavigationBar);
    expect(nav, findsOneWidget);
    for (final label in ['Dashboard', 'Ledger', 'Goals', 'Funds', 'Activity']) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
        reason: '$label is in the bottom bar',
      );
    }
    await reachesEverything(tester, nav);
    await done(tester);
  });

  testWidgets('desktop: the rail has Funds, which reaches the war chest, '
      'emergency funds and vacations', (tester) async {
    await pump(tester, size: const Size(1280, 900));
    final nav = find.byType(NavigationRail);
    expect(nav, findsOneWidget);
    for (final label in ['Dashboard', 'Ledger', 'Goals', 'Funds', 'Trophies']) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
        reason: '$label is on the rail',
      );
    }
    await reachesEverything(tester, nav);
    await done(tester);
  });

  testWidgets('an open vacation leads the Funds hub', (tester) async {
    await pump(tester, size: const Size(390, 844), withVacation: true);
    await openFunds(tester, find.byType(NavigationBar));
    expect(find.text('On vacation · Tofino'), findsOneWidget);
    await tester.tap(find.text('On vacation · Tofino'));
    await settle(tester);
    expect(find.byType(VacationScreen), findsOneWidget);
    await done(tester);
  });

  testWidgets('Adventure names the hub the Treasury', (tester) async {
    // Start off the dashboard: the Adventure dashboard loads game assets.
    await pump(
      tester,
      size: const Size(390, 844),
      adventure: true,
      initialPane: ShellPane.funds,
    );
    final nav = find.byType(NavigationBar);
    expect(
      find.descendant(of: nav, matching: find.text('Treasury')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Treasury')),
      findsOneWidget,
    );
    expect(find.text('Reserve caches'), findsOneWidget);
    expect(find.text('Expeditions'), findsOneWidget);
    await done(tester);
  });
}
