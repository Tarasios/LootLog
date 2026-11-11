/// The town's districts on a phone: the strip switches the scene between
/// districts, a locked district shows what opens it, the picker buys one
/// (charged once), the town book shows the rules' own numbers, Log purchase
/// is tappable on the first frame in every district, and nothing overflows
/// on a small phone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/town_book.dart';
import 'package:lootlog/game/scenes/town/town_scene_view.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/game_home.dart';
import 'package:lootlog/game/ui/town/town_book_screen.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../../domain/town/growth_fixtures.dart';
import '../hall_harness.dart' show before, claimed, granted, kHallNow, robin, sampleEvents, stateOf, storeWith;
import 'town_test_overrides.dart';

const Size _phone = Size(390, 844);
const Size _smallPhone = Size(360, 780);

/// Robin's sample town grown into a hamlet with stores enough for the
/// farmland, and (when [owned]) the farmland already bought.
List<GameEvent> _hamletEvents({bool owned = false}) => [
  ...sampleEvents(),
  tierReached('t-hamlet', TownTier.hamlet, when: before(const Duration(days: 1))),
  granted(
    'stores-a',
    when: before(const Duration(hours: 4)),
    rewardId: 'stores',
    materials: MaterialBundle({MaterialKind.lumber: 200, MaterialKind.stone: 200}),
  ),
  claimed('stores-b', 'stores', when: before(const Duration(hours: 4))),
  if (owned) districtPurchased('d-farmland', kFarmlandDistrictId, when: before(const Duration(hours: 3))),
];

Widget _host(InMemoryGameEventStore store, {HallLinks links = const HallLinks()}) => ProviderScope(
  overrides: townTestOverrides(tier: AdventureTier.pixel, liveStore: store),
  child: MaterialApp(
    home: TownShell(onOpenLedger: () {}, links: links, ambientLife: false),
  ),
);

Future<void> _pumpShell(WidgetTester tester, Widget shell, {Size size = _phone}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(shell);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// The Flame scene ticks forever: advance in steps instead of settling.
Future<void> _pumpUi(WidgetTester tester) async {
  for (var step = 0; step < 6; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _sceneDistrict(WidgetTester tester) =>
    tester.widget<TownSceneView>(find.byType(TownSceneView).last).view.districtId;

void main() {
  testWidgets('the strip switches the scene to an owned district and back', (tester) async {
    await _pumpShell(tester, _host(await storeWith(_hamletEvents(owned: true))));
    expect(find.byKey(const ValueKey('district-strip')), findsOneWidget);
    expect(_sceneDistrict(tester), kOutpostDistrictId);
    await tester.tap(find.byKey(const ValueKey('district-farmland')));
    await _pumpUi(tester);
    expect(_sceneDistrict(tester), kFarmlandDistrictId);
    expect(find.byType(TownSceneView), findsOneWidget, reason: 'the old district is let go');
    await tester.tap(find.byKey(const ValueKey('district-outpost')));
    await _pumpUi(tester);
    expect(_sceneDistrict(tester), kOutpostDistrictId);
  });

  testWidgets('a locked district cannot be opened and shows what opens it', (tester) async {
    await _pumpShell(tester, _host(await storeWith(sampleEvents())));
    await tester.tap(find.byKey(const ValueKey('district-farmland')));
    await _pumpUi(tester);
    expect(_sceneDistrict(tester), kOutpostDistrictId);
    expect(find.textContaining('Hamlet'), findsWidgets);
    expect(find.byKey(const ValueKey('district-buy-farmland')), findsNothing);
  });

  testWidgets('buying the farmland charges once and opens it', (tester) async {
    final store = await storeWith(_hamletEvents());
    await _pumpShell(tester, _host(store));
    final start = await stateOf(store);
    await tester.tap(find.byKey(const ValueKey('district-map')));
    await _pumpUi(tester);
    final buy = find.byKey(const ValueKey('district-buy-farmland'));
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await _pumpUi(tester);
    final after = await stateOf(store);
    final price = districtById(kFarmlandDistrictId)!.price;
    expect(after.townOf(robin).districts.owns(kFarmlandDistrictId), isTrue);
    expect(after.person(robin).gems, start.person(robin).gems - price.gems);
    expect(
      after.townOf(robin).materials[MaterialKind.lumber],
      start.townOf(robin).materials[MaterialKind.lumber] - price.materials[MaterialKind.lumber],
    );
    expect((await store.all()).whereType<DistrictPurchased>(), hasLength(1));
    // Close the celebration: the farmland is open and nothing is for sale twice.
    await tester.tap(find.text('Huzzah!'));
    await _pumpUi(tester);
    expect(_sceneDistrict(tester), kFarmlandDistrictId);
    await tester.tap(find.byKey(const ValueKey('district-map')));
    await _pumpUi(tester);
    expect(find.byKey(const ValueKey('district-buy-farmland')), findsNothing);
  });

  testWidgets('the town book shows the rules\' own numbers', (tester) async {
    final store = await storeWith(_hamletEvents(owned: true));
    await _pumpShell(tester, _host(store));
    await tester.tap(find.byKey(const ValueKey('town-hud-date')));
    await _pumpUi(tester);
    expect(find.byType(TownBookScreen), findsOneWidget);
    final book = townBook(await stateOf(store), robin, kHallNow);
    String textOf(String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;
    expect(textOf('book-prosperity'), '${book.prosperity}');
    expect(textOf('book-next-prosperity'), '${book.nextTierProsperity}');
    expect(textOf('book-population'), '${book.population}');
    expect(textOf('book-food-need'), '${book.dailyFoodNeed}');
    expect(textOf('book-food-stored'), '${book.foodStored}');
  });

  testWidgets('the town book opens from the Menu too', (tester) async {
    await _pumpShell(tester, _host(await storeWith(sampleEvents())));
    await tester.tap(find.byKey(const ValueKey('town-menu')));
    await _pumpUi(tester);
    await tester.tap(find.textContaining('Town book'));
    await _pumpUi(tester);
    expect(find.byType(TownBookScreen), findsOneWidget);
  });

  testWidgets('Log purchase is tappable on the first frame in every district', (tester) async {
    var logs = 0;
    final links = HallLinks(logPurchase: (_) => logs++);
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(await storeWith(_hamletEvents(owned: true)), links: links));
    await tester.tap(find.textContaining('Log purchase'));
    expect(logs, 1);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('district-farmland')));
    await tester.pump();
    await tester.tap(find.textContaining('Log purchase'));
    expect(logs, 2);
    await _pumpUi(tester);
  });

  testWidgets('nothing overflows on a 360 x 780 phone', (tester) async {
    await _pumpShell(tester, _host(await storeWith(_hamletEvents(owned: true))), size: _smallPhone);
    await tester.tap(find.byKey(const ValueKey('district-farmland')));
    await _pumpUi(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('district-map')));
    await _pumpUi(tester);
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(5, 5));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('town-hud-date')));
    await _pumpUi(tester);
    expect(find.byType(TownBookScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a farmland field opens its sheet with what can be planted', (tester) async {
    await _pumpShell(tester, _host(await storeWith(_hamletEvents(owned: true))));
    await tester.tap(find.byKey(const ValueKey('district-farmland')));
    await _pumpUi(tester);
    final scene = tester.widget<TownSceneView>(find.byType(TownSceneView));
    scene.onTarget(scene.view.targetAt(scene.view.plots.first.origin)!);
    await _pumpUi(tester);
    expect(find.text('Build Farm'), findsOneWidget);
    expect(find.text('Build Orchard'), findsOneWidget);
    expect(find.text('Build Granary'), findsOneWidget);
  });
}
