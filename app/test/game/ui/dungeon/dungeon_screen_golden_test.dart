/// Golden for the month-end dungeon's battle stage on a phone, drawn with
/// the bundled art packs: the ritual fixture's goal boss, no goal pictures.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/battle/month_end_battle.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_providers.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_screen.dart';

import '../../../features/spoils/spoils_fixtures.dart';
import '../town/town_test_overrides.dart';

void main() {
  testWidgets('dungeon battle phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final registry = (await tester.runAsync(loadGameAssetRegistry))!;
    final harness = (await tester.runAsync(TownTestHarness.create))!;
    final (household, ritual) = ritualFixture();
    // Decode the art for real first (bounded); the scene then finds it
    // ready and draws within a few frames of the test clock.
    await tester.runAsync(() => PackAtlas.warmUp(registry).timeout(const Duration(seconds: 30)));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...harness.overrides(
            tier: AdventureTier.pixel,
            registry: registry,
            battle: MonthEndBattle.from(ritual, household),
          ),
          spoilsWriterProvider.overrideWithValue((ritual, result) async {}),
          onTimeRitualMonthsProvider.overrideWith((ref) async => 0),
        ],
        child: const MaterialApp(debugShowCheckedModeBanner: false, home: DungeonScreen()),
      ),
    );
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(DungeonScreen), matchesGoldenFile('goldens/dungeon_battle_phone.png'));
  });
}
