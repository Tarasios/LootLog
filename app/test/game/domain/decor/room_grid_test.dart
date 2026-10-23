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
}
