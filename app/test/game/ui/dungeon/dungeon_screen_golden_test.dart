/// Goldens for the month-end dungeon's battle stage under the Adventure
/// theme, on a phone and on a desktop, drawn with the bundled art packs: the
/// ritual fixture's goal boss, no goal pictures, the kit's frames decoded.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/art_source.dart';
import 'package:lootlog/game/assets/asset_catalog.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/battle/month_end_battle.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_providers.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_screen.dart';
import 'package:lootlog/game/ui/kit/kit.dart';

import '../../../features/spoils/spoils_fixtures.dart';
import '../town/town_test_overrides.dart';

/// Every key the screen draws outside the Flame scene.
const _screenKeys = <AssetKey>[
  KitKeys.parchment,
  KitKeys.wood,
  KitKeys.ornate,
  KitKeys.inset,
  KitKeys.ribbon,
  AssetKey('hero', 'body'),
  AssetKey('town', 'wagon'),
];

/// Decodes the sheets holding [_screenKeys] (and the weapon icon), so the
/// frames and portraits paint on the next frames of the test clock.
Future<void> _decodeScreenArt(WidgetTester tester, AssetRegistry registry) async {
  final paths = {
    for (final key in [..._screenKeys, GameAssetKeys.gear('weapon')])
      switch (registry.artFor(key)) {
        ArtRegion(:final region) => '${AssetRegistry.assetDir}${region.sheetPath}',
        ArtFile(:final fileName) => '${AssetRegistry.assetDir}$fileName',
        null => null,
      },
  }.nonNulls;
  await tester.runAsync(() async {
    final element = tester.element(find.byType(DungeonScreen));
    for (final path in paths) {
      await precacheImage(AssetImage(path), element).timeout(const Duration(seconds: 30));
    }
  });
}

void main() {
  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('dungeon battle $name', (tester) async {
      tester.view.physicalSize = size;
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
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AdventureTheme.build(),
            home: const DungeonScreen(),
          ),
        ),
      );
      await _decodeScreenArt(tester, registry);
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(DungeonScreen), matchesGoldenFile('goldens/dungeon_battle_$name.png'));
    });
  }
}
