/// The town loop on a phone: the "while you were away" summary, the day's
/// visitor, the town spirit bar and the weekend festival — plus the same
/// features in the text tier and the shift note on a producer's sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/festival.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/building_sheet.dart';
import 'package:lootlog/game/ui/hall_common.dart';
import 'package:lootlog/game/ui/hall_names.dart';
import 'package:lootlog/game/ui/kit/kit.dart' show WoodButton;
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
  HallLinks links = const HallLinks(),
  Clock? clock,
}) => ProviderScope(
  overrides: townTestOverrides(tier: tier, game: game, liveStore: liveStore, loopPopups: popups, clock: clock),
  child: MaterialApp(home: TownShell(onOpenLedger: () {}, links: links, ambientLife: false)),
);

/// A clock the test moves forward by hand.
class _SteppingClock implements Clock {
  _SteppingClock(this.current);
  DateTime current;

  @override
  DateTime now() => current;
}

/// Opens the summary from the HUD's "crews made" chip.
Future<void> openAwaySummary(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('town-away-chip')));
  await pumpSteps(tester);
}

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
    testWidgets('at 360x780 the crews chip, the check-in and the strip never overflow', (tester) async {
      final store = await storeWith([
        ...sampleEvents(),
        built('x0001', 2, BuildingType.quarry, when: before(const Duration(hours: 4))),
      ]);
      await pumpTown(tester, townHost(liveStore: store), size: const Size(360, 780));
      expect(tester.takeException(), isNull);
      final crews = tester.getRect(find.byKey(const ValueKey('town-away-chip')));
      final checkIn = tester.getRect(find.byKey(const ValueKey('town-no-spend')));
      final log = tester.getRect(find.textContaining('Log purchase'));
      for (final rect in [crews, checkIn, log]) {
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
        expect(rect.bottom, lessThanOrEqualTo(780));
      }
      expect(log.top, greaterThan(checkIn.bottom));
    });

    testWidgets('waits behind a chip; Collect all banks each producer once', (tester) async {
      final store = await storeWith([
        ...sampleEvents(),
        built('x0001', 2, BuildingType.quarry, when: before(const Duration(hours: 4))),
      ]);
      await pumpTown(tester, townHost(liveStore: store));
      // Nothing opens by itself.
      expect(find.text('While you were away'), findsNothing);
      expect(find.textContaining('Crews made'), findsOneWidget);

      await openAwaySummary(tester);
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
      // Everything banked: the chip goes.
      expect(find.byKey(const ValueKey('town-away-chip')), findsNothing);
    });

    testWidgets('Log purchase is one tap on the first frame, whatever the crews made', (tester) async {
      var entries = 0;
      final store = await storeWith(sampleEvents());
      tester.view.physicalSize = kPhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        townHost(liveStore: store, links: HallLinks(logPurchase: (_) => entries++)),
      );
      await tester.pump();
      await tester.tap(find.textContaining('Log purchase'));
      expect(entries, 1);
      await pumpSteps(tester);
      expect(find.text('While you were away'), findsNothing);
    });

    testWidgets('a quiet stretch says how the crews worked, kindly', (tester) async {
      await pumpTown(tester, townHost(game: projectGameState(quietEvents())));
      await openAwaySummary(tester);
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
      final lumberBefore = (await stateOf(store)).townOf(robin).materials[MaterialKind.lumber];

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
      expect(after.townOf(robin).materials[MaterialKind.lumber], lumberBefore - 10);
      expect(after.townOf(robin).materials[MaterialKind.stone], 106);
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
    testWidgets('celebrates once on entering and claims its gifts', (tester) async {
      final store = await storeWith([...quietEvents(), ...festivalEvents()]);
      await pumpTown(tester, townHost(liveStore: store));
      expect(find.text('Fair'), findsOneWidget);
      expect(find.textContaining('A fair fills the square'), findsOneWidget);
      // The market day plus what the fair adds.
      expect(find.textContaining(HallNames.loot(Balance.festivalRewards[FestivalTier.fair]!)), findsOneWidget);
      await tester.tap(label('Claim'));
      await pumpSteps(tester);
      // The seed's claim, then one per tier reached.
      expect(await eventsOfType<RewardClaimed>(store), hasLength(3));
      expect(find.textContaining('A fair fills the square'), findsNothing);

      await store.append([granted('x0009', when: kHallNow, rewardId: 'later-gift', gems: 1)]);
      await pumpSteps(tester);
      expect(find.textContaining('A fair fills the square'), findsNothing);
    });

    testWidgets('a grand festival shows and claims every tier and the joint bonus', (tester) async {
      final store = await storeWith([
        ...quietEvents(),
        ...festivalEvents(tier: FestivalTier.grandFestival, joint: true),
      ]);
      await pumpTown(tester, townHost(liveStore: store));
      final grand = Balance.festivalRewards[FestivalTier.grandFestival]!;
      final total = Loot(gems: grand.gems + Balance.jointFestivalGems, materials: grand.materials);
      expect(find.text('Grand festival'), findsOneWidget);
      expect(find.textContaining(HallNames.loot(total)), findsOneWidget);
      await tester.tap(label('Claim'));
      await pumpSteps(tester);
      final claimed = {for (final claim in await eventsOfType<RewardClaimed>(store)) claim.rewardId};
      expect(claimed, containsAll([...festivalRewardIds(robin, kWeek), jointFestivalRewardId(robin, kWeek)]));
      final me = (await stateOf(store)).person(robin);
      expect(me.unclaimedRewards.keys.where((id) => id.startsWith('festival')), isEmpty);
    });

    testWidgets('a market day is still a cheerful celebration', (tester) async {
      await pumpTown(
        tester,
        townHost(game: projectGameState([...sampleEvents(), ...festivalEvents(tier: FestivalTier.marketDay)])),
      );
      expect(find.text('Market day'), findsOneWidget);
      expect(find.textContaining("It's market day!"), findsOneWidget);
    });

    testWidgets('a festival arriving mid-session opens nothing on a tick', (tester) async {
      final clock = _SteppingClock(kHallNow);
      final store = await storeWith(sampleEvents());
      await pumpTown(tester, townHost(liveStore: store, clock: clock));
      await store.append(festivalEvents());
      clock.current = kHallNow.add(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 31));
      await pumpSteps(tester);
      expect(find.textContaining('A fair fills the square'), findsNothing);
      expect(find.text('While you were away'), findsNothing);
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
