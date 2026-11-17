/// The long road on a phone: the strip opens each new district and Castle
/// Hill at the city; a civic plot builds once; the workshop starts a job
/// and collects one once; the Castle sheet starts a stage once and shows
/// the rising stage's meter; a resting farm explains itself; the town
/// book's new numbers are the rules' own; Log purchase is one tap in every
/// district; nothing overflows on a 360 × 780 phone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/long_road_book.dart';
import 'package:lootlog/game/scenes/town/town_scene_view.dart';
import 'package:lootlog/game/ui/hall_common.dart' show HallLinks;
import 'package:lootlog/game/ui/town/castle_sheet.dart';
import 'package:lootlog/game/ui/town/civic_plot_sheet.dart';
import 'package:lootlog/game/ui/town/town_book_screen.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../../domain/town/growth_fixtures.dart';
import '../hall_harness.dart' show before, kHallNow, robin, stateOf, storeWith;
import 'long_road_fixtures.dart';

const Size _phone = Size(390, 844);
const Size _smallPhone = Size(360, 780);

Future<void> _pump(WidgetTester tester, Widget host, {Size size = _phone}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host);
  await _frames(tester);
}

/// The Flame scene ticks forever: advance in steps instead of settling.
Future<void> _frames(WidgetTester tester) async {
  for (var step = 0; step < 6; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

TownSceneView _scene(WidgetTester tester) => tester.widget<TownSceneView>(find.byType(TownSceneView).last);

/// Opens [districtId] from the strip (scrolling it into view first).
Future<void> _openDistrict(WidgetTester tester, String districtId) async {
  final button = find.byKey(ValueKey('district-$districtId'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _frames(tester);
}

/// Taps plot [plotIndex] of the open district.
Future<void> _tapPlot(WidgetTester tester, int plotIndex) async {
  final scene = _scene(tester);
  final plot = scene.view.plots[plotIndex];
  scene.onTarget(scene.view.targetAt(plot.origin)!);
  await _frames(tester);
}

void main() {
  testWidgets('the strip opens every new district, and Castle Hill at the city', (tester) async {
    await _pump(tester, longRoadHost(await storeWith(longRoadEvents(TownTier.city))));
    for (final id in [...quartersFor(TownTier.city), kCastleHillDistrictId]) {
      await _openDistrict(tester, id);
      expect(_scene(tester).view.districtId, id);
      expect(find.byType(TownSceneView), findsOneWidget, reason: 'the old district is let go');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the strip names the open district shortly and keeps it fully in view', (tester) async {
    await _pump(tester, longRoadHost(await storeWith(longRoadEvents(TownTier.city))));
    await _openDistrict(tester, kResidentialDistrictId);
    expect(find.descendant(of: find.byKey(const ValueKey('district-residential')), matching: find.textContaining('Homes', findRichText: true)),
        findsOneWidget);
    for (final id in [kCastleHillDistrictId, kOutpostDistrictId, kMarketRowDistrictId]) {
      // Opened by a swipe or the picker: the strip scrolls to it by itself.
      final shell = tester.state(find.byType(TownShell)) as dynamic;
      shell.openDistrict(id);
      await _frames(tester);
      final viewport = tester.getRect(find.byKey(const ValueKey('district-strip-scroll')));
      final button = tester.getRect(find.byKey(ValueKey('district-$id')));
      expect(button.left, greaterThanOrEqualTo(viewport.left), reason: id);
      expect(button.right, lessThanOrEqualTo(viewport.right), reason: id);
    }
  });

  testWidgets('Castle Hill stays locked until the city, and says so in the picker', (tester) async {
    await _pump(tester, longRoadHost(await storeWith(longRoadEvents(TownTier.town))));
    expect(find.byKey(const ValueKey('district-castleHill')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('district-map')));
    await tester.tap(find.byKey(const ValueKey('district-map')));
    await _frames(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('district-card-castleHill')));
    expect(find.textContaining('a castle can rise on the hill'), findsOneWidget);
    expect(find.byKey(const ValueKey('district-visit-castleHill')), findsNothing);
  });

  testWidgets('an empty civic plot builds a watchtower, charged once', (tester) async {
    final store = await storeWith(longRoadEvents(TownTier.village));
    await _pump(tester, longRoadHost(store));
    await _openDistrict(tester, kGuardPostDistrictId);
    await _tapPlot(tester, 0);
    expect(find.byType(CivicPlotSheet), findsOneWidget);
    final build = find.byKey(const ValueKey('civic-build-watchtower'));
    await tester.ensureVisible(build);
    await tester.tap(build);
    await _frames(tester);
    final built = (await store.all()).whereType<CivicBuildingStarted>().toList();
    expect(built, hasLength(1));
    expect((built.single.districtId, built.single.plotIndex, built.single.buildingKey), (kGuardPostDistrictId, 0, 'watchtower'));
  });

  testWidgets('the workshop starts a job once, and collects a finished one once', (tester) async {
    final store = await storeWith(longRoadEvents(TownTier.town, extra: [
      civicBuilt('workshop', kMarketRowDistrictId, 1, CivicBuildingType.workshop, when: before(const Duration(days: 3))),
      civicBuilt('workshop-2', kMarketRowDistrictId, 3, CivicBuildingType.workshop, when: before(const Duration(days: 3))),
      refiningStarted('done-job', 3, 'tools',
          when: before(const Duration(hours: 3)),
          completesAt: before(const Duration(hours: 2)),
          output: GoodsBundle({GoodsKind.tools: 3})),
    ]));
    await _pump(tester, longRoadHost(store));
    await _openDistrict(tester, kMarketRowDistrictId);
    await _tapPlot(tester, 1);
    expect(find.textContaining('3 Tools ready to collect'), findsOneWidget);
    final collect = find.byKey(const ValueKey('workshop-collect'));
    await tester.ensureVisible(collect);
    await tester.tap(collect);
    await _frames(tester);
    expect((await store.all()).whereType<GoodsCollected>(), hasLength(1));
    expect((await stateOf(store)).townOf(robin).goods.stored[GoodsKind.tools], 3);
    expect(find.byKey(const ValueKey('workshop-collect')), findsNothing, reason: 'nothing left to collect');

    await tester.tap(find.byKey(const ValueKey('recipe-cutStone')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('batches-more')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const ValueKey('batches-count'))).data, '2');
    expect(find.textContaining('Takes 20 stone'), findsOneWidget);
    final start = find.byKey(const ValueKey('workshop-start'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await _frames(tester);
    final started = (await store.all()).whereType<RefiningStarted>().where((event) => event.eventId != 'done-job').toList();
    expect(started, hasLength(1));
    expect((started.single.recipeId, started.single.batches), ('cutStone', 2));
    expect(find.textContaining('Making 4 Cut stone'), findsOneWidget);
  });

  testWidgets('the Castle sheet starts the next stage once, then shows it rising', (tester) async {
    final store = await storeWith(longRoadEvents(TownTier.city, goods: true));
    await _pump(tester, longRoadHost(store));
    await _openDistrict(tester, kCastleHillDistrictId);
    final scene = _scene(tester);
    final origin = scene.view.layout.castleOrigin!;
    scene.onTarget(scene.view.targetAt(origin)!);
    await _frames(tester);
    expect(find.byType(CastleSheet), findsOneWidget);
    expect(find.textContaining('Everything is gathered'), findsOneWidget);
    final start = find.byKey(const ValueKey('castle-start'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await _frames(tester);
    expect((await store.all()).whereType<CastleStageStarted>(), hasLength(1));
    expect(find.byKey(const ValueKey('castle-start')), findsNothing);
    expect(find.byKey(const ValueKey('castle-stage-meter')), findsOneWidget);
    expect(_scene(tester).view.castleUnderConstruction, isTrue);
  });

  testWidgets('a double tap on Start starts one workshop job and one Castle stage', (tester) async {
    final store = await storeWith(longRoadEvents(TownTier.city, goods: true, extra: [
      civicBuilt('workshop', kMarketRowDistrictId, 1, CivicBuildingType.workshop, when: before(const Duration(days: 3))),
      civicBuilt('workshop-2', kMarketRowDistrictId, 3, CivicBuildingType.workshop, when: before(const Duration(days: 3))),
    ]));
    await _pump(tester, longRoadHost(store));
    await _openDistrict(tester, kMarketRowDistrictId);
    await _tapPlot(tester, 1);
    final start = find.byKey(const ValueKey('workshop-start'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.tap(start, warnIfMissed: false);
    await _frames(tester);
    final jobs = (await store.all()).whereType<RefiningStarted>().where((event) => event.eventId != 'crates');
    expect(jobs, hasLength(1), reason: 'two idle workshops, one tap that counts');
    await tester.tap(find.text('Close').last);
    await _frames(tester);

    await _openDistrict(tester, kCastleHillDistrictId);
    final scene = _scene(tester);
    scene.onTarget(scene.view.targetAt(scene.view.layout.castleOrigin!)!);
    await _frames(tester);
    final castle = find.byKey(const ValueKey('castle-start'));
    await tester.ensureVisible(castle);
    await tester.tap(castle);
    await tester.tap(castle, warnIfMissed: false);
    await _frames(tester);
    expect((await store.all()).whereType<CastleStageStarted>(), hasLength(1));
  });

  testWidgets('the Castle sheet says what is still to gather', (tester) async {
    await _pump(tester, longRoadHost(await storeWith(longRoadEvents(TownTier.city))));
    await _openDistrict(tester, kCastleHillDistrictId);
    final scene = _scene(tester);
    scene.onTarget(scene.view.targetAt(scene.view.layout.castleOrigin!)!);
    await _frames(tester);
    expect(tester.widget<Text>(find.byKey(const ValueKey('castle-missing'))).data, startsWith('Still to gather:'));
  });

  testWidgets('a resting farm explains itself and what to build', (tester) async {
    await _pump(tester, longRoadHost(await storeWith(longRoadEvents(TownTier.town, extra: [
      farmBuilt('edge', 6, FarmBuildingType.farm, when: before(const Duration(days: 2))),
    ]))));
    await _openDistrict(tester, kFarmlandDistrictId);
    expect(_scene(tester).view.plots[6].resting, isTrue);
    await _tapPlot(tester, 6);
    expect(find.byKey(const ValueKey('farm-resting')), findsOneWidget);
    expect(find.textContaining('watchtower, barracks or wall section'), findsOneWidget);
  });

  testWidgets('the town book\'s homes, guards, goods and Castle are the rules\' own numbers', (tester) async {
    final store = await storeWith(longRoadEvents(TownTier.city, goods: true, extra: [
      civicBuilt('cottage', kResidentialDistrictId, 0, CivicBuildingType.cottage, when: before(const Duration(days: 3))),
      civicBuilt('tower', kGuardPostDistrictId, 0, CivicBuildingType.watchtower, when: before(const Duration(days: 3))),
    ]));
    await _pump(tester, longRoadHost(store));
    await tester.tap(find.byKey(const ValueKey('town-hud-date')));
    await _frames(tester);
    expect(find.byType(TownBookScreen), findsOneWidget);
    final book = longRoadBook(await stateOf(store), robin, kHallNow);
    String textOf(String key) {
      final finder = find.byKey(ValueKey(key));
      return tester.widget<Text>(finder).data!;
    }

    await tester.ensureVisible(find.byKey(const ValueKey('book-housing')));
    expect(textOf('book-housing'), '${book.housing}');
    expect(book.housing, greaterThan(0));
    await tester.ensureVisible(find.byKey(const ValueKey('book-guards')));
    expect(textOf('book-guards'), '${book.guards}');
    expect(textOf('book-fields'), '${book.fieldsOpen}');
    await tester.ensureVisible(find.byKey(const ValueKey('book-goods')));
    expect(textOf('book-goods'), contains('2000 Planks'));
    await tester.ensureVisible(find.byKey(const ValueKey('book-castle-stages')));
    expect(textOf('book-castle-stages'), '${book.castleStagesDone} of 5 stages built.');
  });

  testWidgets('Log purchase is one tap in every district', (tester) async {
    var logs = 0;
    final links = HallLinks(logPurchase: (_) => logs++);
    await _pump(tester, longRoadHost(await storeWith(longRoadEvents(TownTier.city)), links: links));
    for (final id in [...quartersFor(TownTier.city), kCastleHillDistrictId]) {
      await _openDistrict(tester, id);
      final before = logs;
      await tester.tap(find.textContaining('Log purchase'));
      expect(logs, before + 1, reason: id);
      await tester.pump();
    }
  });

  testWidgets('nothing overflows on a 360 x 780 phone', (tester) async {
    final store = await storeWith(longRoadEvents(TownTier.city, goods: true, extra: [
      civicBuilt('workshop', kMarketRowDistrictId, 1, CivicBuildingType.workshop, when: before(const Duration(days: 3))),
    ]));
    await _pump(tester, longRoadHost(store), size: _smallPhone);
    for (final id in [...quartersFor(TownTier.city), kCastleHillDistrictId]) {
      await _openDistrict(tester, id);
      expect(tester.takeException(), isNull, reason: id);
    }
    // The Castle sheet, then the workshop and an empty plot's sheet.
    final hill = _scene(tester);
    hill.onTarget(hill.view.targetAt(hill.view.layout.castleOrigin!)!);
    await _frames(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Close').last);
    await _frames(tester);
    await _openDistrict(tester, kMarketRowDistrictId);
    await _tapPlot(tester, 1);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Close').last);
    await _frames(tester);
    await _tapPlot(tester, 0);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Close').last);
    await _frames(tester);
    await tester.tap(find.byKey(const ValueKey('town-hud-date')));
    await _frames(tester);
    expect(find.byType(TownBookScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
