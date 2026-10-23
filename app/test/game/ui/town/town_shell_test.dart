import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/features/settings/play_mode_switch.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/game_home.dart';
import 'package:lootlog/game/ui/town/town_place_openers.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../hall_harness.dart' show FixedTier, before, sampleEvents, storeWith;
import 'town_test_overrides.dart';

/// Counts toggles instead of writing the tier file.
class RecordingTier extends FixedTier {
  RecordingTier(super.tier);
  int toggles = 0;

  @override
  void toggle() => toggles++;
}

Widget host({
  required AdventureTier tier,
  VoidCallback? onOpenLedger,
  HallLinks links = const HallLinks(),
  InMemoryGameEventStore? liveStore,
  bool registryFails = false,
  TownPlaceOpeners openers = const TownPlaceOpeners(),
  AdventureTierNotifier? tierNotifier,
}) => ProviderScope(
  overrides: townTestOverrides(
    tier: tier,
    tierNotifier: tierNotifier,
    liveStore: liveStore,
    registryFails: registryFails,
  ),
  child: MaterialApp(
    home: TownShell(
      onOpenLedger: onOpenLedger ?? () {},
      links: links,
      openers: openers,
      ambientLife: false,
    ),
  ),
);

/// The Flame scene ticks forever, so pumpAndSettle never settles: advance
/// time in fixed steps instead (enough for a sheet or menu to finish opening).
Future<void> pumpUi(WidgetTester tester) async {
  for (var step = 0; step < 6; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpShell(WidgetTester tester, Widget shell) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(shell);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('pixel tier shows the town scene and the four bottom actions', (
    tester,
  ) async {
    var purchasesOpened = 0;
    await pumpShell(
      tester,
      host(
        tier: AdventureTier.pixel,
        links: HallLinks(logPurchase: (_) => purchasesOpened++),
      ),
    );
    expect(find.byKey(const ValueKey('town-scene')), findsOneWidget);
    for (final label in ['Log a purchase', 'Shop', 'Inbox', 'Budget']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Log a purchase'));
    expect(purchasesOpened, 1);
  });

  testWidgets('text tier shows the guild-hall text screens instead', (
    tester,
  ) async {
    await pumpShell(tester, host(tier: AdventureTier.text));
    expect(find.byType(GameHome), findsOneWidget);
    expect(find.byKey(const ValueKey('town-scene')), findsNothing);
  });

  testWidgets('the top bar shows gems and a live streak', (tester) async {
    await pumpShell(tester, host(tier: AdventureTier.pixel));
    expect(find.byKey(const ValueKey('town-gems')), findsOneWidget);
    expect(find.byKey(const ValueKey('town-streak')), findsOneWidget);
    expect(find.text('130'), findsOneWidget, reason: 'sample hall gems');
    expect(find.text('3-day streak'), findsOneWidget);
  });

  testWidgets('the menu offers the mode switch', (tester) async {
    await pumpShell(tester, host(tier: AdventureTier.pixel));
    expect(find.byType(PlayModeMenuButton), findsOneWidget);
    await tester.tap(find.byType(PlayModeMenuButton));
    await pumpUi(tester);
    expect(find.textContaining('Standard'), findsWidgets);
  });

  testWidgets('the Text mode button toggles the render tier', (tester) async {
    final tier = RecordingTier(AdventureTier.pixel);
    await pumpShell(
      tester,
      host(tier: AdventureTier.pixel, tierNotifier: tier),
    );
    await tester.tap(find.byTooltip('Text mode'));
    expect(tier.toggles, 1);
  });

  testWidgets('Shop without a shop yet explains what is coming', (
    tester,
  ) async {
    await pumpShell(tester, host(tier: AdventureTier.pixel));
    await tester.tap(find.text('Shop'));
    await pumpUi(tester);
    expect(find.textContaining('decorations'), findsOneWidget);
  });

  testWidgets('a given shop opener replaces the coming-soon sheet', (
    tester,
  ) async {
    var shopsOpened = 0;
    await pumpShell(
      tester,
      host(
        tier: AdventureTier.pixel,
        openers: TownPlaceOpeners(openShop: (_) => shopsOpened++),
      ),
    );
    await tester.tap(find.text('Shop'));
    await pumpUi(tester);
    expect(shopsOpened, 1);
    expect(find.textContaining('decorations'), findsNothing);
  });

  testWidgets('Inbox opens the chests and rewards waiting', (tester) async {
    await pumpShell(tester, host(tier: AdventureTier.pixel));
    await tester.tap(find.text('Inbox'));
    await pumpUi(tester);
    expect(find.text('Wood chest'), findsOneWidget);
  });

  testWidgets(
    'Log a purchase falls back to the ledger when no entry link is wired',
    (tester) async {
      var ledgerOpened = 0;
      await pumpShell(
        tester,
        host(tier: AdventureTier.pixel, onOpenLedger: () => ledgerOpened++),
      );
      await tester.tap(find.text('Log a purchase'));
      expect(ledgerOpened, 1);
    },
  );

  testWidgets(
    'a registry that fails to load falls back to bundled art and still shows the scene',
    (tester) async {
      await pumpShell(
        tester,
        host(tier: AdventureTier.pixel, registryFails: true),
      );
      expect(find.byKey(const ValueKey('town-scene')), findsOneWidget);
    },
  );

  group('the starter set', () {
    Widget starterHost(TownTestHarness harness, AdventureTier tier) =>
        ProviderScope(
          overrides: harness.overrides(tier: tier),
          child: MaterialApp(
            home: TownShell(onOpenLedger: () {}, ambientLife: false),
          ),
        );

    Future<List<ItemAcquired>> starterEvents(
      WidgetTester tester,
      TownTestHarness harness,
    ) async {
      final events =
          await tester.runAsync(harness.store.all) ?? const <GameEvent>[];
      return events.whereType<ItemAcquired>().toList();
    }

    testWidgets('a new player is given the starter furniture and a welcome', (
      tester,
    ) async {
      final harness = await TownTestHarness.create();
      await pumpShell(tester, starterHost(harness, AdventureTier.pixel));
      await pumpUi(tester);
      final acquired = await starterEvents(tester, harness);
      expect(
        acquired.map((event) => event.itemId),
        harness.catalog.starterItemIds,
      );
      expect(acquired.every((event) => event.actorId == harness.meId), isTrue);
      expect(find.text('Welcome home'), findsOneWidget);
    });

    testWidgets(
      'a player who already owns a chest item still gets the starter set',
      (tester) async {
        final harness = await TownTestHarness.create();
        await tester.runAsync(
          () => harness.store.append([
            ItemAcquired(
              eventId: 'c0001',
              deviceId: 'test',
              actorId: harness.meId,
              occurredAt: before(const Duration(days: 1)),
              createdAt: before(const Duration(days: 1)),
              acquisitionId: 'chest:c0001',
              itemId: 'plant_pot',
              source: DecorSource.chest,
            ),
          ]),
        );
        await pumpShell(tester, starterHost(harness, AdventureTier.pixel));
        await pumpUi(tester);
        final acquired = await starterEvents(tester, harness);
        expect(
          acquired
              .where((event) => event.source == DecorSource.starter)
              .map((event) => event.itemId),
          harness.catalog.starterItemIds,
        );
        expect(find.text('Welcome home'), findsOneWidget);
      },
    );

    testWidgets(
      'a player who already has the starter set is not given it twice',
      (tester) async {
        final harness = await TownTestHarness.create(starterClaimed: true);
        final before = (await starterEvents(tester, harness)).length;
        await pumpShell(tester, starterHost(harness, AdventureTier.pixel));
        await pumpUi(tester);
        expect((await starterEvents(tester, harness)).length, before);
        expect(find.text('Welcome home'), findsNothing);
      },
    );

    testWidgets('the text tier does not claim the starter set', (tester) async {
      final harness = await TownTestHarness.create();
      await pumpShell(tester, starterHost(harness, AdventureTier.text));
      await pumpUi(tester);
      expect(await starterEvents(tester, harness), isEmpty);
    });
  });

  group('the Inbox sheet stays live', () {
    Future<void> pumpLiveShell(WidgetTester tester) async {
      final store = await tester.runAsync(() => storeWith(sampleEvents()));
      await pumpShell(
        tester,
        host(tier: AdventureTier.pixel, liveStore: store),
      );
      await tester.tap(find.text('Inbox'));
      await pumpUi(tester);
    }

    testWidgets('opening a chest removes its row', (tester) async {
      await pumpLiveShell(tester);
      expect(find.widgetWithText(FilledButton, 'Open'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Open'));
      await pumpUi(tester);
      await tester.tap(find.text('Huzzah!'));
      await pumpUi(tester);

      expect(find.widgetWithText(FilledButton, 'Open'), findsNothing);
    });

    testWidgets('claiming a reward removes its row', (tester) async {
      await pumpLiveShell(tester);
      expect(find.widgetWithText(FilledButton, 'Claim'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Claim'));
      await pumpUi(tester);

      expect(find.widgetWithText(FilledButton, 'Claim'), findsNothing);
    });
  });
}
