import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/decor/inventory_tray.dart';

import '../town/town_test_overrides.dart';

void main() {
  testWidgets('lists available room items and reports a pick', (tester) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    DecorItem? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides(tier: AdventureTier.pixel),
        child: MaterialApp(
          home: Scaffold(
            body: InventoryTray(
              space: DecorSpace.room,
              personId: harness.meId,
              onPick: (item) => picked = item,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Simple bed'), findsOneWidget);
    expect(
      find.text('Traveller'),
      findsNothing,
      reason: 'outfits are worn, not placed',
    );
    await tester.tap(find.text('Simple bed'));
    expect(picked?.id, 'bed_simple');
  });

  testWidgets('an empty tray points to the shop and chests', (tester) async {
    final harness = await TownTestHarness.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides(tier: AdventureTier.pixel),
        child: MaterialApp(
          home: Scaffold(
            body: InventoryTray(
              space: DecorSpace.room,
              personId: harness.meId,
              onPick: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing to place'), findsOneWidget);
  });

  testWidgets('the town tray is empty without town decorations', (
    tester,
  ) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides(tier: AdventureTier.pixel),
        child: MaterialApp(
          home: Scaffold(
            body: InventoryTray(
              space: DecorSpace.town,
              personId: harness.meId,
              onPick: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Simple bed'), findsNothing);
    expect(find.textContaining('Nothing to place'), findsOneWidget);
  });
}
