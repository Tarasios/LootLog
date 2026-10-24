/// Goldens for a furnished room, phone and desktop, drawn with the bundled
/// art packs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/decor/room_screen.dart';

import '../town/town_test_overrides.dart';

void main() {
  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1280, 800)),
  ]) {
    testWidgets('room $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = await TownTestHarness.create(starterClaimed: true);
      for (final (itemId, column, row) in [
        ('bed_simple', 1, 1),
        ('rug_round', 4, 3),
        ('lamp_small', 3, 1),
      ]) {
        await harness.service.placeItem(
          itemId: itemId,
          space: DecorSpace.room,
          column: column,
          row: row,
        );
      }
      await harness.service.equipItem('outfit_traveller');
      final registry = (await tester.runAsync(loadGameAssetRegistry))!;
      // Decode the art for real first (bounded); the scene then finds it
      // ready and draws within a few frames of the test clock.
      await tester.runAsync(() => PackAtlas.warmUp(registry).timeout(const Duration(seconds: 30)));
      await tester.pumpWidget(
        ProviderScope(
          overrides: harness.overrides(
            tier: AdventureTier.pixel,
            registry: registry,
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RoomScreen(personId: harness.meId),
          ),
        ),
      );
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await expectLater(
        find.byType(RoomScreen),
        matchesGoldenFile('goldens/room_screen_$name.png'),
      );
    });
  }
}
