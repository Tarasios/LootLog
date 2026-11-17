/// Composes the town's buildings from the Kenney Tiny Town, Tiny Farm and
/// Tiny Dungeon tiles (all CC0).
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
/// and its barn come from Tiny Farm (`tool/town_farm_art.dart`); the civic
/// quarters' buildings and plots from `tool/town_civic_art.dart`; their
/// scenery, Castle Hill and the Castle's stages from
/// `tool/town_quarter_art.dart`. This writes
/// `assets/game/packs/town_composed/` (the sheet and its `regions.json`);
/// rerun it after changing a recipe:
///
///     dart run tool/compose_town_buildings.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

import 'town_civic_art.dart';
import 'town_farm_art.dart';
import 'town_house_art.dart';
import 'town_quarter_art.dart';

const String _outputFolder = 'assets/game/packs/town_composed';

const Map<String, Recipe> _buildings = {
  'central_hall': Recipe(redRoof, stoneWall, doubleDoor: true),
  'scribes_desk': Recipe(blueRoof, brickWall),
  'storehouse': Recipe(blueRoof, brickWall, doubleDoor: true),
  'forge': Recipe(redRoof, stoneWall, sign: hammer),
  'vault': Recipe(blueRoof, stoneWall, sign: keySign),
  'lumberyard': Recipe(redRoof, brickWall, sign: axe),
  'quarry': Recipe(redRoof, stoneWall, sign: pickaxe),
  'mine': Recipe(blueRoof, stoneWall, sign: bucket),
  'herb_garden': Recipe(redRoof, brickWall, sign: pitchfork),
  'hunters_lodge': Recipe(blueRoof, brickWall, sign: bowSign),
};

const Recipe _house = Recipe(redRoof, brickWall);

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
  draw(site, townCell(hammer), 8, 8);
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
    tiers('building.$name', (tier) => tier < 3 ? squatBuilding(recipe) : tallBuilding(recipe, tier));
  }
  tiers('building.arcane_well', _well);
  for (final farmBuilding in farmBuildingNames) {
    tiers('building.$farmBuilding', (tier) => farmBuildingLook(farmBuilding, tier), everyTierOwnLook: true);
  }
  for (final civicBuilding in civicBuildingNames) {
    tiers('building.$civicBuilding', (tier) => civicBuildingLook(civicBuilding, tier), everyTierOwnLook: true);
  }
  sprites.addAll({
    'town.house.default.idle': squatBuilding(_house),
    'town.plot.locked.idle': _lockedPlot(),
    'town.scaffold.default.idle': _buildingSite(),
    'town.plot.empty.idle': _ring((0, 1)),
    'farm.plot.empty.idle': emptyField(),
    'farm.barn.default.idle': barn(),
    'town.ground.water.idle': _water(),
    'farm.resting.sign.idle': restingSign(),
    ...civicPlots(),
    ...quarterSprites(),
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
    'Composed from Kenney "Tiny Town", "Tiny Farm" and "Tiny Dungeon" tiles '
    '(www.kenney.nl), Creative Commons Zero (CC0), with a few hand-drawn '
    'pixels in their palette.\n'
    'See ../tiny_town/License.txt, ../tiny_farm/License.txt and '
    '../tiny_dungeon/License.txt. Regenerate with '
    'tool/compose_town_buildings.dart.\n',
  );
  stdout.writeln('Wrote ${packed.regions.length} regions to $_outputFolder');
}
