/// Goldens for the town as the Adventure home, phone and desktop, drawn with
/// the bundled art packs. No ambient villagers, so the frames are stable.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import 'town_test_overrides.dart';

void main() {
  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1280, 800)),
  ]) {
    testWidgets('town shell $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final registry = (await tester.runAsync(loadGameAssetRegistry))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: townTestOverrides(tier: AdventureTier.pixel, registry: registry),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: TownShell(onOpenLedger: () {}, ambientLife: false),
          ),
        ),
      );
      // The scene decodes its sheets on real time; the game loop draws on
      // the test clock. Alternate until the first frames are on screen.
      for (var round = 0; round < 6; round++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await expectLater(
        find.byType(TownShell),
        matchesGoldenFile('goldens/town_shell_$name.png'),
      );
    });
  }
}
