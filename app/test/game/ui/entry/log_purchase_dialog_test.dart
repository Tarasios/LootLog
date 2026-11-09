/// Logging a purchase from the Adventure town opens the game dialog over the
/// town, and the dialog writes through the real ledger (an in-memory
/// database): typed digits then a destination log exactly one purchase and
/// close it; Escape closes it without writing; Enter walks to the
/// destinations and presses one; "More details" carries the amount to the
/// full entry screen. Standard mode keeps its full-screen entry.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/actions.dart';
import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/providers.dart';
import 'package:lootlog/data/setup/local_setup.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/entry/expense_entry_screen.dart';
import 'package:lootlog/features/settings/play_mode.dart';
import 'package:lootlog/features/settings/play_mode_providers.dart';
import 'package:lootlog/features/settings/visibility_prefs.dart';
import 'package:lootlog/features/shell/app_shell.dart';
import 'package:lootlog/features/shell/home_gate.dart';
import 'package:lootlog/features/tutorial/tutorial_prefs.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/entry/log_purchase_dialog.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../town/town_test_overrides.dart';

/// Tour already seen, with no file I/O.
class _SeenTour extends TutorialProgressNotifier {
  @override
  TutorialProgress build() => TutorialProgress.done;
}

/// Full household visibility, with no file I/O.
class _ShowEveryone extends ShowHouseholdBudgets {
  @override
  bool build() => true;
}

/// [text] inside the log-purchase dialog (the town behind it may show the
/// same names on its quest board).
Finder inDialog(Finder text) =>
    find.descendant(of: find.byType(LogPurchaseDialog), matching: text);

void main() {
  late AppDatabase db;
  final at = DateTime.now().toUtc();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Alex, one adult, with a personal Groceries budget under Food.
  Future<void> seedLedger(WidgetTester tester) => tester.runAsync(() async {
    await db.eventsDao.appendEvents([
      MemberSet(
        eventId: 'm-u1',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: at,
        createdAt: at,
        memberId: 'u1',
        name: 'Alex',
        role: MemberRole.adult,
      ),
      BudgetSliceSet(
        eventId: 'slice-groceries',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: at,
        createdAt: at,
        sliceId: 'groceries',
        name: 'Groceries',
        ownership: const PersonalSlice('u1'),
        mainCategoryId: 'food',
        limitCents: 40000,
        poolTithePct: 0,
        defaultLeftoverPolicy: const Discretionary(),
        taxDeductibleByDefault: false,
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

  List<Override> ledgerOverrides({required bool adventure}) => [
    appDatabaseProvider.overrideWithValue(db),
    deviceIdProvider.overrideWithValue('test-device'),
    blobStoreProvider.overrideWithValue(
      BlobStore(Directory.systemTemp.createTempSync('lootlog_log_dialog')),
    ),
    tutorialProgressProvider.overrideWith(_SeenTour.new),
    showHouseholdBudgetsProvider.overrideWith(_ShowEveryone.new),
    isAdventureProvider.overrideWithValue(adventure),
  ];

  /// Lets the database's streams and writes run, then advances the frames.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<List<PurchaseAdded>> purchases(WidgetTester tester) async =>
      (await tester.runAsync(db.eventsDao.allEvents))!.whereType<PurchaseAdded>().toList();

  /// The Adventure town on a desktop window, wired to the real hall links.
  Future<void> pumpTown(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seedLedger(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...townTestOverrides(tier: AdventureTier.pixel),
          ...ledgerOverrides(adventure: true),
        ],
        child: MaterialApp(
          theme: AdventureTheme.build(),
          home: TownShell(onOpenLedger: () {}, links: ledgerHallLinks(() {})),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.textContaining('Log purchase'));
    await settle(tester);
    expect(find.byType(LogPurchaseDialog), findsOneWidget);
    expect(find.text('Log a purchase'), findsOneWidget);
  }

  Future<void> typeDigits(WidgetTester tester, List<LogicalKeyboardKey> keys) async {
    for (final key in keys) {
      await tester.sendKeyEvent(key);
    }
    await tester.pump();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  const oneTwoFive = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit5,
  ];

  testWidgets('1, 2, 5 then a budget logs exactly one \$1.25 purchase and '
      'closes the dialog', (tester) async {
    await pumpTown(tester);
    await openDialog(tester);
    expect(find.byType(ExpenseEntryScreen), findsNothing);

    await typeDigits(tester, oneTwoFive);
    expect(find.text('\$1.25'), findsOneWidget);

    await tester.tap(inDialog(find.text('Groceries')));
    await settle(tester);
    await settle(tester);

    final logged = await purchases(tester);
    expect(logged, hasLength(1));
    expect(logged.single.amountCents, 125);
    expect(logged.single.target, const SliceCharge('groceries'));
    expect(logged.single.shared, isFalse);
    expect(find.byType(LogPurchaseDialog), findsNothing);
    expect(find.byType(TownShell), findsOneWidget);
    await done(tester);
  });

  testWidgets('Escape closes the dialog without writing', (tester) async {
    await pumpTown(tester);
    await openDialog(tester);
    await typeDigits(tester, oneTwoFive);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    expect(find.byType(LogPurchaseDialog), findsNothing);
    expect(find.byType(TownShell), findsOneWidget);
    expect(await purchases(tester), isEmpty);
    await done(tester);
  });

  testWidgets('a budget tapped before any amount asks for one and writes '
      'nothing', (tester) async {
    await pumpTown(tester);
    await openDialog(tester);
    await tester.tap(inDialog(find.text('Groceries')));
    await settle(tester);
    expect(find.text('Type the amount first'), findsOneWidget);
    expect(find.byType(LogPurchaseDialog), findsOneWidget);
    expect(await purchases(tester), isEmpty);
    await done(tester);
  });

  testWidgets('Enter moves to the first budget and Enter again logs it', (tester) async {
    await pumpTown(tester);
    await openDialog(tester);
    await typeDigits(tester, oneTwoFive);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(await purchases(tester), isEmpty, reason: 'the first Enter only picks');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    await settle(tester);

    final logged = await purchases(tester);
    expect(logged, hasLength(1));
    expect(logged.single.amountCents, 125);
    expect(logged.single.target, const SliceCharge('groceries'));
    expect(find.byType(LogPurchaseDialog), findsNothing);
    await done(tester);
  });

  testWidgets('More details opens the full entry screen with the typed amount', (tester) async {
    await pumpTown(tester);
    await openDialog(tester);
    await typeDigits(tester, const [LogicalKeyboardKey.digit4, LogicalKeyboardKey.digit2]);

    await tester.tap(inDialog(find.textContaining('More details')));
    await settle(tester);

    expect(find.byType(LogPurchaseDialog), findsNothing);
    expect(find.byType(ExpenseEntryScreen), findsOneWidget);
    expect(find.text('\$0.42'), findsOneWidget);
    expect(await purchases(tester), isEmpty);
    await done(tester);
  });

  testWidgets('Standard mode still logs on the full-screen entry', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seedLedger(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...ledgerOverrides(adventure: false),
          playPrefsProvider.overrideWithValue(
            const PlayPrefs(mode: PlayMode.standard, home: AdventureHome.hall),
          ),
        ],
        child: const MaterialApp(home: HomeGate()),
      ),
    );
    await settle(tester);
    expect(find.byType(AppShell), findsOneWidget);

    await tester.tap(find.text('New'));
    await settle(tester);

    expect(find.byType(ExpenseEntryScreen), findsOneWidget);
    expect(find.byType(LogPurchaseDialog), findsNothing);
    await done(tester);
  });
}
