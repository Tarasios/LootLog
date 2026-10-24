import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';

void main() {
  const layout = TownLayout.standard;

  bool insideMap(TownCell cell) =>
      cell.column >= 0 && cell.row >= 0 && cell.column < layout.columns && cell.row < layout.rows;

  Set<TownCell> footprintOf(TownCell origin) => {
        for (var i = 0; i < TownLayout.footprint; i++)
          for (var j = 0; j < TownLayout.footprint; j++) TownCell(origin.column + i, origin.row + j),
      };

  test('a plot for every possible hall plot, and six houses', () {
    expect(layout.plotOrigins, hasLength(11));
    expect(layout.houseOrigins, hasLength(6));
  });

  test('plots, houses, the gate and statues never overlap and stay off water and paths', () {
    final used = <TownCell>{};
    for (final origin in [...layout.plotOrigins, ...layout.houseOrigins]) {
      for (final cell in footprintOf(origin)) {
        expect(insideMap(cell), isTrue, reason: '$cell is off the map');
        expect(layout.groundAt(cell), TownGround.grass, reason: '$cell is not grass');
        expect(used.add(cell), isTrue, reason: '$cell is used twice');
      }
    }
    for (final spot in [layout.gate, ...layout.statueSpots, ...layout.treeCells]) {
      expect(insideMap(spot), isTrue);
      expect(used.add(spot), isTrue, reason: '$spot is used twice');
    }
  });

  test('the gate sits on the path at the right edge', () {
    expect(layout.groundAt(layout.gate), TownGround.path);
    expect(layout.gate.column, layout.columns - 1);
  });

  test('statue spots are on the square', () {
    for (final spot in layout.statueSpots) {
      expect(layout.groundAt(spot), TownGround.square);
    }
  });
}
