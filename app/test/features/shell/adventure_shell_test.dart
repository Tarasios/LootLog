/// The budget shell in each play mode: an Adventure player gets the panes in
/// game chrome (wood header with Town, wood tabs, the "Adventure log") and no
/// Material navigation rail or bottom bar; a Standard player keeps the rail on
/// desktop and the bottom bar on a phone. Goldens of the Adventure shell on
/// desktop and phone with a small household.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/actions.dart';
import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/providers.dart';
import 'package:lootlog/data/setup/local_setup.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/ledger/ledger_screen.dart';
import 'package:lootlog/features/menu/manage_screen.dart';
import 'package:lootlog/features/settings/play_mode_providers.dart';
import 'package:lootlog/features/shell/adventure_shell_chrome.dart';
import 'package:lootlog/features/shell/app_shell.dart';
import 'package:lootlog/features/tutorial/tutorial_prefs.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/kit/kit.dart';

/// Tour already seen, with no file I/O.
class _SeenTour extends TutorialProgressNotifier {
  @override
  TutorialProgress build() => TutorialProgress.done;
}

/// The pixel tier, with no file I/O.
class _PixelTier extends AdventureTierNotifier {
  @override
  AdventureTier build() => AdventureTier.pixel;
}

const _desktop = Size(1440, 900);
const _phone = Size(390, 844);

/// Two adults; Alex found a $500 gift and spent some of it from the gold
/// pouch on fixed days, so the ledger and the log never depend on today.
List<Event> _household() {
  final setupInstant = DateTime.utc(2025, 3, 1, 18);
  Event member(String id, String name) => MemberSet(
    eventId: 'member-$id',
    deviceId: 'd',
    userId: 'alex',
    occurredAt: setupInstant,
    createdAt: setupInstant,
    memberId: id,
    name: name,
    role: MemberRole.adult,
  );
  Event purchase(String id, int day, String merchant, int amountCents) {
    final instant = DateTime.utc(2025, 3, day, 18);
    return PurchaseAdded(
      eventId: 'purchase-$id',
      deviceId: 'd',
      userId: 'alex',
      occurredAt: instant,
      createdAt: instant,
      purchaseId: id,
      target: const VaultCharge(),
      amountCents: amountCents,
      merchant: merchant,
    );
  }

  return [
    member('alex', 'Alex'),
    member('blair', 'Blair'),
    GiftReceived(
      eventId: 'gift',
      deviceId: 'd',
      userId: 'alex',
      occurredAt: setupInstant,
      createdAt: setupInstant,
      forUserId: 'alex',
      amountCents: 50000,
      note: 'Birthday',
    ),
    purchase('bakery', 3, 'Corner bakery', 1250),
    purchase('books', 7, 'Bookshop', 3499),
    purchase('market', 12, 'Farmers market', 4280),
  ];
}

/// The wood tab labelled [label].
Finder _tab(String label) => find.byWidgetPredicate(
  (widget) => widget is WoodButton && widget.label == label,
);

Future<void> _loadPixelFonts() async {
  for (final (family, asset) in [
    (AdventureTokens.pixelFont, 'assets/fonts/KenneyPixel.ttf'),
    (AdventureTokens.pixelMonoFont, 'assets/fonts/KenneyMiniSquare.ttf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pumpShell(
    WidgetTester tester, {
    required Size size,
    required bool adventure,
    VoidCallback? onOpenHall,
    ShellPane initialPane = ShellPane.ledger,
    AssetRegistry registry = AssetRegistry.empty,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await db.eventsDao.appendEvents(_household());
      await db.localSetupDao.save(
        LocalSetup(
          timezone: 'America/Vancouver',
          user1: const UserProfile(userId: 'alex', name: 'Alex'),
          user2: const UserProfile(userId: 'blair', name: 'Blair'),
          meUserId: 'alex',
        ),
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('test-device'),
          blobStoreProvider.overrideWithValue(
            BlobStore(Directory.systemTemp.createTempSync('lootlog_shell')),
          ),
          tutorialProgressProvider.overrideWith(_SeenTour.new),
          isAdventureProvider.overrideWithValue(adventure),
          adventureTierProvider.overrideWith(_PixelTier.new),
          gameAssetRegistryProvider.overrideWith((ref) async => registry),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: adventure ? AdventureTheme.build() : null,
          home: AppShell(initialPane: initialPane, onOpenHall: onOpenHall),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester);
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  group('Adventure', () {
    testWidgets('desktop: wood tabs and the Adventure log, no rail', (
      tester,
    ) async {
      var townOpened = 0;
      await pumpShell(
        tester,
        size: _desktop,
        adventure: true,
        onOpenHall: () => townOpened++,
        initialPane: ShellPane.goals,
      );
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Adventure log'), findsOneWidget);
      final tabs = find.byType(AdventureTabStrip);
      for (final label in [
        'Dashboard',
        'Ledger',
        'Goals',
        'Treasury',
        'Trophies',
      ]) {
        expect(
          find.descendant(of: tabs, matching: _tab(label)),
          findsOneWidget,
        );
      }

      await tester.tap(find.byKey(const ValueKey('shell-tab-ledger')));
      await settle(tester);
      expect(find.byType(LedgerScreen), findsOneWidget);
      expect(find.text('Corner bakery'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shell-town')));
      await settle(tester);
      expect(townOpened, 1);
      await done(tester);
    });

    testWidgets('Manage opens from the header', (tester) async {
      await pumpShell(
        tester,
        size: _desktop,
        adventure: true,
        onOpenHall: () {},
      );
      await tester.tap(find.widgetWithText(HudButton, 'Manage'));
      await settle(tester);
      expect(find.byType(ManageScreen), findsOneWidget);
      await done(tester);
    });

    testWidgets('the play-mode switch stays reachable from More', (
      tester,
    ) async {
      await pumpShell(
        tester,
        size: _desktop,
        adventure: true,
        onOpenHall: () {},
      );
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Switch to Standard'), findsOneWidget);
      await done(tester);
    });

    testWidgets('phone: wood tabs at the bottom, Activity among them', (
      tester,
    ) async {
      await pumpShell(
        tester,
        size: _phone,
        adventure: true,
        onOpenHall: () {},
        initialPane: ShellPane.funds,
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.takeException(), isNull);
      final tabs = find.byType(AdventureTabStrip);
      for (final label in [
        'Dashboard',
        'Ledger',
        'Goals',
        'Treasury',
        'Activity',
      ]) {
        expect(
          find.descendant(of: tabs, matching: _tab(label)),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('shell-tab-ledger')));
      await settle(tester);
      expect(find.byType(LedgerScreen), findsOneWidget);
      await done(tester);
    });

    testWidgets('no Town button without a town to go back to', (tester) async {
      await pumpShell(tester, size: _desktop, adventure: true);
      expect(find.byKey(const ValueKey('shell-town')), findsNothing);
      await done(tester);
    });
  });

  group('Standard', () {
    testWidgets('desktop keeps the navigation rail', (tester) async {
      await pumpShell(tester, size: _desktop, adventure: false);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(AdventureTabStrip), findsNothing);
      expect(find.text('Adventure log'), findsNothing);
      await done(tester);
    });

    testWidgets('phone keeps the bottom navigation bar', (tester) async {
      await pumpShell(tester, size: _phone, adventure: false);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(AdventureTabStrip), findsNothing);
      await done(tester);
    });
  });

  for (final (name, size) in [('desktop', _desktop), ('phone', _phone)]) {
    testWidgets('golden: Adventure shell $name', (tester) async {
      await tester.runAsync(_loadPixelFonts);
      final registry = (await tester.runAsync(loadGameAssetRegistry))!;
      await pumpShell(
        tester,
        size: size,
        adventure: true,
        onOpenHall: () {},
        registry: registry,
      );
      // Decode the UI pack so the kit's frames paint.
      await tester.runAsync(() async {
        final element = tester.element(find.byType(AppShell));
        await precacheImage(
          AssetImage(
            '${AssetRegistry.assetDir}packs/ui_pixel_adventure/tilemap_packed.png',
          ),
          element,
        ).timeout(const Duration(seconds: 30));
      });
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(AppShell),
        matchesGoldenFile('goldens/adventure_shell_$name.png'),
      );
      await done(tester);
    });
  }
}
