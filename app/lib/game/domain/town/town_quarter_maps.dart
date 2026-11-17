/// The maps of the stage-3 districts, each a phone-sized 14 × 20 grid with
/// its own look and a lane along rows 9–10 joining it to the district strip's
/// neighbours (in from the west, out to the east; Castle Hill is the last):
///
/// - the Guard Post: a walled compound, towers at its corners and gate
///   arches where the lane passes through, a stone parade ground, archery
///   targets and weapon racks, guards on patrol;
/// - the Residential Quarter: two rows of cottage plots with fenced front
///   gardens along a crossroads of dirt lanes, vegetable gardens and a
///   beehive;
/// - the Park: lawns and trees, a pond, flowerbeds and benches by the
///   paths;
/// - Market Row: a wide cobbled street with shopfront plots on both sides,
///   awning stalls, crates and barrels;
/// - Castle Hill: no plots, a hill where the Castle rises stage by stage.
///
/// `town_layout.dart` reads these through [quarterMapFor]. Pure Dart, zero
/// Flutter imports.
library;

import 'district_catalog.dart';
import 'town_layout.dart';

/// One district's map data.
class QuarterMap {
  const QuarterMap({
    required this.ground,
    required this.plotOrigins,
    this.treeCells = const [],
    this.landmarks = const [],
    this.strollers = const [],
    this.strollRow = 10,
    this.strollColumn = 2,
    this.castleOrigin,
  });

  final TownGround Function(TownCell cell) ground;
  final List<TownCell> plotOrigins;
  final List<TownCell> treeCells;
  final List<TownLandmark> landmarks;
  final List<TownStroller> strollers;
  final int strollRow;
  final int strollColumn;

  /// Where the Castle stands (Castle Hill only).
  final TownCell? castleOrigin;
}

/// The map of stage-3 district [districtId], or null for another district.
QuarterMap? quarterMapFor(String districtId) => switch (districtId) {
      kGuardPostDistrictId => _guardPost,
      kResidentialDistrictId => _residential,
      kParkDistrictId => _park,
      kMarketRowDistrictId => _marketRow,
      kCastleHillDistrictId => _castleHill,
      _ => null,
    };

/// The lane every district shares: rows 9–10, edge to edge.
bool _onLane(TownCell cell) => cell.row == 9 || cell.row == 10;

TownLandmark _one(int column, int row, String key, String label) =>
    TownLandmark(TownCell(column, row), key, label);

// ---- The Guard Post -----------------------------------------------------

TownGround _guardPostGround(TownCell cell) {
  final parade = cell.column >= 5 && cell.column <= 8 && cell.row >= 4 && cell.row <= 15;
  if (parade) return TownGround.square;
  if (_onLane(cell)) return TownGround.path;
  return TownGround.grass;
}

final QuarterMap _guardPost = QuarterMap(
  ground: _guardPostGround,
  plotOrigins: const [TownCell(2, 6), TownCell(10, 6), TownCell(2, 12), TownCell(10, 12)],
  treeCells: const [TownCell(1, 3), TownCell(12, 3), TownCell(12, 15)],
  landmarks: List.unmodifiable([
    // Towers at the corners, walls between them on the north and south.
    for (final (column, row) in [(0, 0), (12, 0), (0, 18), (12, 18)])
      TownLandmark(TownCell(column, row), 'guard.tower.default.idle', 'Tower', columns: 2, rows: 2),
    for (var column = 2; column <= 11; column++) ...[
      _one(column, 1, 'guard.wall.default.idle', 'Wall'),
      _one(column, 18, 'guard.wall.default.idle', 'Wall'),
    ],
    // Gate arches over the lane where it enters and leaves.
    TownLandmark(const TownCell(0, 9), 'guard.gate.default.idle', 'Gate', columns: 2, rows: 2, underlay: true),
    TownLandmark(const TownCell(12, 9), 'guard.gate.default.idle', 'Gate', columns: 2, rows: 2, underlay: true),
    _one(0, 8, 'guard.wall.default.idle', 'Wall'),
    _one(1, 8, 'guard.wall.default.idle', 'Wall'),
    _one(12, 8, 'guard.wall.default.idle', 'Wall'),
    _one(13, 8, 'guard.wall.default.idle', 'Wall'),
    _one(5, 3, 'guard.rack.default.idle', 'Weapon rack'),
    _one(6, 3, 'guard.rack.default.idle', 'Weapon rack'),
    _one(8, 3, 'guard.target.default.idle', 'Target'),
    _one(4, 16, 'guard.target.default.idle', 'Target'),
    _one(9, 16, 'guard.barrel.default.idle', 'Barrel'),
    _one(10, 16, 'guard.barrel.default.idle', 'Barrel'),
  ]),
  strollers: const [
    (cell: TownCell(2, 9), assetKey: 'npc.guard.default.idle', wanderTiles: 9),
    (cell: TownCell(5, 13), assetKey: 'npc.guard.default.idle', wanderTiles: 3),
  ],
);

// ---- The Residential Quarter --------------------------------------------

TownGround _residentialGround(TownCell cell) {
  final crossLane = (cell.column == 6 || cell.column == 7) && cell.row >= 3 && cell.row <= 16;
  if (_onLane(cell) || crossLane) return TownGround.path;
  return TownGround.grass;
}

final QuarterMap _residential = QuarterMap(
  ground: _residentialGround,
  // A row of four cottage plots north of the lane, two more south of it.
  plotOrigins: const [
    TownCell(1, 6),
    TownCell(3, 6),
    TownCell(8, 6),
    TownCell(10, 6),
    TownCell(1, 12),
    TownCell(3, 12),
  ],
  treeCells: const [TownCell(1, 2), TownCell(4, 2), TownCell(10, 2), TownCell(12, 3), TownCell(1, 16)],
  landmarks: List.unmodifiable([
    // Fenced front gardens between the cottages and the lane.
    for (final column in [1, 2, 3, 4, 8, 9, 10, 11]) _one(column, 8, 'town.fence.default.idle', 'Fence'),
    TownLandmark(const TownCell(8, 12), 'residential.garden.default.idle', 'Garden', columns: 4, rows: 2),
    _one(12, 12, 'residential.beehive.default.idle', 'Beehive'),
    _one(8, 14, 'town_decor.flowerbed.default.idle', 'Flowers'),
    _one(11, 14, 'town_decor.flowerbed.default.idle', 'Flowers'),
    _one(4, 15, 'residential.barrel.default.idle', 'Water butt'),
  ]),
  strollers: const [
    (cell: TownCell(0, 10), assetKey: 'npc.villager.a.idle', wanderTiles: 5),
    (cell: TownCell(8, 9), assetKey: 'npc.villager.b.idle', wanderTiles: 4),
  ],
);

// ---- The Park -------------------------------------------------------------

TownGround _parkGround(TownCell cell) {
  final column = cell.column, row = cell.row;
  if (column >= 9 && column <= 12 && row >= 15 && row <= 17) return TownGround.water;
  // A path north to the lawns and one south to the pond.
  final north = (column == 6 || column == 7) && row >= 3 && row <= 8;
  final south = (row == 13 || row == 14) && column >= 6 && column <= 9;
  final southLink = (column == 6 || column == 7) && row >= 11 && row <= 14;
  if (_onLane(cell) || north || south || southLink) return TownGround.path;
  return TownGround.grass;
}

final QuarterMap _park = QuarterMap(
  ground: _parkGround,
  plotOrigins: const [TownCell(2, 6), TownCell(10, 6), TownCell(2, 12), TownCell(10, 12)],
  treeCells: const [
    TownCell(1, 1),
    TownCell(4, 1),
    TownCell(9, 1),
    TownCell(12, 1),
    TownCell(0, 4),
    TownCell(13, 6),
    TownCell(0, 15),
    TownCell(4, 17),
    TownCell(7, 17),
    TownCell(13, 13),
  ],
  landmarks: List.unmodifiable([
    TownLandmark(const TownCell(4, 4), 'park.flowerbed.default.idle', 'Flowerbed', columns: 1, rows: 2),
    TownLandmark(const TownCell(9, 4), 'park.flowerbed.default.idle', 'Flowerbed', columns: 1, rows: 2),
    _one(5, 2, 'park.lamp.default.idle', 'Lamp'),
    _one(8, 2, 'park.lamp.default.idle', 'Lamp'),
    _one(4, 8, 'park.bench.default.idle', 'Bench'),
    _one(9, 8, 'park.bench.default.idle', 'Bench'),
    _one(4, 11, 'park.bench.default.idle', 'Bench'),
    _one(9, 11, 'park.bench.default.idle', 'Bench'),
    _one(5, 15, 'town_decor.flowerbed.default.idle', 'Flowers'),
    _one(8, 15, 'town_decor.flowerbed.default.idle', 'Flowers'),
  ]),
  strollers: const [
    (cell: TownCell(0, 9), assetKey: 'npc.villager.b.idle', wanderTiles: 6),
    (cell: TownCell(6, 4), assetKey: 'npc.villager.a.idle', wanderTiles: 1),
  ],
);

// ---- Market Row -------------------------------------------------------------

TownGround _marketRowGround(TownCell cell) {
  if (cell.row >= 8 && cell.row <= 11) return TownGround.square;
  return TownGround.grass;
}

final QuarterMap _marketRow = QuarterMap(
  ground: _marketRowGround,
  // Three shopfronts north of the street, two south of it.
  plotOrigins: const [TownCell(1, 5), TownCell(6, 5), TownCell(11, 5), TownCell(3, 13), TownCell(9, 13)],
  treeCells: const [TownCell(2, 2), TownCell(11, 2), TownCell(1, 17), TownCell(12, 17)],
  landmarks: List.unmodifiable([
    TownLandmark(const TownCell(3, 5), 'market.stall.red.idle', 'Stall', columns: 2, rows: 2),
    TownLandmark(const TownCell(8, 5), 'market.stall.blue.idle', 'Stall', columns: 2, rows: 2),
    TownLandmark(const TownCell(6, 13), 'market.stall.green.idle', 'Stall', columns: 2, rows: 2),
    _one(5, 7, 'market.crate.default.idle', 'Crate'),
    _one(10, 7, 'market.sack.default.idle', 'Sack'),
    _one(1, 13, 'market.barrel.default.idle', 'Barrel'),
    _one(12, 13, 'market.crate.default.idle', 'Crate'),
    _one(12, 14, 'market.sack.default.idle', 'Sack'),
    _one(0, 12, 'park.lamp.default.idle', 'Lamp'),
    _one(13, 7, 'park.lamp.default.idle', 'Lamp'),
  ]),
  strollers: const [
    (cell: TownCell(0, 9), assetKey: 'npc.villager.a.idle', wanderTiles: 8),
    (cell: TownCell(4, 10), assetKey: 'npc.villager.b.idle', wanderTiles: 6),
  ],
);

// ---- Castle Hill ----------------------------------------------------------

/// The Castle's cells on the hilltop: [kCastleColumns] × [kCastleRows].
const TownCell _castleOrigin = TownCell(4, 5);
const int kCastleColumns = 6;
const int kCastleRows = 6;

TownGround _castleHillGround(TownCell cell) {
  // The road in from the west, to the foot of the hill (its own lane sits
  // lower, so the Castle stands in the middle of a phone's view).
  if ((cell.row == 12 || cell.row == 13) && cell.column <= 2) return TownGround.path;
  return TownGround.grass;
}

final QuarterMap _castleHill = QuarterMap(
  ground: _castleHillGround,
  plotOrigins: const [],
  castleOrigin: _castleOrigin,
  strollRow: 13,
  strollColumn: 0,
  treeCells: const [
    TownCell(0, 1),
    TownCell(1, 4),
    TownCell(12, 1),
    TownCell(13, 4),
    TownCell(0, 16),
    TownCell(2, 18),
    TownCell(12, 17),
    TownCell(13, 18),
  ],
  landmarks: List.unmodifiable([
    // The hill under the Castle, its road winding up to the gate.
    TownLandmark(const TownCell(2, 6), 'castle.hill.default.idle', 'Hill', columns: 10, rows: 10, underlay: true),
    _one(5, 17, 'town_decor.flowerbed.default.idle', 'Flowers'),
    _one(8, 17, 'town_decor.flowerbed.default.idle', 'Flowers'),
  ]),
  strollers: const [
    (cell: TownCell(0, 13), assetKey: 'npc.guard.default.idle', wanderTiles: 2),
  ],
);
