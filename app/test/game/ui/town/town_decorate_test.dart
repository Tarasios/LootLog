import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';
import 'package:lootlog/game/scenes/town/town_scene_view.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import 'town_test_overrides.dart';

final DateTime _acquiredAt = DateTime.utc(2026, 10, 1);

Future<void> pumpUi(WidgetTester tester) async {
  for (var step = 0; step < 6; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpTown(WidgetTester tester, TownTestHarness harness) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: harness.overrides(tier: AdventureTier.pixel),
      child: MaterialApp(
        home: TownShell(onOpenLedger: () {}, ambientLife: false),
      ),
    ),
  );
  await pumpUi(tester);
}

Future<void> giveTownItem(TownTestHarness harness, String itemId) => harness.store.append([
  ItemAcquired(
    eventId: 'gift-$itemId',
    deviceId: 'd',
    actorId: harness.meId,
    occurredAt: _acquiredAt,
    createdAt: _acquiredAt,
    acquisitionId: 'test:$itemId',
    itemId: itemId,
    source: DecorSource.shop,
    toTown: true,
  ),
]);

TownSceneView scene(WidgetTester tester) =>
    tester.widget<TownSceneView>(find.byKey(const ValueKey('town-scene')));

Future<void> startDecorating(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('town-menu')));
  await pumpUi(tester);
  await tester.tap(find.text('Decorate town'));
  await pumpUi(tester);
}

void main() {
  testWidgets('taps open buildings until Decorate town is chosen', (tester) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    await pumpTown(tester, harness);
    expect(scene(tester).onCellTap, isNull);
    await startDecorating(tester);
    expect(scene(tester).onCellTap, isNotNull);
    expect(find.text('Done decorating'), findsNothing, reason: 'the menu closed');
  });

  testWidgets('a bench picked from the town tray is placed on tapped grass', (tester) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    await giveTownItem(harness, 'town_bench');
    await pumpTown(tester, harness);
    await startDecorating(tester);
    await tester.tap(find.byKey(const ValueKey('tray-town_bench')));
    await pumpUi(tester);
    scene(tester).onCellTap!(const TownCell(4, 6));
    await pumpUi(tester);
    final state = projectGameState(await harness.store.all());
    final placed = state.decor.townPlacements.single;
    expect((placed.itemId, placed.column, placed.row), ('town_bench', 4, 6));
  });

  testWidgets('tapping a spot with nothing picked places nothing', (tester) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    await giveTownItem(harness, 'town_bench');
    await pumpTown(tester, harness);
    await startDecorating(tester);
    scene(tester).onCellTap!(const TownCell(4, 6));
    await pumpUi(tester);
    expect(projectGameState(await harness.store.all()).decor.townPlacements, isEmpty);
  });

  testWidgets('a bench on the water is refused with a message and not placed', (tester) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    await giveTownItem(harness, 'town_bench');
    await pumpTown(tester, harness);
    await startDecorating(tester);
    await tester.tap(find.byKey(const ValueKey('tray-town_bench')));
    await pumpUi(tester);
    scene(tester).onCellTap!(const TownCell(26, 1));
    await pumpUi(tester);
    expect(projectGameState(await harness.store.all()).decor.townPlacements, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Done decorating brings buildings back', (tester) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    await pumpTown(tester, harness);
    await startDecorating(tester);
    await tester.tap(find.byKey(const ValueKey('town-menu')));
    await pumpUi(tester);
    await tester.tap(find.text('Done decorating'));
    await pumpUi(tester);
    expect(scene(tester).onCellTap, isNull);
  });
}
