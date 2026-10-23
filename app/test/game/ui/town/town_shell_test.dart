import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/features/settings/play_mode_switch.dart';
import 'package:lootlog/game/battle/month_end_battle.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/reason_codes.dart';
import 'package:lootlog/game/domain/town/town_view.dart';
import 'package:lootlog/game/scenes/town/town_scene_view.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_screen.dart';
import 'package:lootlog/game/ui/game_home.dart';
import 'package:lootlog/game/ui/hall_habits.dart';
import 'package:lootlog/game/ui/hall_ledger_view.dart';
import 'package:lootlog/game/ui/logged_voice.dart';
import 'package:lootlog/game/ui/town/town_place_openers.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../../../features/spoils/spoils_fixtures.dart';
import '../hall_harness.dart'
    show
        FakeHabits,
        FixedTier,
        before,
        granted,
        robin,
        testLoggedPurchasesProvider,
        kShippedCatalog,
        sampleEvents,
        sampleView,
        storeWith;
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
  DecorCatalog catalog = DecorCatalog.empty,
  MonthEndBattle? battle,
  GameState? game,
  HallHabits? habits,
  HallLedgerView? view,
}) => ProviderScope(
  overrides: townTestOverrides(
    tier: tier,
    battle: battle,
    game: game,
    habits: habits,
    view: view,
    catalog: catalog,
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

  group('the dungeon gate', () {
    TownSceneView scene(WidgetTester tester) =>
        tester.widget<TownSceneView>(find.byKey(const ValueKey('town-scene')));

    testWidgets('with no month-end waiting the gate is not lit', (
      tester,
    ) async {
      // The household only started budgeting this month.
      await pumpShell(
        tester,
        host(
          tier: AdventureTier.pixel,
          view: sampleView(firstBudgetMonth: const Month(2026, 10)),
        ),
      );
      expect(scene(tester).view.dungeonOpen, isFalse);
    });

    testWidgets(
      'a finished month whose chest has not come home opens the gate, '
      'leftovers or not',
      (tester) async {
        await pumpShell(
          tester,
          host(
            tier: AdventureTier.pixel,
            view: sampleView(firstBudgetMonth: const Month(2026, 9)),
          ),
        );
        expect(scene(tester).view.dungeonOpen, isTrue);
      },
    );

    testWidgets('with a pending ritual the gate glows and opens the dungeon', (
      tester,
    ) async {
      final (household, ritual) = ritualFixture();
      await pumpShell(
        tester,
        host(
          tier: AdventureTier.pixel,
          battle: MonthEndBattle.from(ritual, household),
          openers: const TownPlaceOpeners(openDungeon: DungeonScreen.open),
        ),
      );
      expect(scene(tester).view.dungeonOpen, isTrue);
      // The gate sits off-screen at the default zoom, so hand the scene's
      // tap result straight to the shell.
      scene(tester).onTarget(const GateTarget());
      await pumpUi(tester);
      expect(find.byType(DungeonScreen), findsOneWidget);
    });
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
        // Items so chests can be opened, but no starter set to claim.
        host(
          tier: AdventureTier.pixel,
          liveStore: store,
          catalog: DecorCatalog(kShippedCatalog.items),
        ),
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

  group('habits in the town', () {
    Finder noSpendChip() => find.descendant(
      of: find.byKey(const ValueKey('town-no-spend')),
      matching: find.byType(ActionChip),
    );

    testWidgets('"No spend today" sits beside Log a purchase and checks in', (
      tester,
    ) async {
      final habits = FakeHabits();
      await pumpShell(
        tester,
        host(
          tier: AdventureTier.pixel,
          game: GameState.initial(),
          habits: habits,
        ),
      );
      expect(find.text('No spend today'), findsOneWidget);
      await tester.tap(find.text('No spend today'));
      await pumpUi(tester);
      expect(habits.checkIns, 1);
      expect(find.text('Today already counts'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('a covered day shows the check-in as done', (tester) async {
      await pumpShell(tester, host(tier: AdventureTier.pixel));
      expect(find.text('Today already counts'), findsOneWidget);
      expect(tester.widget<ActionChip>(noSpendChip()).onPressed, isNull);
    });

    testWidgets('before the savings rules a tap explains why, writing nothing', (
      tester,
    ) async {
      final habits = FakeHabits();
      await pumpShell(
        tester,
        host(
          tier: AdventureTier.pixel,
          game: GameState.initial(),
          habits: habits,
          view: sampleView(habits: false),
        ),
      );
      await tester.tap(find.text('No spend today'));
      await pumpUi(tester);
      expect(habits.checkIns, 0);
      expect(find.textContaining('adopts the savings rules'), findsOneWidget);
    });

    testWidgets('the Inbox offers the weekly reconcile', (tester) async {
      final habits = FakeHabits();
      await pumpShell(
        tester,
        host(
          tier: AdventureTier.pixel,
          game: GameState.initial(),
          habits: habits,
        ),
      );
      await tester.tap(find.text('Inbox'));
      await pumpUi(tester);
      await tester.tap(find.text('Reconcile this week'));
      await pumpUi(tester);
      expect(find.text('Reconcile this week?'), findsOneWidget);
      await tester.tap(find.text('Mark reconciled'));
      await pumpUi(tester);
      expect(habits.reconciled, [CalendarDay(2026, 10, 3)]);
      expect(find.text('Week reconciled'), findsOneWidget);
    });

    testWidgets('the Inbox reconcile is off with a plain reason before the '
        'savings rules', (tester) async {
      await pumpShell(
        tester,
        host(
          tier: AdventureTier.pixel,
          game: GameState.initial(),
          view: sampleView(habits: false),
        ),
      );
      await tester.tap(find.text('Inbox'));
      await pumpUi(tester);
      final reconcile = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Reconcile this week'),
          matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
        ),
      );
      expect(reconcile.onPressed, isNull);
      expect(find.textContaining('adopts the savings rules'), findsOneWidget);
    });
  });

  group('celebrating a log', () {
    TownSceneView scene(WidgetTester tester) =>
        tester.widget<TownSceneView>(find.byKey(const ValueKey('town-scene')));

    void logAPurchase(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(TownShell, skipOffstage: false)),
        )
            .read(testLoggedPurchasesProvider.notifier)
            .log();

    Future<InMemoryGameEventStore> pumpLive(
      WidgetTester tester, {
      AdventureTier tier = AdventureTier.pixel,
      List<GameEvent> events = const [],
    }) async {
      final store = (await tester.runAsync(() => storeWith(events)))!;
      await pumpShell(tester, host(tier: tier, liveStore: store));
      await pumpUi(tester);
      return store;
    }

    Future<void> grantDailyLog(
      WidgetTester tester,
      InMemoryGameEventStore store, {
      required String rewardId,
    }) async {
      await tester.runAsync(
        () => store.append([
          granted(
            'r-$rewardId',
            when: before(const Duration(minutes: 1)),
            rewardId: rewardId,
            gems: 5,
            reasonCode: GameReasonCodes.dailyLog,
          ),
        ]),
      );
      await pumpUi(tester);
    }

    testWidgets("new logging gems fly to the logger's house", (tester) async {
      final store = await pumpLive(tester);
      expect(scene(tester).logPulse, isNull);
      await grantDailyLog(tester, store, rewardId: 'log.daily:$robin:today');
      final pulse = scene(tester).logPulse!;
      expect(pulse.personId, robin);
      expect(pulse.gems, 5);
    });

    testWidgets('rewards already waiting when the town opens are not replayed',
        (tester) async {
      await pumpLive(
        tester,
        events: [
          granted(
            'r0',
            when: before(const Duration(hours: 1)),
            rewardId: 'log.daily:$robin:today',
            gems: 5,
            reasonCode: GameReasonCodes.dailyLog,
          ),
        ],
      );
      expect(scene(tester).logPulse, isNull);
    });

    testWidgets('a log with no gems (daily cap) still sparkles', (tester) async {
      await pumpLive(tester);
      logAPurchase(tester);
      await pumpUi(tester);
      final pulse = scene(tester).logPulse!;
      expect(pulse.personId, robin);
      expect(pulse.gems, 0);
    });

    testWidgets('a log made under a covering screen plays once the town is back', (
      tester,
    ) async {
      await pumpLive(tester);
      final navigator = Navigator.of(tester.element(find.byType(TownShell)));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('entry screen')),
          ),
        ),
      );
      await pumpUi(tester);
      TownSceneView coveredScene() => tester.widget<TownSceneView>(
        find.byKey(const ValueKey('town-scene'), skipOffstage: false),
      );
      logAPurchase(tester);
      await pumpUi(tester);
      expect(coveredScene().logPulse, isNull, reason: 'held while covered');
      navigator.pop();
      await pumpUi(tester);
      final pulse = coveredScene().logPulse!;
      expect(pulse.personId, robin);
      expect(pulse.gems, 0);
    });

    testWidgets('the text tier says a line from the logged-purchase file', (
      tester,
    ) async {
      await pumpLive(tester, tier: AdventureTier.text);
      logAPurchase(tester);
      await pumpUi(tester);
      final shown = tester
          .widget<Text>(
            find.descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Text),
            ),
          )
          .data!;
      final shipped = LoggedVoice.parse(
        File(kPurchaseLoggedAsset).readAsStringSync(),
      );
      final possible = {
        for (var seed = 0; seed < 200; seed++) shipped.line(seed: seed),
        for (final line in shipped.lines) LoggedVoice(lines: [line]).line(),
      };
      expect(possible, contains(shown));
    });
  });
}
