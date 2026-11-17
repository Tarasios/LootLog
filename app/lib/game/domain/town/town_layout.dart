/// The fixed maps of a town's districts. The outpost is a 28×20 cell grid:
/// ground, the eleven hall plots, six houses, the dungeon gate, the square's
/// statue spots and decorative trees. The farmland is a phone-sized 14×20:
/// a lane in from the outpost side (the west edge), twelve fields (six to
/// start, more at the town and the city), the
/// barn and its yard, a pond, hedges and a few animals. The stage-3
/// districts (the Guard Post, Residential Quarter, Park, Market Row and
/// Castle Hill) are 14×20 maps too, kept in `town_quarter_maps.dart`. Pure
/// Dart, zero Flutter imports.
library;

import 'districts.dart'
    show
        kCastleHillDistrictId,
        kFarmlandDistrictId,
        kGuardPostDistrictId,
        kMarketRowDistrictId,
        kOutpostDistrictId,
        kParkDistrictId,
        kResidentialDistrictId;
import 'town_quarter_maps.dart';

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

/// Scenery larger than a prop that stands on a district map: the barn, hay,
/// hedges and animals. Drawn from [assetKey] over [columns] × [rows] cells
/// from [origin]; never tapped.
class TownLandmark {
  const TownLandmark(
    this.origin,
    this.assetKey,
    this.label, {
    this.columns = 1,
    this.rows = 1,
    this.underlay = false,
  });

  final TownCell origin;
  final String assetKey;
  final String label;
  final int columns;
  final int rows;

  /// Drawn under everything else on the map (a hill, a gate arch over the
  /// lane): other landmarks and the Castle may stand on it.
  final bool underlay;
}

/// A villager who strolls a district: starting at [cell], walking
/// [wanderTiles] east and back, drawn with [assetKey].
typedef TownStroller = ({TownCell cell, String assetKey, int wanderTiles});

class TownLayout {
  const TownLayout._(this.districtId);

  /// The outpost: where every town begins.
  static const TownLayout standard = TownLayout._(kOutpostDistrictId);

  /// The farmland district.
  static const TownLayout farmland = TownLayout._(kFarmlandDistrictId);

  static const TownLayout guardPost = TownLayout._(kGuardPostDistrictId);
  static const TownLayout residential = TownLayout._(kResidentialDistrictId);
  static const TownLayout park = TownLayout._(kParkDistrictId);
  static const TownLayout marketRow = TownLayout._(kMarketRowDistrictId);
  static const TownLayout castleHill = TownLayout._(kCastleHillDistrictId);

  /// The map of district [districtId], or null for a district that has no
  /// map yet (one a newer build added).
  static TownLayout? forDistrict(String districtId) => switch (districtId) {
        kOutpostDistrictId => standard,
        kFarmlandDistrictId => farmland,
        kGuardPostDistrictId => guardPost,
        kResidentialDistrictId => residential,
        kParkDistrictId => park,
        kMarketRowDistrictId => marketRow,
        kCastleHillDistrictId => castleHill,
        _ => null,
      };

  /// The district this map draws.
  final String districtId;

  bool get _isFarmland => districtId == kFarmlandDistrictId;

  /// Every map other than the outpost's is phone-sized.
  bool get _isOutpost => districtId == kOutpostDistrictId;

  /// A stage-3 district's map data, or null for the outpost and farmland.
  QuarterMap? get _quarter => quarterMapFor(districtId);

  /// Plots and houses cover footprint × footprint cells from their origin.
  static const int footprint = 2;

  /// The roads are two cells wide and cross in the middle of the square, so
  /// they meet it centred on every side.
  static const int _pathRow = 10;
  static const int _pathColumn = 14;

  static bool _onRoad(TownCell cell) =>
      cell.row == _pathRow ||
      cell.row == _pathRow - 1 ||
      cell.column == _pathColumn ||
      cell.column == _pathColumn - 1;

  int get columns => _isOutpost ? 28 : 14;
  int get rows => 20;

  TownGround groundAt(TownCell cell) {
    if (_quarter case final quarter?) return quarter.ground(cell);
    if (_isFarmland) return _farmlandGroundAt(cell);
    final inSquare =
        cell.column >= 12 && cell.column <= 15 && cell.row >= 8 && cell.row <= 11;
    if (inSquare) return TownGround.square;
    if (_onRoad(cell)) return TownGround.path;
    final inRiver = cell.column >= 22 && cell.row <= 4 && cell.column - cell.row >= 21;
    if (inRiver) return TownGround.water;
    return TownGround.grass;
  }

  /// The farmland's lane: in from the west edge along rows 9–10, then north
  /// and south along columns 6–7, with the barn's yard off it on row 6 (and
  /// a step down to the east field). The pond lies in the south-east corner.
  static TownGround _farmlandGroundAt(TownCell cell) {
    final column = cell.column, row = cell.row;
    final lane = ((row == 9 || row == 10) && column <= 7) ||
        ((column == 6 || column == 7) && row >= 2 && row <= 17) ||
        (row == 6 && column >= 8 && column <= 12) ||
        (row == 7 && column == 12);
    if (lane) return TownGround.path;
    if (column >= 10 && column <= 12 && row >= 15 && row <= 17) return TownGround.water;
    return TownGround.grass;
  }

  /// Plot index → top-left cell. In the outpost the order matches
  /// `HallState.plots` and the three starting plots sit nearest the square;
  /// in the farmland it is the district's plot index. A plot covers
  /// [footprint] × [footprint] cells; a tall building also overhangs the
  /// row above.
  List<TownCell> get plotOrigins => _quarter?.plotOrigins ?? (_isFarmland ? _farmlandPlots : _outpostPlots);

  /// The six fields every farmland has, then the three the town adds and
  /// the three the city adds (`Balance.farmlandPlotsByTier`).
  static const List<TownCell> _farmlandPlots = [
    TownCell(3, 5),
    TownCell(3, 12),
    TownCell(9, 9),
    TownCell(9, 12),
    TownCell(3, 2),
    TownCell(3, 15),
    TownCell(1, 5),
    TownCell(1, 12),
    TownCell(11, 9),
    TownCell(8, 15),
    TownCell(1, 2),
    TownCell(1, 15),
  ];

  static const List<TownCell> _outpostPlots = [
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

  /// House slots, filled in household roster order (the outpost only).
  List<TownCell> get houseOrigins => _isOutpost ? _houses : const [];

  static const List<TownCell> _houses = [
    TownCell(17, 7),
    TownCell(17, 12),
    TownCell(20, 7),
    TownCell(20, 12),
    TownCell(23, 7),
    TownCell(23, 12),
  ];

  /// Whether the map has the dungeon gate (the outpost only).
  bool get hasGate => _isOutpost;

  /// The dungeon gate. Only the outpost has one ([hasGate]).
  TownCell get gate {
    if (!hasGate) throw StateError('The $districtId has no dungeon gate.');
    return const TownCell(27, _pathRow);
  }

  /// The signpost to the neighbouring towns, where the outpost's east road
  /// meets the forest, a step from the dungeon gate (outpost only).
  TownCell? get signpost => _isOutpost ? const TownCell(25, _pathRow - 2) : null;

  /// Where a Standard adult's supply caravan camps, beside the signpost
  /// (outpost only).
  TownCell? get caravanCamp => _isOutpost ? const TownCell(26, _pathRow - 3) : null;

  /// Spots for goal statues (the outpost's square only).
  List<TownCell> get statueSpots => _isOutpost ? _statues : const [];

  static const List<TownCell> _statues = [
    TownCell(12, 8),
    TownCell(15, 8),
    TownCell(12, 11),
    TownCell(15, 11),
  ];

  List<TownCell> get treeCells => _quarter?.treeCells ?? (_isFarmland ? _farmlandTrees : _outpostTrees);

  static const List<TownCell> _outpostTrees = [
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

  static const List<TownCell> _farmlandTrees = [
    TownCell(13, 1),
    TownCell(0, 13),
    TownCell(13, 18),
  ];

  /// The barn with its hay and hen, the animals grazing by the east fields,
  /// sunflowers by the west fields, and hedges along the east and south
  /// edges (none in the outpost).
  List<TownLandmark> get landmarks => _quarter?.landmarks ?? (_isFarmland ? _farmlandLandmarks : const []);

  static final List<TownLandmark> _farmlandLandmarks = List.unmodifiable([
    TownLandmark(TownCell(9, 0), 'farm.barn.default.idle', 'Barn', columns: 3, rows: 6),
    TownLandmark(TownCell(12, 4), 'farm.hay.default.idle', 'Hay'),
    TownLandmark(TownCell(12, 5), 'farm.hay.wrapped.idle', 'Hay'),
    TownLandmark(TownCell(8, 4), 'npc.animal.chicken.idle', 'Hen'),
    TownLandmark(TownCell(13, 16), 'npc.animal.cow.idle', 'Cow'),
    TownLandmark(TownCell(12, 12), 'npc.animal.sheep.idle', 'Sheep'),
    TownLandmark(TownCell(0, 8), 'farm.sunflower.default.idle', 'Sunflower'),
    TownLandmark(TownCell(5, 8), 'farm.sunflower.default.idle', 'Sunflower'),
    for (var row = 8; row <= 13; row++)
      TownLandmark(TownCell(13, row), 'town.bush.default.idle', 'Hedge'),
    for (var column = 0; column <= 4; column++)
      TownLandmark(TownCell(column, 19), 'town.bush.default.idle', 'Hedge'),
  ]);

  /// Who strolls the district's lanes.
  List<TownStroller> get strollers => _quarter?.strollers ?? (_isFarmland
      ? const [
          (cell: TownCell(0, 9), assetKey: 'npc.farmer.default.idle', wanderTiles: 5),
          (cell: TownCell(8, 6), assetKey: 'npc.villager.b.idle', wanderTiles: 4),
        ]
      : const [
          (cell: TownCell(1, 10), assetKey: 'npc.villager.a.idle', wanderTiles: 9),
          (cell: TownCell(16, 10), assetKey: 'npc.villager.b.idle', wanderTiles: 8),
        ]);

  /// The row the household's dependents and pets walk, from [strollColumn].
  int get strollRow => _quarter?.strollRow ?? (_isFarmland ? 10 : _pathRow);
  int get strollColumn => _quarter?.strollColumn ?? (_isFarmland ? 1 : 3);

  /// Where the Castle stands (Castle Hill only), over [castleColumns] ×
  /// [castleRows] cells.
  TownCell? get castleOrigin => _quarter?.castleOrigin;
  int get castleColumns => kCastleColumns;
  int get castleRows => kCastleRows;

  /// Whether [cell] is one of the Castle's.
  bool castleCovers(TownCell cell) {
    final origin = castleOrigin;
    return origin != null &&
        cell.column >= origin.column &&
        cell.column < origin.column + castleColumns &&
        cell.row >= origin.row &&
        cell.row < origin.row + castleRows;
  }

  @override
  bool operator ==(Object other) => other is TownLayout && other.districtId == districtId;

  @override
  int get hashCode => districtId.hashCode;
}
