/// The town loop on a phone: the "while you were away" summary, the day's
/// visitor, the town spirit bar and the weekend festival — plus the same
/// features in the text tier and the shift note on a producer's sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/festival.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/building_sheet.dart';
import 'package:lootlog/game/ui/hall_common.dart';
import 'package:lootlog/game/ui/kit/kit.dart' show WoodButton;
import 'package:lootlog/game/ui/town/town_loop_providers.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';
import 'package:lootlog/game/ui/town/town_spirit_bar.dart';

import '../hall_harness.dart';
import 'town_loop_fixtures.dart';
import 'town_test_overrides.dart';

const Size kPhone = Size(390, 844);

Widget townHost({
  GameState? game,
  InMemoryGameEventStore? liveStore,
  AdventureTier tier = AdventureTier.pixel,
  bool popups = true,
}) => ProviderScope(
  overrides: townTestOverrides(tier: tier, game: game, liveStore: liveStore, loopPopups: popups),
  child: MaterialApp(home: TownShell(onOpenLedger: () {}, ambientLife: false)),
);

Future<void> pumpTown(WidgetTester tester, Widget host, {Size size = kPhone}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host);
  await pumpSteps(tester);
}

/// The Flame scene never settles: step the clock instead.
Future<void> pumpSteps(WidgetTester tester, [int steps = 8]) async {
  for (var step = 0; step < steps; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A button by its label: a wood button (pixel tier) or a plain text label
/// (the text tier's Material buttons).
Finder label(String text) => find.byWidgetPredicate(
  (widget) => (widget is WoodButton && widget.label == text) || (widget is Text && widget.data == text),
);

Future<List<T>> eventsOfType<T extends GameEvent>(InMemoryGameEventStore store) async =>
    (await store.all()).whereType<T>().toList();

void main() {
  group('while you were away', () {
    testWidgets('lists each producer and Collect all banks each one once', (tester) async {
      final store = await storeWith([
        ...sampleEvents(),
        built('x0001', 2, BuildingType.quarry, when: before(const Duration(hours: 4))),
      ]);
      await pumpTown(tester, townHost(liveStore: store));

      expect(find.text('While you were away'), findsOneWidget);
      expect(find.text('Lumberyard'), findsWidgets);
      expect(find.text('Quarry'), findsWidgets);
      // Robin logged today, so every day in the stretch was a full one.
      expect(find.text('Full days: the ledger was kept.'), findsOneWidget);

      await tester.tap(label('Collect all'));
      await pumpSteps(tester);
      final collected = await eventsOfType<MaterialsCollected>(store);
      expect(collected.map((event) => event.buildingId).toSet(), {'plot-0', 'plot-2'});
      expect(collected, hasLength(2));
      expect(find.text('While you were away'), findsNothing);
    });

    testWidgets('does not open again the same day', (tester) async {
      final store = await storeWith(sampleEvents());
      await pumpTown(tester, townHost(liveStore: store));
      expect(find.text('While you were away'), findsOneWidget);
      await tester.tap(label('Later'));
      await pumpSteps(tester);
      expect(find.text('While you were away'), findsNothing);

      // A new game state (a new event) rebuilds the town: still closed.
      await store.append([granted('x0009', when: kHallNow, rewardId: 'later-gift', gems: 1)]);
      await pumpSteps(tester);
      expect(find.text('While you were away'), findsNothing);
      final container = ProviderScope.containerOf(tester.element(find.byType(TownShell)));
      expect(container.read(townLoopShownProvider).awayDay, kToday);
    });

    testWidgets('a quiet stretch says how the crews worked, kindly', (tester) async {
      await pumpTown(tester, townHost(game: projectGameState(quietEvents())));
      final note = find.textContaining('Short shifts on 2 quiet days');
      expect(note, findsOneWidget);
      expect(find.textContaining('Log today and the crews work the full day'), findsOneWidget);
      final words = RegExp(r'\b(lost|missed|penalty)\b', caseSensitive: false);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(words.hasMatch(text.data ?? ''), isFalse, reason: text.data);
      }
    });
  });

  group('the day\'s visitor', () {
    testWidgets('a tag stands in town only while an offer is open', (tester) async {
      await pumpTown(tester, townHost(game: projectGameState(sampleEvents()), popups: false));
      expect(find.text('Trader in town'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await pumpTown(
        tester,
        townHost(game: projectGameState([...sampleEvents(), offered('x0001')]), popups: false),
      );
      expect(find.text('Trader in town'), findsOneWidget);
    });

    testWidgets('before the day is opened the Log button says so', (tester) async {
      await pumpTown(tester, townHost(game: projectGameState(quietEvents()), popups: false));
      expect(find.text('Log today to open the town'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpTown(tester, townHost(game: projectGameState(sampleEvents()), popups: false));
      expect(find.text('Log today to open the town'), findsNothing);
    });

    testWidgets('Trade swaps the goods once and the trader leaves', (tester) async {
      final store = await storeWith([...sampleEvents(), offered('x0001')]);
      await pumpTown(tester, townHost(liveStore: store, popups: false));
      final lumberBefore = (await stateOf(store)).hall.materials[MaterialKind.lumber];

      await tester.tap(find.text('Trader in town'));
      await pumpSteps(tester);
      expect(label('Trade'), findsOneWidget);
      expect(label('Not today'), findsOneWidget);
      await tester.tap(label('Trade'));
      await pumpSteps(tester);

      final resolved = await eventsOfType<DailyEventResolved>(store);
      expect(resolved, hasLength(1));
      expect(resolved.single.accepted, isTrue);
      final after = await stateOf(store);
      expect(after.hall.materials[MaterialKind.lumber], lumberBefore - 10);
      expect(after.hall.materials[MaterialKind.stone], 106);
      expect(find.text('Trader in town'), findsNothing);
    });

    testWidgets('Not today waves the visitor off and it leaves', (tester) async {
      final store = await storeWith([...sampleEvents(), offered('x0001')]);
      await pumpTown(tester, townHost(liveStore: store, popups: false));
      await tester.tap(find.text('Trader in town'));
      await pumpSteps(tester);
      await tester.tap(label('Not today'));
      await pumpSteps(tester);
      final resolved = await eventsOfType<DailyEventResolved>(store);
      expect(resolved.single.accepted, isFalse);
      expect(find.text('Trader in town'), findsNothing);
    });

    testWidgets('a visitor with a gift is collected', (tester) async {
      final store = await storeWith([...sampleEvents(), offered('x0001', kind: DailyEventKind.visitor)]);
      await pumpTown(tester, townHost(liveStore: store, popups: false));
      await tester.tap(find.text('A visitor'));
      await pumpSteps(tester);
      await tester.tap(label('Collect'));
      await pumpSteps(tester);
      expect(await eventsOfType<DailyEventResolved>(store), hasLength(1));
      expect(find.text('A visitor'), findsNothing);
    });
  });

  testWidgets('the spirit pips match the weekdays logged', (tester) async {
    await pumpTown(tester, townHost(game: projectGameState(sampleEvents()), popups: false));
    final bar = tester.widget<TownSpiritBar>(find.byType(TownSpiritBar));
    // Robin logged Thursday and Friday (and today, Saturday).
    expect(bar.days, [false, false, false, true, true]);
    expect(bar.weekend, isTrue);

    await tester.tap(find.byType(TownSpiritBar));
    await pumpSteps(tester);
    expect(find.text('Town spirit'), findsOneWidget);
    expect(find.text('2 of 5 weekdays logged this week.'), findsOneWidget);
  });

  group('the weekend festival', () {
    testWidgets('celebrates once per weekend and claims its gifts', (tester) async {
      final store = await storeWith([...quietEvents(), ...festivalEvents()]);
      await pumpTown(tester, townHost(liveStore: store));
      // The away summary comes first; the festival follows it.
      if (find.text('While you were away').evaluate().isNotEmpty) {
        await tester.tap(label('Later'));
        await pumpSteps(tester);
      }
      expect(find.text('Fair'), findsOneWidget);
      expect(find.textContaining('A fair fills the square'), findsOneWidget);
      expect(find.textContaining('6 gems'), findsOneWidget);
      await tester.tap(label('Claim'));
      await pumpSteps(tester);
      expect(await eventsOfType<RewardClaimed>(store), hasLength(2));
      expect(find.textContaining('A fair fills the square'), findsNothing);

      await store.append([granted('x0009', when: kHallNow, rewardId: 'later-gift', gems: 1)]);
      await pumpSteps(tester);
      expect(find.textContaining('A fair fills the square'), findsNothing);
    });

    testWidgets('a market day is still a cheerful celebration', (tester) async {
      await pumpTown(
        tester,
        townHost(game: projectGameState([...sampleEvents(), ...festivalEvents(tier: FestivalTier.marketDay)])),
      );
      if (find.text('While you were away').evaluate().isNotEmpty) {
        await tester.tap(label('Later'));
        await pumpSteps(tester);
      }
      expect(find.text('Market day'), findsOneWidget);
      expect(find.textContaining("It's market day!"), findsOneWidget);
    });
  });

  testWidgets('nothing overflows on a 360 px phone', (tester) async {
    await pumpTown(
      tester,
      townHost(
        game: projectGameState([...sampleEvents(), offered('x0001'), ...festivalEvents()]),
        popups: false,
      ),
      size: const Size(360, 780),
    );
    expect(tester.takeException(), isNull);
    final spirit = tester.getRect(find.byType(TownSpiritBar));
    final treasure = tester.getRect(find.byKey(const ValueKey('town-hud-treasure')));
    expect(spirit.right, lessThanOrEqualTo(treasure.left));
    expect(spirit.left, greaterThanOrEqualTo(0));
  });

  group('text tier', () {
    testWidgets('exposes the away summary, visitor, spirit and festival', (tester) async {
      final store = await storeWith([...sampleEvents(), offered('x0001'), ...festivalEvents()]);
      await pumpHall(tester, store: store, view: sampleView());
      expect(find.text('While you were away'), findsOneWidget);
      expect(label('Collect all'), findsOneWidget);
      expect(label('Trade'), findsOneWidget);
      expect(label('Not today'), findsOneWidget);
      expect(find.text('Town spirit'), findsOneWidget);
      expect(find.textContaining('2 of 5 weekdays logged this week.'), findsOneWidget);
      expect(find.textContaining('A fair fills the square'), findsOneWidget);

      await tester.tap(label('Trade'));
      await settle(tester);
      expect(await eventsOfType<DailyEventResolved>(store), hasLength(1));
    });

    testWidgets("a producer's sheet carries the shift note", (tester) async {
      final store = await storeWith(sampleEvents());
      await pumpHall(
        tester,
        store: store,
        home: HallScope(child: Scaffold(body: BuildingSheet(plotIndex: 0, onOpenLedger: () {}))),
      );
      expect(find.text('Full days: the ledger was kept.'), findsOneWidget);
    });
  });
}
