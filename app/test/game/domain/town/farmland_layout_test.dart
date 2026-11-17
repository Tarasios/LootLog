import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';

void main() {
  const layout = TownLayout.farmland;

  bool insideMap(TownCell cell) =>
      cell.column >= 0 && cell.row >= 0 && cell.column < layout.columns && cell.row < layout.rows;

  Set<TownCell> footprintOf(TownCell origin, {int columns = TownLayout.footprint, int rows = TownLayout.footprint}) => {
        for (var column = 0; column < columns; column++)
          for (var row = 0; row < rows; row++) TownCell(origin.column + column, origin.row + row),
      };

  test('a phone-sized map of 14 x 20 cells', () {
    expect(layout.columns, 14);
    expect(layout.rows, 20);
    expect(layout.districtId, kFarmlandDistrictId);
  });

  test('one plot per farmland plot the rules know', () {
    expect(layout.plotOrigins, hasLength(districtById(kFarmlandDistrictId)!.plotCount));
    expect(layout.houseOrigins, isEmpty);
    expect(layout.statueSpots, isEmpty);
    expect(layout.hasGate, isFalse);
  });

  test('plots, the extra row above them and landmarks never overlap, on grass', () {
    final used = <TownCell>{};
    for (final origin in layout.plotOrigins) {
      // A tall building overhangs the row above its plot.
      final overhang = TownCell(origin.column, origin.row - 1);
      for (final cell in {...footprintOf(origin), ...footprintOf(overhang, rows: 1)}) {
        expect(insideMap(cell), isTrue, reason: '$cell is off the map');
        expect(layout.groundAt(cell), TownGround.grass, reason: '$cell is not grass');
        expect(used.add(cell), isTrue, reason: '$cell is used twice');
      }
    }
    for (final landmark in layout.landmarks) {
      for (final cell in footprintOf(landmark.origin, columns: landmark.columns, rows: landmark.rows)) {
        expect(insideMap(cell), isTrue, reason: '${landmark.label} at $cell is off the map');
        expect(layout.groundAt(cell), isNot(TownGround.water), reason: '${landmark.label} stands in the pond');
        expect(used.add(cell), isTrue, reason: '${landmark.label} at $cell is used twice');
      }
    }
  });

  test('a lane enters from the outpost side (the west edge) and reaches every plot', () {
    final entrance = [
      for (var row = 0; row < layout.rows; row++)
        if (layout.groundAt(TownCell(0, row)) == TownGround.path) row,
    ];
    expect(entrance, isNotEmpty);
    // Every plot touches the lane, a field gap or the yard one cell away.
    final pathCells = {
      for (var column = 0; column < layout.columns; column++)
        for (var row = 0; row < layout.rows; row++)
          if (layout.groundAt(TownCell(column, row)) == TownGround.path) TownCell(column, row),
    };
    for (final origin in layout.plotOrigins) {
      final near = [
        for (var column = origin.column - 2; column < origin.column + 4; column++)
          for (var row = origin.row; row < origin.row + 2; row++) TownCell(column, row),
      ];
      expect(near.any(pathCells.contains), isTrue, reason: 'plot at $origin is off the lane');
    }
  });

  test('a pond for character and a barn in its yard', () {
    final water = [
      for (var column = 0; column < layout.columns; column++)
        for (var row = 0; row < layout.rows; row++)
          if (layout.groundAt(TownCell(column, row)) == TownGround.water) TownCell(column, row),
    ];
    expect(water, isNotEmpty);
    expect(layout.landmarks.map((landmark) => landmark.assetKey), contains('farm.barn.default.idle'));
  });

  test('every district with a map has a layout; the teasers have none yet', () {
    expect(TownLayout.forDistrict(kOutpostDistrictId), TownLayout.standard);
    expect(TownLayout.forDistrict(kFarmlandDistrictId), TownLayout.farmland);
    expect(TownLayout.forDistrict('guardPost'), isNull);
    expect(TownLayout.standard.hasGate, isTrue);
    expect(TownLayout.standard.landmarks, isEmpty);
  });
}
