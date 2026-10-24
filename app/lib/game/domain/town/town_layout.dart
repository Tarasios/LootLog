/// The town's fixed map on a 28×20 cell grid: ground, the eleven hall plots,
/// six houses, the dungeon gate, the square's statue spots and decorative
/// trees. Pure Dart, zero Flutter imports.
library;

class TownCell {
  const TownCell(this.column, this.row);
  final int column;
  final int row;

  @override
  bool operator ==(Object other) =>
      other is TownCell && other.column == column && other.row == row;

  @override
  int get hashCode => Object.hash(column, row);

  @override
  String toString() => 'TownCell($column, $row)';
}

enum TownGround { grass, path, water, square }

class TownLayout {
  const TownLayout._();

  static const TownLayout standard = TownLayout._();

  /// Plots and houses cover footprint × footprint cells from their origin.
  static const int footprint = 2;

  static const int _pathRow = 10;
  static const int _pathColumn = 14;

  int get columns => 28;
  int get rows => 20;

  TownGround groundAt(TownCell cell) {
    final inSquare =
        cell.column >= 12 && cell.column <= 15 && cell.row >= 8 && cell.row <= 11;
    if (inSquare) return TownGround.square;
    if (cell.row == _pathRow || cell.column == _pathColumn) return TownGround.path;
    final inRiver = cell.column >= 22 && cell.row <= 4 && cell.column - cell.row >= 21;
    if (inRiver) return TownGround.water;
    return TownGround.grass;
  }

  /// Hall plot index → top-left cell. Index order matches `HallState.plots`;
  /// the three starting plots sit nearest the square.
  List<TownCell> get plotOrigins => const [
        TownCell(9, 7),
        TownCell(9, 12),
        TownCell(6, 7),
        TownCell(6, 12),
        TownCell(3, 7),
        TownCell(3, 12),
        TownCell(9, 15),
        TownCell(6, 15),
        TownCell(3, 15),
        TownCell(9, 4),
        TownCell(6, 4),
      ];

  /// House slots, filled in household roster order.
  List<TownCell> get houseOrigins => const [
        TownCell(17, 7),
        TownCell(17, 12),
        TownCell(20, 7),
        TownCell(20, 12),
        TownCell(23, 7),
        TownCell(23, 12),
      ];

  TownCell get gate => const TownCell(27, _pathRow);

  List<TownCell> get statueSpots => const [
        TownCell(12, 8),
        TownCell(15, 8),
        TownCell(12, 11),
        TownCell(15, 11),
      ];

  List<TownCell> get treeCells => const [
        TownCell(0, 0),
        TownCell(2, 1),
        TownCell(5, 0),
        TownCell(0, 3),
        TownCell(1, 18),
        TownCell(4, 19),
        TownCell(11, 18),
        TownCell(18, 18),
        TownCell(25, 17),
        TownCell(27, 19),
        TownCell(17, 2),
        TownCell(19, 0),
        TownCell(0, 8),
        TownCell(26, 15),
      ];
}
