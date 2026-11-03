/// Goldens for the shop counter, phone and desktop, under the Adventure theme
/// with the bundled art packs: some slots affordable, the rest saying how
/// many gems are missing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/decor/shop_screen.dart';
import 'package:lootlog/game/ui/kit/kit.dart';

import '../town/town_test_overrides.dart';
import 'decor_golden_support.dart';

void main() {
  for (final (name, size) in decorGoldenSizes) {
    testWidgets('shop $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = await TownTestHarness.create(gems: 60);
      final registry = (await tester.runAsync(loadGameAssetRegistry))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: harness.overrides(tier: AdventureTier.pixel, registry: registry),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AdventureTheme.build(),
            // Pushed over a home route, as in the app, so the back button shows.
            initialRoute: '/shop',
            routes: {
              '/': (_) => const SizedBox.shrink(),
              '/shop': (_) => const ShopScreen(),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await decodeAllGameArt(tester, registry, find.byType(ShopScreen));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(ShopScreen),
        matchesGoldenFile('goldens/shop_screen_$name.png'),
      );
    });
  }
}
