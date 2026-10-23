import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/data/game_providers.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/decor/shop_screen.dart';

import '../town/town_test_overrides.dart';

void main() {
  testWidgets(
    'shows six items with prices; buying one spends gems and celebrates',
    (tester) async {
      final harness = await TownTestHarness.create(gems: 200);
      await tester.pumpWidget(
        ProviderScope(
          overrides: harness.overrides(tier: AdventureTier.pixel),
          child: const MaterialApp(home: ShopScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final shop = harness.container.read(todaysShopProvider);
      expect(shop, hasLength(6));
      for (final item in shop) {
        expect(find.byKey(ValueKey('decor-name-${item.id}')), findsOneWidget);
        expect(find.text(item.name), findsWidgets);
      }
      final affordable = shop.first;
      await tester.tap(find.byKey(ValueKey('buy-${affordable.id}')));
      await tester.pumpAndSettle();
      final state = projectGameState(
        await tester.runAsync(harness.store.all) ?? const [],
      );
      expect(state.person(harness.meId).gems, 200 - affordable.priceGems!);
      expect(
        find.text('${affordable.name} is in your inventory.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('an item you cannot afford says how many gems are missing', (
    tester,
  ) async {
    final harness = await TownTestHarness.create(gems: 0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides(tier: AdventureTier.pixel),
        child: const MaterialApp(home: ShopScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final first = harness.container.read(todaysShopProvider).first;
    expect(find.text('${first.priceGems} more gems'), findsOneWidget);
    expect(find.byKey(ValueKey('buy-${first.id}')), findsNothing);
  });

  testWidgets('works in text tier too', (tester) async {
    final harness = await TownTestHarness.create(gems: 100);
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides(tier: AdventureTier.text),
        child: const MaterialApp(home: ShopScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final shop = harness.container.read(todaysShopProvider);
    expect(find.byKey(ValueKey('decor-name-${shop.first.id}')), findsOneWidget);
    expect(find.text('You have 100 gems'), findsOneWidget);
  });
}
