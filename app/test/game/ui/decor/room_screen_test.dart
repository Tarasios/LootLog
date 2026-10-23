import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/scenes/camera_controls.dart';
import 'package:lootlog/game/scenes/room/room_scene_view.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/decor/room_screen.dart';

import '../town/town_test_overrides.dart';

/// The Flame scene ticks forever, so pumpAndSettle never settles: advance time
/// in fixed steps instead (enough for a sheet or a command to finish).
Future<void> settle(WidgetTester tester) async {
  for (var step = 0; step < 6; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpRoom(
  WidgetTester tester,
  TownTestHarness harness,
  String personId,
) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: harness.overrides(tier: AdventureTier.pixel),
      child: MaterialApp(home: RoomScreen(personId: personId)),
    ),
  );
  await settle(tester);
}

Future<List<String>> placedInRoom(TownTestHarness harness) async {
  final state = projectGameState(await harness.store.all());
  return [
    for (final placement in state.decor.placementsInRoom(harness.meId))
      placement.itemId,
  ];
}

void main() {
  testWidgets('the owner can pick an item and tap a spot to place it', (
    tester,
  ) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    await pumpRoom(tester, harness, harness.meId);
    await tester.tap(find.text('Edit room'));
    await settle(tester);
    await tester.tap(find.text('Little lamp'));
    await tester.pump();
    final scene = tester.getRect(find.byKey(const ValueKey('room-scene')));
    await tester.tapAt(scene.center);
    await settle(tester);
    expect(await placedInRoom(harness), contains('lamp_small'));
  });

  testWidgets('tapping a placed item offers rotate and put away', (
    tester,
  ) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    await harness.service.placeItem(
      itemId: 'lamp_small',
      space: DecorSpace.room,
      column: 4,
      row: 3,
    );
    await pumpRoom(tester, harness, harness.meId);
    await tester.tap(find.text('Edit room'));
    await settle(tester);
    final scene = tester.getRect(find.byKey(const ValueKey('room-scene')));
    final zoom = RoomSceneView.fitZoom(scene.size);
    // Centre of the scene is the room's centre; cell (4, 3) is the wall-offset
    // (5, 4) tile of a 12x10-tile room, whose centre lies at tile (6, 5).
    final cellCentre = scene.center.translate(
      (5.5 - 6) * kTileSize * zoom,
      (4.5 - 5) * kTileSize * zoom,
    );
    await tester.tapAt(cellCentre);
    await settle(tester);
    expect(find.text('Rotate'), findsOneWidget);
    await tester.tap(find.text('Put away'));
    await settle(tester);
    expect(await placedInRoom(harness), isNot(contains('lamp_small')));
  });

  testWidgets('rotating a placed item turns it a quarter', (tester) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    await harness.service.placeItem(
      itemId: 'bed_simple',
      space: DecorSpace.room,
      column: 2,
      row: 1,
    );
    await pumpRoom(tester, harness, harness.meId);
    await tester.tap(find.text('Edit room'));
    await settle(tester);
    final scene = tester.getRect(find.byKey(const ValueKey('room-scene')));
    final zoom = RoomSceneView.fitZoom(scene.size);
    await tester.tapAt(
      scene.center.translate(
        (3.5 - 6) * kTileSize * zoom,
        (2.5 - 5) * kTileSize * zoom,
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Rotate'));
    await settle(tester);
    final state = projectGameState(await harness.store.all());
    expect(state.decor.placementsInRoom(harness.meId).single.rotation, 1);
  });

  testWidgets('dragging an item from the tray onto the room places it', (
    tester,
  ) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    await pumpRoom(tester, harness, harness.meId);
    await tester.tap(find.text('Edit room'));
    await settle(tester);
    final scene = tester.getRect(find.byKey(const ValueKey('room-scene')));
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tray-lamp_small'))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await drag.moveTo(scene.center);
    await tester.pump(const Duration(milliseconds: 100));
    await drag.up();
    await settle(tester);
    expect(await placedInRoom(harness), contains('lamp_small'));
  });

  testWidgets('a visitor sees the room but no edit button', (tester) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    await pumpRoom(tester, harness, harness.partnerId);
    expect(find.text('Edit room'), findsNothing);
    expect(find.byTooltip('Wardrobe'), findsNothing);
  });

  testWidgets('the wardrobe lists owned outfits and wears one', (tester) async {
    final harness = await TownTestHarness.create(starterClaimed: true);
    await pumpRoom(tester, harness, harness.meId);
    await tester.tap(find.byTooltip('Wardrobe'));
    await settle(tester);
    await tester.tap(find.text('Traveller'));
    await settle(tester);
    final state = projectGameState(await harness.store.all());
    expect(state.decor.outfitOf(harness.meId), 'outfit_traveller');
  });

  group('fitZoom', () {
    test('picks the largest whole zoom that fits the whole room', () {
      // The room is 12 x 10 tiles of 16 pixels: 192 x 160.
      expect(RoomSceneView.fitZoom(const Size(390, 600)), 2);
      expect(RoomSceneView.fitZoom(const Size(1280, 700)), 4);
      expect(RoomSceneView.fitZoom(const Size(2000, 900)), 5);
    });

    test('never drops below the smallest zoom', () {
      expect(RoomSceneView.fitZoom(const Size(100, 100)), 1);
    });
  });
}
