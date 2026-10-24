import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/decor/room_grid.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';

const bed = DecorItem(
  id: 'bed_simple', name: 'Bed', kind: DecorKind.furniture, rarity: DecorRarity.common,
  assetKey: AssetKey('furniture', 'bed'), footprintColumns: 1, footprintRows: 2,
);

void main() {
  test('a 1x2 bed covers two cells; a quarter turn makes it 2x1', () {
    expect(RoomGrid.cellsOf(bed, 0, 0, 0), {(0, 0), (0, 1)});
    expect(RoomGrid.cellsOf(bed, 0, 0, 1), {(0, 0), (1, 0)});
  });

  test('fits keeps every cell inside the room', () {
    expect(RoomGrid.fits(bed, 9, 6, 0), isTrue);
    expect(RoomGrid.fits(bed, 9, 7, 0), isFalse);
    expect(RoomGrid.fits(bed, 9, 7, 1), isFalse);
    expect(RoomGrid.fits(bed, -1, 0, 0), isFalse);
  });

  test('town decor goes only on free grass', () {
    const layout = TownLayout.standard;
    expect(TownDecorSpots.isFreeGrass(layout, 1, 5), isTrue);
    expect(TownDecorSpots.isFreeGrass(layout, 14, 3), isFalse, reason: 'path');
    final plot = layout.plotOrigins.first;
    expect(TownDecorSpots.isFreeGrass(layout, plot.column, plot.row), isFalse, reason: 'plot');
    expect(TownDecorSpots.isFreeGrass(layout, layout.gate.column, layout.gate.row), isFalse);
  });

  group('the first free town spot (text tier placing)', () {
    const layout = TownLayout.standard;
    const lantern = DecorItem(
      id: 'lantern', name: 'Lantern', kind: DecorKind.townDecor, rarity: DecorRarity.common,
      assetKey: AssetKey('decor', 'lantern'),
    );
    const statue = DecorItem(
      id: 'statue', name: 'Statue', kind: DecorKind.statue, rarity: DecorRarity.common,
      assetKey: AssetKey('decor', 'statue'),
    );

    test('a statue takes the first free statue spot', () {
      expect(TownDecorSpots.firstFreeSpot(layout, statue, const {}), layout.statueSpots.first);
      final first = layout.statueSpots.first;
      expect(TownDecorSpots.firstFreeSpot(layout, statue, {(first.column, first.row)}), layout.statueSpots[1]);
      final allTaken = {for (final spot in layout.statueSpots) (spot.column, spot.row)};
      expect(TownDecorSpots.firstFreeSpot(layout, statue, allTaken), isNull);
    });

    test('a decoration takes free grass nearest the middle of town, never a taken cell', () {
      final spot = TownDecorSpots.firstFreeSpot(layout, lantern, const {})!;
      expect(TownDecorSpots.isFreeGrass(layout, spot.column, spot.row), isTrue);
      final next = TownDecorSpots.firstFreeSpot(layout, lantern, {(spot.column, spot.row)})!;
      expect(next, isNot(spot));
      expect(TownDecorSpots.isFreeGrass(layout, next.column, next.row), isTrue);
    });
  });
}
