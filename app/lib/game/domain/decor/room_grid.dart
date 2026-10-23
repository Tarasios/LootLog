/// Placement geometry: the room's 10×8 grid and the town's free grass.
/// Pure Dart.
library;

import '../town/town_layout.dart';
import 'catalog.dart';

class RoomGrid {
  const RoomGrid._();

  static const int columns = 10;
  static const int rows = 8;

  /// The cells [item] covers with its top-left at ([column], [row]); a
  /// quarter turn (rotation 1 or 3) swaps its footprint.
  static Set<(int, int)> cellsOf(DecorItem item, int column, int row, int rotation) {
    final turned = rotation.isOdd;
    final width = turned ? item.footprintRows : item.footprintColumns;
    final height = turned ? item.footprintColumns : item.footprintRows;
    return {
      for (var i = 0; i < width; i++)
        for (var j = 0; j < height; j++) (column + i, row + j),
    };
  }

  static bool fits(DecorItem item, int column, int row, int rotation) => cellsOf(item, column, row, rotation)
      .every((cell) => cell.$1 >= 0 && cell.$2 >= 0 && cell.$1 < columns && cell.$2 < rows);
}

class TownDecorSpots {
  const TownDecorSpots._();

  static bool isFreeGrass(TownLayout layout, int column, int row) {
    final cell = TownCell(column, row);
    if (column < 0 || row < 0 || column >= layout.columns || row >= layout.rows) return false;
    if (layout.groundAt(cell) != TownGround.grass) return false;
    if (cell == layout.gate || layout.statueSpots.contains(cell) || layout.treeCells.contains(cell)) return false;
    bool covers(TownCell origin) =>
        column >= origin.column &&
        column < origin.column + TownLayout.footprint &&
        row >= origin.row &&
        row < origin.row + TownLayout.footprint;
    return !layout.plotOrigins.any(covers) && !layout.houseOrigins.any(covers);
  }
}
