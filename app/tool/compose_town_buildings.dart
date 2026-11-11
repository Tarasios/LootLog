/// Composes the town's buildings from the Kenney Tiny Town tiles (CC0).
///
/// Tiny Town ships roofs, walls, doors and tools as separate 16 px tiles, so a
/// building is assembled rather than cut out: a roof row over a wall row, with
/// a door and either a window or a tool sign that tells the building types
/// apart. This writes `assets/game/packs/town_composed/` (the sheet and its
/// `regions.json`); rerun it after changing a recipe:
///
///     dart run tool/compose_town_buildings.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

const int _tile = 16;
const String _sourceSheet = 'assets/game/packs/tiny_town/tilemap_packed.png';
const String _outputFolder = 'assets/game/packs/town_composed';

/// Tiny Town cells, as (column, row).
typedef Cell = (int, int);

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

late img.Image _source;

img.Image _cell(Cell cell) => img.copyCrop(
  _source,
  x: cell.$1 * _tile,
  y: cell.$2 * _tile,
  width: _tile,
  height: _tile,
);

void _draw(img.Image target, img.Image tile, int x, int y) =>
    img.compositeImage(target, tile, dstX: x, dstY: y);

/// A roof row: the top half of the roof's upper tile over the bottom half of
/// its lower tile, so one 16 px row carries both the ridge and the eave.
void _drawRoof(img.Image target, int roofColumn, int x, int y) {
  for (final (offset, column) in [(0, roofColumn), (_tile, roofColumn + 2)]) {
    final ridge = img.copyCrop(_cell((column, 4)), x: 0, y: 0, width: _tile, height: 8);
    final eave = img.copyCrop(_cell((column, 5)), x: 0, y: 8, width: _tile, height: 8);
    _draw(target, ridge, x + offset, y);
    _draw(target, eave, x + offset, y + 8);
  }
}

img.Image _building(Recipe recipe) {
  final building = img.Image(width: _tile * 2, height: _tile * 2, numChannels: 4);
  _drawRoof(building, recipe.roof, 0, 0);
  final wall = recipe.wall;
  if (recipe.doubleDoor) {
    _draw(building, _cell((wall + 2, 7)), 0, _tile);
    _draw(building, _cell((wall + 3, 7)), _tile, _tile);
  } else if (recipe.sign case final sign?) {
    _draw(building, _cell((wall, 6)), 0, _tile);
    _draw(building, _cell(sign), 0, _tile);
    _draw(building, _cell((wall + 1, 7)), _tile, _tile);
  } else {
    _draw(building, _cell((wall, 7)), 0, _tile);
    _draw(building, _cell((wall + 1, 7)), _tile, _tile);
  }
  return building;
}

/// Four corner tiles of a 3x3 Tiny Town ring (dirt patch, fence) as a 2x2.
img.Image _ring(Cell topLeft) {
  final ring = img.Image(width: _tile * 2, height: _tile * 2, numChannels: 4);
  final (column, row) = topLeft;
  _draw(ring, _cell((column, row)), 0, 0);
  _draw(ring, _cell((column + 2, row)), _tile, 0);
  _draw(ring, _cell((column, row + 2)), 0, _tile);
  _draw(ring, _cell((column + 2, row + 2)), _tile, _tile);
  return ring;
}

/// A locked plot: a fenced lot with a notice board.
img.Image _lockedPlot() {
  final plot = _ring((8, 3));
  _draw(plot, _cell((11, 6)), 8, 8);
  return plot;
}

/// A plot being built on: the fenced lot with a hammer at work. Drawn over
/// the building, which shows through the middle.
img.Image _buildingSite() {
  final site = _ring((8, 3));
  _draw(site, _cell(_hammer), 8, 8);
  return site;
}

/// The Arcane Well: Tiny Town's two-tile well, centred.
img.Image _well() {
  final well = img.Image(width: _tile * 2, height: _tile * 2, numChannels: 4);
  _draw(well, _cell((8, 7)), 8, 0);
  _draw(well, _cell((8, 8)), 8, _tile);
  return well;
}

/// Still water with a few lighter ripples.
img.Image _water() {
  final water = img.Image(width: _tile, height: _tile, numChannels: 4);
  img.fill(water, color: img.ColorRgba8(0x4F, 0x8F, 0xD6, 0xFF));
  final ripple = img.ColorRgba8(0x8C, 0xBF, 0xF0, 0xFF);
  for (final (x, y, length) in [(2, 4, 4), (9, 10, 5), (4, 13, 3)]) {
    for (var step = 0; step < length; step++) {
      water.setPixel(x + step, y, ripple);
    }
  }
  return water;
}

void main() {
  _source = img.decodePng(File(_sourceSheet).readAsBytesSync())!.convert(numChannels: 4);

  final sprites = <String, img.Image>{
    for (final MapEntry(key: name, value: recipe) in _buildings.entries)
      'building.$name': _building(recipe),
    'building.arcane_well': _well(),
    'town.house.default.idle': _building(_house),
    'town.plot.locked.idle': _lockedPlot(),
    'town.scaffold.default.idle': _buildingSite(),
    'town.plot.empty.idle': _ring((0, 1)),
  };

  const columns = 8;
  final rows = (sprites.length / columns).ceil();
  final sheet = img.Image(
    width: columns * _tile * 2,
    height: rows * _tile * 2 + _tile,
    numChannels: 4,
  );
  final regions = <String, List<int>>{};
  var index = 0;
  for (final MapEntry(key: key, value: sprite) in sprites.entries) {
    final column = (index % columns) * 2, row = (index ~/ columns) * 2;
    _draw(sheet, sprite, column * _tile, row * _tile);
    if (key.startsWith('building.')) {
      // The bundled art has one look per building; every tier shares it.
      for (var tier = 1; tier <= 5; tier++) {
        regions['$key.t$tier.idle'] = [column, row, 2, 2];
      }
    } else {
      regions[key] = [column, row, 2, 2];
    }
    index++;
  }
  _draw(sheet, _water(), 0, rows * _tile * 2);
  regions['town.ground.water.idle'] = [0, rows * 2];

  Directory(_outputFolder).createSync(recursive: true);
  File('$_outputFolder/tilemap_packed.png').writeAsBytesSync(img.encodePng(sheet));
  File('$_outputFolder/regions.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'sheet': 'tilemap_packed.png',
      'cellSize': _tile,
      'spacing': 0,
      'regions': regions,
    })}\n',
  );
  File('$_outputFolder/License.txt').writeAsStringSync(
    'Composed from Kenney "Tiny Town" tiles (www.kenney.nl), '
    'Creative Commons Zero (CC0).\n'
    'See ../tiny_town/License.txt. Regenerate with '
    'tool/compose_town_buildings.dart.\n',
  );
  stdout.writeln('Wrote ${sprites.length} sprites to $_outputFolder');
}
