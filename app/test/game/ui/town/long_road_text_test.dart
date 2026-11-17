/// The long road in the text tier: each civic quarter's plots, the
/// workshop and the Castle as plain buttons that open the same sheets, a
/// civic building built from there, and the Castle's promise before the
/// city.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/town/castle_sheet.dart';
import 'package:lootlog/game/ui/town/civic_plot_sheet.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';
import 'package:lootlog/game/ui/town/workshop_panel.dart';

import '../../domain/town/growth_fixtures.dart';
import '../hall_harness.dart' show before, storeWith;
import 'long_road_fixtures.dart';
import 'town_test_overrides.dart';

Widget _host(InMemoryGameEventStore store) => ProviderScope(
      overrides: townTestOverrides(tier: AdventureTier.text, liveStore: store),
      child: MaterialApp(home: TownShell(onOpenLedger: () {}, ambientLife: false)),
    );

Future<void> _pump(WidgetTester tester, InMemoryGameEventStore store) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(store));
  await _steps(tester);
}

Future<void> _steps(WidgetTester tester) async {
  for (var step = 0; step < 6; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(finder);
  await _steps(tester);
}

void main() {
  testWidgets('a civic plot opens its sheet and builds from the text home', (tester) async {
    final store = await storeWith(longRoadEvents(TownTier.village));
    await _pump(tester, store);
    await _tapVisible(tester, find.byKey(const ValueKey('text-civic-residential-0')));
    expect(find.byType(CivicPlotSheet), findsOneWidget);
    final build = find.text('Build Cottage');
    await tester.ensureVisible(build);
    await tester.tap(build);
    await _steps(tester);
    expect((await store.all()).whereType<CivicBuildingStarted>(), hasLength(1));
  });

  testWidgets('the workshop and the Castle open from the text home', (tester) async {
    final store = await storeWith(longRoadEvents(TownTier.city, extra: [
      civicBuilt('workshop', kMarketRowDistrictId, 0, CivicBuildingType.workshop, when: before(const Duration(days: 2))),
    ]));
    await _pump(tester, store);
    await _tapVisible(tester, find.byKey(const ValueKey('text-workshop')));
    expect(find.byType(WorkshopPanel), findsOneWidget);
    expect(find.byKey(const ValueKey('workshop-start')), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await _steps(tester);
    await _tapVisible(tester, find.byKey(const ValueKey('text-castle')));
    expect(find.byType(CastleSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('castle-stage-1')), findsOneWidget);
  });

  testWidgets('before the city the Castle is a promise', (tester) async {
    await _pump(tester, await storeWith(longRoadEvents(TownTier.town)));
    await tester.scrollUntilVisible(find.textContaining('a castle can rise on the hill').last, 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('text-castle')), findsNothing);
  });
}
