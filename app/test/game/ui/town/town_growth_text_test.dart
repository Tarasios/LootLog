/// The text tier's growth section: the town book, every district and the
/// farmland's fields, as plain sections and buttons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/town/town_book_screen.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../../domain/town/growth_fixtures.dart';
import '../hall_harness.dart' show before, claimed, granted, sampleEvents, storeWith;
import 'town_test_overrides.dart';

List<GameEvent> _hamlet({bool owned = false}) => [
  ...sampleEvents(),
  tierReached('t-hamlet', TownTier.hamlet, when: before(const Duration(days: 30))),
  granted('stores-a', when: before(const Duration(hours: 4)), rewardId: 'stores',
      materials: MaterialBundle({MaterialKind.lumber: 200, MaterialKind.stone: 200})),
  claimed('stores-b', 'stores', when: before(const Duration(hours: 4))),
  if (owned) districtPurchased('d-farmland', kFarmlandDistrictId, when: before(const Duration(hours: 3))),
];

Widget _host(InMemoryGameEventStore store) => ProviderScope(
  overrides: townTestOverrides(tier: AdventureTier.text, liveStore: store),
  child: MaterialApp(home: TownShell(onOpenLedger: () {}, ambientLife: false)),
);

Future<void> _pump(WidgetTester tester, Widget host) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host);
  for (var step = 0; step < 4; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _steps(WidgetTester tester) async {
  for (var step = 0; step < 6; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('a district for sale can be bought from the text home', (tester) async {
    await _pump(tester, _host(await storeWith(_hamlet())));
    final buy = find.byKey(const ValueKey('text-district-buy-farmland'));
    await tester.scrollUntilVisible(buy, 200);
    await tester.tap(buy);
    await _steps(tester);
    expect(find.byKey(const ValueKey('district-buy-farmland')), findsOneWidget);
  });

  testWidgets('the farmland\'s fields open their sheets, and the book opens', (tester) async {
    await _pump(tester, _host(await storeWith(_hamlet(owned: true))));
    final field = find.byKey(const ValueKey('text-field-0'));
    await tester.scrollUntilVisible(field, 200);
    await tester.tap(field);
    await _steps(tester);
    expect(find.text('Build Farm'), findsOneWidget);
    Navigator.of(tester.element(find.text('Build Farm'))).pop();
    await _steps(tester);
    final openBook = find.textContaining('Open the town book');
    await tester.scrollUntilVisible(openBook, -200);
    await tester.tap(openBook);
    await _steps(tester);
    expect(find.byType(TownBookScreen), findsOneWidget);
    expect(find.text('Residents'), findsOneWidget);
  });
}
