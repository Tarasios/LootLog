/// The tier-up celebration: once on entering the town after a recent
/// TierReached, never for a tier reached long ago, never mid-session, and
/// the device remembers what it has shown.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/town/town_loop_providers.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../../domain/town/growth_fixtures.dart';
import '../hall_harness.dart' show before, kHallNow, robin, sampleEvents, storeWith;
import 'town_test_overrides.dart';

const _hamletLine = 'Smoke from new chimneys';

Widget _host(InMemoryGameEventStore store) => ProviderScope(
  overrides: townTestOverrides(tier: AdventureTier.pixel, liveStore: store, loopPopups: true),
  child: MaterialApp(home: TownShell(onOpenLedger: () {}, ambientLife: false)),
);

Future<void> _pumpTown(WidgetTester tester, Widget host) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host);
  for (var step = 0; step < 8; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('a town that just grew into a hamlet is celebrated on entering', (tester) async {
    final store = await storeWith([
      ...sampleEvents(),
      tierReached('t-hamlet', TownTier.hamlet, when: before(const Duration(hours: 2))),
    ]);
    await _pumpTown(tester, _host(store));
    expect(find.textContaining(_hamletLine), findsOneWidget);
    expect(find.textContaining('wait in your inbox'), findsOneWidget);
    await tester.tap(find.text('Hooray!'));
    for (var step = 0; step < 4; step++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining(_hamletLine), findsNothing);
  });

  testWidgets('a tier reached long ago is history, not a pop-up', (tester) async {
    final store = await storeWith([
      ...sampleEvents(),
      tierReached('t-hamlet', TownTier.hamlet, when: before(const Duration(days: 40))),
    ]);
    await _pumpTown(tester, _host(store));
    expect(find.textContaining(_hamletLine), findsNothing);
  });

  testWidgets('a tier reached mid-session opens nothing until the next entry', (tester) async {
    final store = await storeWith(sampleEvents());
    await _pumpTown(tester, _host(store));
    await store.append([tierReached('t-hamlet', TownTier.hamlet, when: kHallNow)]);
    for (var step = 0; step < 8; step++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining(_hamletLine), findsNothing);
  });

  group('the memory', () {
    final person = projectGameState([
      tierReached('t-hamlet', TownTier.hamlet, when: before(const Duration(hours: 2))),
    ]).person(robin);

    test('a tier is due once, then remembered across restarts', () {
      const fresh = TownLoopShown(loaded: true);
      expect(fresh.tierDue(person, kHallNow), TownTier.hamlet);
      const shown = TownLoopShown(loaded: true, tierShown: TownTier.hamlet);
      expect(shown.tierDue(person, kHallNow), isNull);
      final restored = TownLoopShown.decode(shown.encode());
      expect(restored.tierShown, TownTier.hamlet);
      expect(restored.tierDue(person, kHallNow), isNull);
    });

    test('nothing is due before the memory loads', () {
      expect(const TownLoopShown().tierDue(person, kHallNow), isNull);
    });

    test('the festival and the tier are both kept', () {
      final both = TownLoopShown.decode('festival=2026-09-28\ntier=village');
      expect(both.tierShown, TownTier.village);
      expect(both.festivalWeek, isNotNull);
      expect(TownLoopShown.decode(both.encode()).tierShown, TownTier.village);
    });
  });
}
