/// Decorating in the text tier, with no pixel scene: the room as a list with
/// move, rotate and put away and a grid picker for spots, and the town's
/// decorations as a list with a tray.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/decor/decor_state.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/decor/room_grid.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/decor/room_screen.dart';
import 'package:lootlog/game/ui/town/town_decor_text_screen.dart';

import '../town/town_test_overrides.dart';

Future<void> pumpText(WidgetTester tester, TownTestHarness harness, Widget screen) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: harness.overrides(tier: AdventureTier.text),
    child: MaterialApp(home: screen),
  ));
  await tester.pumpAndSettle();
}

Future<List<Placement>> roomOf(TownTestHarness harness) async =>
    projectGameState(await harness.store.all()).decor.placementsInRoom(harness.meId);

void main() {
  group('the room in text tier', () {
    testWidgets('renders as a list, with no pixel scene', (tester) async {
      final harness = await TownTestHarness.create(starterClaimed: true);
      await harness.service.placeItem(itemId: 'lamp_small', space: DecorSpace.room, column: 4, row: 3);
      await pumpText(tester, harness, RoomScreen(personId: harness.meId));
      expect(find.byKey(const ValueKey('room-text')), findsOneWidget);
      expect(find.byKey(const ValueKey('room-scene')), findsNothing);
      expect(find.text('Little lamp'), findsOneWidget);
      expect(find.text('Column 5, row 4'), findsOneWidget);
    });

    testWidgets('picking from the tray asks for a spot on the grid and places it', (tester) async {
      final harness = await TownTestHarness.create(starterClaimed: true);
      await pumpText(tester, harness, RoomScreen(personId: harness.meId));
      await tester.tap(find.text('Edit room'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tray-lamp_small')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cell-2-1')));
      await tester.pumpAndSettle();
      final placed = (await roomOf(harness)).single;
      expect((placed.itemId, placed.column, placed.row), ('lamp_small', 2, 1));
    });

    testWidgets('move, rotate and put away work from the list', (tester) async {
      final harness = await TownTestHarness.create(starterClaimed: true);
      await harness.service.placeItem(itemId: 'lamp_small', space: DecorSpace.room, column: 4, row: 3);
      await pumpText(tester, harness, RoomScreen(personId: harness.meId));
      await tester.tap(find.text('Edit room'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Move'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<InkWell>(find.byKey(const ValueKey('cell-4-3'))).onTap,
        isNotNull,
        reason: 'an item can shift over its own old spot',
      );
      await tester.tap(find.byKey(const ValueKey('cell-7-6')));
      await tester.pumpAndSettle();
      var placed = (await roomOf(harness)).single;
      expect((placed.column, placed.row), (7, 6));

      await tester.tap(find.byTooltip('Rotate'));
      await tester.pumpAndSettle();
      placed = (await roomOf(harness)).single;
      expect(placed.rotation, 1);

      await tester.tap(find.byTooltip('Put away'));
      await tester.pumpAndSettle();
      expect(await roomOf(harness), isEmpty);
    });

    testWidgets('cells another item covers cannot be picked', (tester) async {
      final harness = await TownTestHarness.create(starterClaimed: true);
      await harness.service.placeItem(itemId: 'lamp_small', space: DecorSpace.room, column: 0, row: 0);
      await pumpText(tester, harness, RoomScreen(personId: harness.meId));
      await tester.tap(find.text('Edit room'));
      await tester.pumpAndSettle();
      final trayItem = find.byWidgetPredicate(
        (widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('tray-'),
      );
      await tester.tap(trayItem.first);
      await tester.pumpAndSettle();
      expect(tester.widget<InkWell>(find.byKey(const ValueKey('cell-0-0'))).onTap, isNull);
      expect(find.byKey(ValueKey('cell-${RoomGrid.columns - 1}-${RoomGrid.rows - 1}')), findsOneWidget);
    });

    testWidgets('a visitor sees the list but cannot edit', (tester) async {
      final harness = await TownTestHarness.create(starterClaimed: true);
      await pumpText(tester, harness, RoomScreen(personId: harness.partnerId));
      expect(find.byKey(const ValueKey('room-text')), findsOneWidget);
      expect(find.text('Edit room'), findsNothing);
    });
  });

  group('town decorations in text tier', () {
    Future<void> giveTownItem(TownTestHarness harness, String itemId) => harness.store.append([
          ItemAcquired(
            eventId: 'gift-$itemId',
            deviceId: 'd',
            actorId: harness.meId,
            occurredAt: DateTime.utc(2026, 10, 1),
            createdAt: DateTime.utc(2026, 10, 1),
            acquisitionId: 'test:$itemId',
            itemId: itemId,
            source: DecorSource.shop,
            toTown: true,
          ),
        ]);

    testWidgets('a picked decoration takes a free spot; Put away takes it back', (tester) async {
      final harness = await TownTestHarness.create(starterClaimed: true);
      await giveTownItem(harness, 'town_bench');
      await pumpText(tester, harness, const TownDecorTextScreen());
      expect(find.text('Nothing stands in the town yet.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tray-town_bench')));
      await tester.pumpAndSettle();
      final placed = projectGameState(await harness.store.all()).decor.townPlacements.single;
      expect(placed.itemId, 'town_bench');
      expect(TownDecorSpots.isFreeGrass(TownLayout.standard, placed.column, placed.row), isTrue);
      expect(find.text('On the grass'), findsOneWidget);

      await tester.tap(find.byTooltip('Put away'));
      await tester.pumpAndSettle();
      expect(projectGameState(await harness.store.all()).decor.townPlacements, isEmpty);
    });
  });
}
