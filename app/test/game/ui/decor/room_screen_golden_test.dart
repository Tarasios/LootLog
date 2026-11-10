/// Goldens for a furnished room on its wood board, phone and desktop, under
/// the Adventure theme with the bundled art packs: as the owner first sees
/// it, and mid-edit with the inventory tray open.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/decor/room_screen.dart';
import 'package:lootlog/game/ui/kit/kit.dart';

import '../town/town_test_overrides.dart';
import 'decor_golden_support.dart';

void main() {
  for (final (name, size) in decorGoldenSizes) {
    for (final editing in [false, true]) {
      final variant = editing ? '${name}_editing' : name;
      testWidgets('room $variant', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final harness = await TownTestHarness.create(starterClaimed: true);
        for (final (itemId, column, row) in [
          ('bed_simple', 1, 1),
          ('rug_round', 4, 3),
          // Mid-edit, the lamp waits in the tray.
          if (!editing) ('lamp_small', 3, 1),
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
              theme: AdventureTheme.build(),
              // Pushed over a home route, as in the app, so the back button
              // shows.
              initialRoute: '/room',
              routes: {
                '/': (_) => const SizedBox.shrink(),
                '/room': (_) => RoomScreen(personId: harness.meId),
              },
            ),
          ),
        );
        await decodeAllGameArt(tester, registry, find.byType(RoomScreen));
        if (editing) {
          await tester.tap(find.text('Edit room'));
          await tester.pump();
          // Pick the lamp, so the placing hint shows above the tray.
          await tester.tap(find.byKey(const ValueKey('tray-lamp_small')));
        }
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(RoomScreen),
          matchesGoldenFile('goldens/room_screen_$variant.png'),
        );
      });
    }
  }
}
