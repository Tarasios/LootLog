/// The Castle's celebrations: a stage finished lately is celebrated once on
/// entering the town (the banners with the title they bring), never for a
/// stage finished long ago, never mid-session, and the device remembers
/// what it has shown.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/ui/town/town_loop_providers.dart';

import '../../domain/town/growth_fixtures.dart';
import '../hall_harness.dart' show before, kHallNow, robin, storeWith;
import 'long_road_fixtures.dart';

/// Stages 1..[count], back to back, the last finishing [finishedAgo]
/// before now.
List<CastleStageStarted> _stages(int count, {Duration finishedAgo = const Duration(hours: 3)}) {
  var start = before(finishedAgo);
  for (var stage = count; stage >= 1; stage--) {
    start = start.subtract(Duration(days: Balance.castleStages[stage - 1].buildDays));
  }
  final stages = <CastleStageStarted>[];
  for (var stage = 1; stage <= count; stage++) {
    stages.add(castleStageStarted('stage-$stage', stage, when: start));
    start = start.add(Duration(days: Balance.castleStages[stage - 1].buildDays));
  }
  return stages;
}

Future<InMemoryGameEventStore> _enter(WidgetTester tester, List<CastleStageStarted> stages) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // City reached long ago, so only the Castle is news.
  final store = await storeWith(longRoadEvents(TownTier.city, extra: stages));
  await tester.pumpWidget(longRoadHost(store, popups: true));
  await _frames(tester);
  return store;
}

Future<void> _frames(WidgetTester tester) async {
  for (var step = 0; step < 8; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('a stage finished lately is celebrated on entering', (tester) async {
    await _enter(tester, _stages(1));
    expect(find.text('Foundation finished!'), findsOneWidget);
    expect(find.textContaining('Stone by stone'), findsOneWidget);
    await tester.tap(find.text('Huzzah!'));
    for (var step = 0; step < 4; step++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Foundation finished!'), findsNothing);
  });

  testWidgets('the finished Castle brings its title', (tester) async {
    // Long enough ago that the city was reached first.
    await _enter(tester, _stages(5));
    expect(find.text('Banners finished!'), findsOneWidget);
    expect(find.textContaining('the Castle is complete'), findsOneWidget);
    expect(find.text('You are now Keeper of the Castle.'), findsOneWidget);
  });

  testWidgets('a stage finished long ago is history, not a pop-up', (tester) async {
    await _enter(tester, _stages(1, finishedAgo: const Duration(days: 20)));
    expect(find.textContaining(' finished!'), findsNothing);
  });

  testWidgets('a stage that finishes mid-session opens nothing until the next entry', (tester) async {
    final store = await _enter(tester, const []);
    await store.append(_stages(1));
    await _frames(tester);
    expect(find.textContaining(' finished!'), findsNothing);
  });

  group('the memory', () {
    final castle = projectGameState(longRoadEvents(TownTier.city, extra: _stages(2))).townOf(robin).castle;

    test('stages are due once, then remembered across restarts', () {
      const fresh = TownLoopShown(loaded: true);
      expect(fresh.castleDue(castle, kHallNow), 2);
      const shown = TownLoopShown(loaded: true, castleShown: 2);
      expect(shown.castleDue(castle, kHallNow), isNull);
      final restored = TownLoopShown.decode(shown.encode());
      expect(restored.castleShown, 2);
      expect(restored.castleDue(castle, kHallNow), isNull);
    });

    test('nothing is due before the memory loads', () {
      expect(const TownLoopShown().castleDue(castle, kHallNow), isNull);
    });
  });
}
