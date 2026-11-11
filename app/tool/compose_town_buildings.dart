/// Composes the town's buildings from the Kenney Tiny Town and Tiny Farm
/// tiles (both CC0).
///
/// Tiny Town ships roofs, walls, doors and tools as separate 16 px tiles, so a
/// building is assembled rather than cut out: a roof over a wall row, with a
/// door and either a window or a tool sign that tells the building types
/// apart. Each building grows with its tier:
///
/// - tiers 1–2: 2×2 cells, a squat roof row over the wall row;
/// - tiers 3–4: 2×3 cells, a full two-row roof (the extra row overhangs the
///   cell above the plot), tier 4 with a dormer;
/// - tier 5: the tier-4 look with a pennant flying from the roof.
///
/// The farmland's buildings (farm, orchard, granary), its empty field plot
/// and its barn come from Tiny Farm (`tool/town_farm_art.dart`). This writes
/// `assets/game/packs/town_composed/` (the sheet and its `regions.json`);
/// rerun it after changing a recipe:
///
///     dart run tool/compose_town_buildings.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

import 'town_farm_art.dart';

const String _outputFolder = 'assets/game/packs/town_composed';

/// Roof colours: the left tile's column on the sheet (the right is two on).
const int _blueRoof = 0, _redRoof = 4;

/// Wall materials: the column of the material's first tile on rows 6 and 7.
const int _brickWall = 0, _stoneWall = 4;

/// Tool signs hung on a wall.
const Cell _pickaxe = (7, 9), _pitchfork = (8, 9), _key = (9, 9), _bow = (10, 9);
const Cell _axe = (7, 10), _hammer = (8, 10), _bucket = (10, 10);

/// One building: its roof, wall, whether it has double doors, and its sign.
class Recipe {
  const Recipe(this.roof, this.wall, {this.doubleDoor = false, this.sign});
  final int roof;
  final int wall;
  final bool doubleDoor;
  final Cell? sign;
}

const Map<String, Recipe> _buildings = {
  'central_hall': Recipe(_redRoof, _stoneWall, doubleDoor: true),
  'scribes_desk': Recipe(_blueRoof, _brickWall),
  'storehouse': Recipe(_blueRoof, _brickWall, doubleDoor: true),
  'forge': Recipe(_redRoof, _stoneWall, sign: _hammer),
  'vault': Recipe(_blueRoof, _stoneWall, sign: _key),
  'lumberyard': Recipe(_redRoof, _brickWall, sign: _axe),
  'quarry': Recipe(_redRoof, _stoneWall, sign: _pickaxe),
  'mine': Recipe(_blueRoof, _stoneWall, sign: _bucket),
  'herb_garden': Recipe(_redRoof, _brickWall, sign: _pitchfork),
  'hunters_lodge': Recipe(_blueRoof, _brickWall, sign: _bow),
};

const Recipe _house = Recipe(_redRoof, _brickWall);

/// A squat roof row: the top half of the roof's upper tile over the bottom
/// half of its lower tile, so one 16 px row carries both ridge and eave.
void _drawSquatRoof(img.Image target, int roofColumn, int y) {
  for (final (offset, column) in [(0, roofColumn), (tile, roofColumn + 2)]) {
    final ridge = img.copyCrop(townCell((column, 4)), x: 0, y: 0, width: tile, height: 8);
    final eave = img.copyCrop(townCell((column, 5)), x: 0, y: 8, width: tile, height: 8);
    draw(target, ridge, offset, y);
    draw(target, eave, offset, y + 8);
  }
}

/// A full roof: the upper roof tiles over the lower ones, with a dormer
/// (the roof sheet's own window tile) on the right of the upper row.
void _drawTallRoof(img.Image target, int roofColumn, {required bool dormer}) {
  draw(target, townCell((roofColumn, 4)), 0, 0);
  draw(target, townCell(dormer ? (roofColumn + 3, 4) : (roofColumn + 2, 4)), tile, 0);
  draw(target, townCell((roofColumn, 5)), 0, tile);
  draw(target, townCell((roofColumn + 2, 5)), tile, tile);
}

/// The wall row at [y]: double doors, a wall with its sign beside a door,
/// or a window beside a door.
void _drawWall(img.Image target, Recipe recipe, int y) {
  final wall = recipe.wall;
  if (recipe.doubleDoor) {
    draw(target, townCell((wall + 2, 7)), 0, y);
    draw(target, townCell((wall + 3, 7)), tile, y);
  } else if (recipe.sign case final sign?) {
    draw(target, townCell((wall, 6)), 0, y);
    draw(target, townCell(sign), 0, y);
    draw(target, townCell((wall + 1, 7)), tile, y);
  } else {
    draw(target, townCell((wall, 7)), 0, y);
    draw(target, townCell((wall + 1, 7)), tile, y);
  }
}

/// A building at tiers 1–2: the squat roof over the wall.
img.Image _squatBuilding(Recipe recipe) {
  final building = blank(2, 2);
  _drawSquatRoof(building, recipe.roof, 0);
  _drawWall(building, recipe, tile);
  return building;
}

/// A building at tiers 3–5: the full roof over the wall, a dormer from tier
/// 4 and a pennant at tier 5.
img.Image _tallBuilding(Recipe recipe, int tier) {
  final building = blank(2, 3);
  _drawTallRoof(building, recipe.roof, dormer: tier >= 4);
  _drawWall(building, recipe, 2 * tile);
  if (tier >= 5) drawPennant(building, x: 4);
  return building;
}

/// The Arcane Well: Tiny Town's two-tile well, centred; from tier 3 it
/// stands between two lanterns under a taller canopy of trees, and at tier
/// 5 a pennant flies.
img.Image _well(int tier) {
  final rows = tier < 3 ? 2 : 3;
  final well = blank(2, rows);
  if (tier >= 3) {
    draw(well, townCell((4, 0)), 0, 0);
    draw(well, townCell((4, 0)), tile, 0);
    draw(well, townCell((9, 7)), 0, 2 * tile);
    draw(well, townCell((9, 7)), tile, 2 * tile);
  }
  final top = (rows - 2) * tile;
  draw(well, townCell((8, 7)), 8, top);
  draw(well, townCell((8, 8)), 8, top + tile);
  if (tier >= 5) drawPennant(well, x: 1);
  return well;
}

/// Four corner tiles of a 3x3 Tiny Town ring (dirt patch, fence) as a 2x2.
img.Image _ring(Cell topLeft) {
  final ring = blank(2, 2);
  final (column, row) = topLeft;
  draw(ring, townCell((column, row)), 0, 0);
  draw(ring, townCell((column + 2, row)), tile, 0);
  draw(ring, townCell((column, row + 2)), 0, tile);
  draw(ring, townCell((column + 2, row + 2)), tile, tile);
  return ring;
}

/// A locked plot: a fenced lot with a notice board.
img.Image _lockedPlot() {
  final plot = _ring((8, 3));
  draw(plot, townCell((11, 6)), 8, 8);
  return plot;
}

/// A plot being built on: the fenced lot with a hammer at work. Drawn over
/// the building, which shows through the middle.
img.Image _buildingSite() {
  final site = _ring((8, 3));
  draw(site, townCell(_hammer), 8, 8);
  return site;
}

/// Still water with a few lighter ripples.
img.Image _water() {
  final water = blank(1, 1);
  img.fill(water, color: img.ColorRgba8(0x4F, 0x8F, 0xD6, 0xFF));
  final ripple = img.ColorRgba8(0x8C, 0xBF, 0xF0, 0xFF);
  for (final (x, y, length) in [(2, 4, 4), (9, 10, 5), (4, 13, 3)]) {
    for (var step = 0; step < length; step++) {
      water.setPixel(x + step, y, ripple);
    }
  }
  return water;
}

/// Every composed sprite by region key; a building's five tiers each get a
/// key, tiers sharing a look sharing its region.
Map<String, img.Image> _sprites() {
  final sprites = <String, img.Image>{};
  void tiers(String key, img.Image Function(int tier) look, {bool everyTierOwnLook = false}) {
    final looks = <String, img.Image>{};
    for (var tier = 1; tier <= 5; tier++) {
      final shared = everyTierOwnLook ? '$tier' : switch (tier) { 1 || 2 => 'low', 3 => 'tall', 4 => 'dormer', _ => 'top' };
      sprites['$key.t$tier.idle'] = looks.putIfAbsent(shared, () => look(tier));
    }
  }

  for (final MapEntry(key: name, value: recipe) in _buildings.entries) {
    tiers('building.$name', (tier) => tier < 3 ? _squatBuilding(recipe) : _tallBuilding(recipe, tier));
  }
  tiers('building.arcane_well', _well);
  for (final farmBuilding in farmBuildingNames) {
    tiers('building.$farmBuilding', (tier) => farmBuildingLook(farmBuilding, tier), everyTierOwnLook: true);
  }
  sprites.addAll({
    'town.house.default.idle': _squatBuilding(_house),
    'town.plot.locked.idle': _lockedPlot(),
    'town.scaffold.default.idle': _buildingSite(),
    'town.plot.empty.idle': _ring((0, 1)),
    'farm.plot.empty.idle': emptyField(),
    'farm.barn.default.idle': barn(),
    'town.ground.water.idle': _water(),
  });
  return sprites;
}

void main() {
  loadSourceSheets();
  final sprites = _sprites();
  final packed = packSheet(sprites, columns: 16);
  Directory(_outputFolder).createSync(recursive: true);
  File('$_outputFolder/tilemap_packed.png').writeAsBytesSync(img.encodePng(packed.sheet));
  File('$_outputFolder/regions.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'sheet': 'tilemap_packed.png',
      'cellSize': tile,
      'spacing': 0,
      'regions': packed.regions,
    })}\n',
  );
  File('$_outputFolder/License.txt').writeAsStringSync(
    'Composed from Kenney "Tiny Town" and "Tiny Farm" tiles (www.kenney.nl), '
    'Creative Commons Zero (CC0).\n'
    'See ../tiny_town/License.txt and ../tiny_farm/License.txt. Regenerate with '
    'tool/compose_town_buildings.dart.\n',
  );
  stdout.writeln('Wrote ${packed.regions.length} regions to $_outputFolder');
}
