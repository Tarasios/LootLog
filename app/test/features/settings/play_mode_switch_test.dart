/// The shared Adventure / Standard switch: present in both modes (ledger
/// overflow menu, guild hall overflow menu, top of Settings), confirmed with a
/// one-line reassurance, and switching both ways through the real event log.
/// The old in-scene "Classic" button is gone.
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
import 'package:lootlog/features/settings/play_mode.dart';
import 'package:lootlog/features/settings/play_mode_providers.dart';
import 'package:lootlog/features/settings/settings_screen.dart';
import 'package:lootlog/features/settings/visibility_prefs.dart';
import 'package:lootlog/features/shell/app_shell.dart';
import 'package:lootlog/features/shell/home_gate.dart';
import 'package:lootlog/features/tutorial/tutorial_prefs.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/game_home.dart';
import 'package:lootlog/ui/glossary.dart';

/// Tour already seen, with no file I/O.
class _SeenTour extends TutorialProgressNotifier {
  @override
  TutorialProgress build() => TutorialProgress.done;
}

/// The text tier, with no file I/O.
class _TextTier extends AdventureTierNotifier {
  @override
  AdventureTier build() => AdventureTier.text;
}

/// Everyone's budgets shown, with no file I/O.
class _ShowEveryone extends ShowHouseholdBudgets {
  @override
  bool build() => true;
}

const _meUserId = 'u1';

void main() {
  late AppDatabase db;
  final seededAt = DateTime.utc(2026, 10, 1, 12);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  CosmeticSet playSetting(String key, String value) => CosmeticSet(
        eventId: 'setting-$key',
        deviceId: 'd',
        userId: _meUserId,
        occurredAt: seededAt,
        createdAt: seededAt,
        key: key,
        value: value,
      );

  Future<PlayMode> recordedMode() async =>
      resolvePlayPrefs(await db.eventsDao.allEvents(), _meUserId).mode;

  /// Lets drift writes and stream updates land, then rebuilds.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pump(
    WidgetTester tester, {
    required PlayMode mode,
    AdventureHome home = AdventureHome.hall,
    Widget screen = const HomeGate(),
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await db.eventsDao.appendEvents([
        MemberSet(
          eventId: 'member-u1',
          deviceId: 'd',
          userId: _meUserId,
          occurredAt: seededAt,
          createdAt: seededAt,
          memberId: _meUserId,
          name: 'Alex',
          role: MemberRole.adult,
        ),
        playSetting(playModeKey(_meUserId), mode.name),
        playSetting(adventureHomeKey(_meUserId), home.name),
      ]);
      await db.localSetupDao.save(
        LocalSetup(
          timezone: 'America/Vancouver',
          user1: const UserProfile(userId: _meUserId, name: 'Alex'),
          user2: const UserProfile(userId: 'u2', name: 'Blair'),
          meUserId: _meUserId,
        ),
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('test-device'),
          blobStoreProvider.overrideWithValue(
            BlobStore(Directory.systemTemp.createTempSync('lootlog_switch')),
          ),
          tutorialProgressProvider.overrideWith(_SeenTour.new),
          legacySkinModeProvider.overrideWith((ref) async => null),
          adventureTierProvider.overrideWith(_TextTier.new),
          showHouseholdBudgetsProvider.overrideWith(_ShowEveryone.new),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await settle(tester);
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Opens the app-bar overflow and picks the Adventure / Standard entry.
  Future<void> openMenuSwitch(WidgetTester tester, String expectedLabel) async {
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text(Glossary.playMode.classic), findsOneWidget);
    await tester.tap(find.text(expectedLabel));
    await tester.pumpAndSettle();
  }

  Future<void> confirmSwitch(WidgetTester tester) async {
    expect(find.text(Glossary.playModeSwitchReassurance), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Switch'));
    await settle(tester);
  }

  testWidgets('from Standard you can switch to Adventure and back',
      (tester) async {
    await pump(tester, mode: PlayMode.standard);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(GameHome), findsNothing);

    // Into Adventure from the ledger's overflow menu.
    await openMenuSwitch(tester, 'Switch to Adventure');
    expect(find.text('Switch to Adventure?'), findsOneWidget);
    await confirmSwitch(tester);

    expect(await tester.runAsync(recordedMode), PlayMode.adventure);
    expect(find.byType(GameHome), findsOneWidget);

    // And back to Standard from the guild hall's overflow menu.
    await openMenuSwitch(tester, 'Switch to Standard');
    await confirmSwitch(tester);

    expect(await tester.runAsync(recordedMode), PlayMode.standard);
    expect(find.byType(GameHome), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byTooltip('Guild hall'), findsNothing);
    await done(tester);
  });

  testWidgets('cancelling the confirmation keeps the current mode',
      (tester) async {
    await pump(tester, mode: PlayMode.standard);

    await openMenuSwitch(tester, 'Switch to Adventure');
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(await tester.runAsync(recordedMode), PlayMode.standard);
    expect(find.byType(GameHome), findsNothing);
    await done(tester);
  });

  testWidgets('the Adventure ledger offers the switch and no Classic button',
      (tester) async {
    await pump(tester, mode: PlayMode.adventure, home: AdventureHome.ledger);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byTooltip('Guild hall'), findsOneWidget);
    expect(find.text('Classic'), findsNothing);

    await openMenuSwitch(tester, 'Switch to Standard');
    await confirmSwitch(tester);

    expect(await tester.runAsync(recordedMode), PlayMode.standard);
    expect(find.byTooltip('Guild hall'), findsNothing);
    await done(tester);
  });

  testWidgets('Settings starts with the switch, in both modes', (tester) async {
    await pump(tester, mode: PlayMode.standard, screen: const SettingsScreen());
    final switchLabel = find.text(Glossary.playMode.classic);
    expect(switchLabel, findsOneWidget);
    expect(
      tester.getTopLeft(switchLabel).dy,
      lessThan(tester.getTopLeft(find.text('Members')).dy),
      reason: 'the switch sits above every other setting',
    );

    await tester.tap(find.text('Adventure'));
    await tester.pumpAndSettle();
    await confirmSwitch(tester);
    expect(await tester.runAsync(recordedMode), PlayMode.adventure);
    expect(find.text(Glossary.playMode.classic), findsOneWidget);

    await tester.tap(find.text('Standard'));
    await tester.pumpAndSettle();
    await confirmSwitch(tester);
    expect(await tester.runAsync(recordedMode), PlayMode.standard);
    await done(tester);
  });
}
