/// The civic quarters' buildings at each tier, composed from Kenney "Tiny
/// Town", "Tiny Farm" and "Tiny Dungeon" tiles (all CC0) with a few
/// hand-drawn pixels in Tiny Town's palette (awnings, water, a bandstand's
/// boards). Like the hall buildings they stand 2×2 at tiers 1–2 and rise to
/// 2×3 from tier 3, tier 5 flying a pennant. Also the quarters' empty plots
/// and the farmland's "resting" sign.
library;

import 'package:image/image.dart' as img;

import 'town_farm_art.dart';
import 'town_house_art.dart';

/// The civic buildings' art keys (`building.<name>.t<tier>.idle`).
const List<String> civicBuildingNames = [
  'watchtower', 'barracks', 'wall_section', 'cottage', 'rowhouse', 'well',
  'garden', 'bandstand', 'fountain', 'stall', 'workshop', 'guild_hall',
];

/// Tiny Town's castle stone: wall-top battlements (left end, middle, right
/// end), plain brick, brick with a window, an open arch's two halves.
const Cell battlementLeft = (3, 8), battlementMiddle = (4, 8), battlementRight = (5, 8);
const Cell brick = (6, 10), brickWindow = (5, 10), archLeft = (5, 9), archRight = (6, 9);

/// Tiny Dungeon: a wall torch, an anvil, a sword, a knight.
const Cell torch = (5, 2), anvil = (2, 6), sword = (8, 8);

/// [name]'s look at [tier].
img.Image civicBuildingLook(String name, int tier) => switch (name) {
      'watchtower' => _watchtower(tier),
      'barracks' => _house(Recipe(redRoof, stoneWall, doubleDoor: true), tier, banner: true),
      'wall_section' => _wallSection(tier),
      'cottage' => _house(const Recipe(blueRoof, brickWall), tier, flowers: true),
      'rowhouse' => _rowhouse(tier),
      'well' => _well(tier),
      'garden' => _garden(tier),
      'bandstand' => _bandstand(tier),
      'fountain' => _fountain(tier),
      'stall' => _stall(tier),
      'workshop' => _house(Recipe(blueRoof, brickWall, signArt: () => dungeonCell(anvil)), tier),
      _ => _house(Recipe(blueRoof, stoneWall, doubleDoor: true), tier, banner: true, torches: true),
    };

/// Rows of art for [tier]: 2 at tiers 1–2, 3 from tier 3.
int _rows(int tier) => tier < 3 ? 2 : 3;

/// A house-shaped building, with flowers by its door, a banner over a
/// double door, or torches either side.
img.Image _house(Recipe recipe, int tier, {bool flowers = false, bool banner = false, bool torches = false}) {
  final building = tier < 3 ? squatBuilding(recipe) : tallBuilding(recipe, tier);
  final wallY = building.height - tile;
  if (flowers && tier >= 2) _flowerBox(building, 2, wallY + 11);
  if (banner) _banner(building, 13, wallY - 3, tier >= 4 ? yellow : red);
  if (torches && tier >= 2) {
    draw(building, img.copyCrop(dungeonCell(torch), x: 4, y: 0, width: 8, height: 12), -2, wallY);
    draw(building, img.copyCrop(dungeonCell(torch), x: 4, y: 0, width: 8, height: 12), 2 * tile - 6, wallY);
  }
  return building;
}

/// A little window box of flowers.
void _flowerBox(img.Image target, int x, int y) {
  fillRect(target, x, y, 10, 4, outline);
  fillRect(target, x + 1, y + 1, 8, 2, woodMid);
  for (final (dx, colour) in [(1, pink), (3, yellow), (5, pink), (7, white)]) {
    fillRect(target, x + dx, y - 2, 2, 2, colour);
  }
}

/// A hanging banner, its point at the bottom.
void _banner(img.Image target, int x, int y, img.Color colour) {
  fillRect(target, x - 1, y - 1, 8, 1, outline);
  for (var row = 0; row < 9; row++) {
    final inset = row < 6 ? 0 : row - 5;
    fillRect(target, x + inset, y + row, 6 - 2 * inset, 1, row < 6 ? colour : outline);
  }
  fillRect(target, x, y, 1, 6, outline);
  fillRect(target, x + 5, y, 1, 6, outline);
  fillRect(target, x + 2, y + 2, 2, 2, yellow);
}

/// Two castle-stone cells side by side: [left] and [right] at row [y]. An
/// open arch is shaded inside, a window in the wall.
void _stonePair(img.Image target, Cell left, Cell right, int y) {
  draw(target, townCell(left), 0, y);
  draw(target, townCell(right), tile, y);
  if (left == archLeft) shadeOpening(target, y);
}

/// Fills the transparent opening of an arch drawn on row [y] with shadow.
void shadeOpening(img.Image target, int y, {int x = 0, int width = 2 * tile}) {
  final shadow = img.ColorRgba8(38, 43, 68, 255);
  for (var row = y + 4; row < y + tile; row++) {
    for (var column = x + 3; column < x + width - 3; column++) {
      if (target.getPixel(column, row).a == 0) target.setPixel(column, row, shadow);
    }
  }
}

/// A stone tower: battlements over brick, an arrow-slit from tier 2, an
/// arched lookout from tier 3, a torch from tier 4.
img.Image _watchtower(int tier) {
  final rows = _rows(tier);
  final tower = blank(2, rows);
  _stonePair(tower, battlementLeft, battlementRight, 0);
  if (tier >= 3) _stonePair(tower, archLeft, archRight, tile);
  _stonePair(tower, tier >= 2 ? brickWindow : brick, brick, (rows - 1) * tile);
  _door(tower, 18, (rows - 1) * tile + 4);
  if (tier >= 4) draw(tower, img.copyCrop(dungeonCell(torch), x: 4, y: 0, width: 8, height: 12), 12, tile + 2);
  if (tier >= 5) drawPennant(tower, x: 3);
  return tower;
}

/// A wooden door 8 × 12 with its top-left at ([x], [y]).
void _door(img.Image target, int x, int y) {
  fillRect(target, x, y, 8, 12, outline);
  fillRect(target, x + 1, y + 1, 6, 11, woodMid);
  fillRect(target, x + 2, y + 2, 4, 1, woodDark);
  fillRect(target, x + 5, y + 6, 1, 1, yellow);
}

/// A stretch of wall: battlements over brick, a window from tier 2, an
/// arch from tier 3, a torch from tier 4.
img.Image _wallSection(int tier) {
  final rows = _rows(tier);
  final wall = blank(2, rows);
  _stonePair(wall, battlementLeft, battlementMiddle, 0);
  draw(wall, townCell(battlementRight), tile, 0);
  if (tier >= 3) _stonePair(wall, archLeft, archRight, tile);
  _stonePair(wall, brick, tier >= 2 ? brickWindow : brick, (rows - 1) * tile);
  if (tier >= 4) draw(wall, img.copyCrop(dungeonCell(torch), x: 4, y: 0, width: 8, height: 12), 0, (rows - 1) * tile);
  if (tier >= 5) drawPennant(wall, x: 3);
  return wall;
}

/// Homes in a row: two front doors under one roof.
img.Image _rowhouse(int tier) {
  final rows = _rows(tier);
  final house = blank(2, rows);
  if (tier < 3) {
    drawSquatRoof(house, redRoof, 0);
  } else {
    drawTallRoof(house, redRoof, dormer: tier >= 4);
  }
  final wallY = (rows - 1) * tile;
  draw(house, townCell((brickWall + 1, 7)), 0, wallY);
  draw(house, townCell((brickWall + 3, 7)), tile, wallY);
  if (tier >= 2) _flowerBox(house, 11, wallY + 12);
  if (tier >= 5) drawPennant(house, x: 4);
  return house;
}

/// Four flagstones under [target]'s bottom two rows.
void _flagstones(img.Image target) {
  final top = target.height - 2 * tile;
  for (final (x, y) in [(0, 0), (tile, 0), (0, tile), (tile, tile)]) {
    draw(target, townCell((7, 3)), x, top + y);
  }
}

/// The quarter's well: Tiny Town's well on flagstones, a bucket from tier
/// 2, a shingle canopy from tier 3, flowers from tier 4.
img.Image _well(int tier) {
  final rows = _rows(tier);
  final well = blank(2, rows);
  _flagstones(well);
  final top = (rows - 2) * tile;
  if (tier >= 3) {
    drawSquatRoof(well, redRoof, 0);
    fillRect(well, 4, 14, 2, tile + 4, outline);
    fillRect(well, 26, 14, 2, tile + 4, outline);
  }
  draw(well, townCell((8, 7)), 8, top);
  draw(well, townCell((8, 8)), 8, top + tile);
  if (tier >= 2) draw(well, img.copyCrop(townCell(bucket), x: 2, y: 4, width: 12, height: 12), 20, top + tile + 4);
  if (tier >= 4) _flowerBox(well, 0, top + 2 * tile - 3);
  if (tier >= 5) drawPennant(well, x: 1);
  return well;
}

/// Flower beds on the lawn, a bush from tier 2, a tree from tier 3, a lamp
/// from tier 4.
img.Image _garden(int tier) {
  final rows = _rows(tier);
  final garden = blank(2, rows);
  final top = (rows - 2) * tile;
  for (final (x, y) in [(0, 0), (tile, 0), (0, tile), (tile, tile)]) {
    draw(garden, townCell((2, 0)), x, top + y);
  }
  if (tier >= 2) draw(garden, townCell((5, 0)), tile, top + tile);
  if (tier >= 3) {
    draw(garden, townCell((4, 0)), 0, 0);
    draw(garden, townCell((4, 1)), 0, tile);
  }
  if (tier >= 4) draw(garden, farmCell((11, 6)), tile, top);
  if (tier >= 5) drawPennant(garden, x: 18);
  return garden;
}

/// Boards on posts under a canopy: a squat roof to tier 2, a full roof
/// from tier 3, bunting from tier 2.
img.Image _bandstand(int tier) {
  final rows = _rows(tier);
  final stand = blank(2, rows);
  final floorY = (rows - 1) * tile;
  fillRect(stand, 1, floorY + 6, 30, 10, outline);
  fillRect(stand, 2, floorY + 7, 28, 7, woodLight);
  for (var x = 6; x < 30; x += 6) {
    fillRect(stand, x, floorY + 7, 1, 7, woodMid);
  }
  for (final x in [3, 27]) {
    fillRect(stand, x, floorY - 2, 2, 9, outline);
  }
  if (tier < 3) {
    drawSquatRoof(stand, redRoof, 0);
  } else {
    drawTallRoof(stand, redRoof, dormer: tier >= 4);
  }
  if (tier >= 2) {
    for (var x = 4; x < 28; x += 4) {
      fillRect(stand, x, floorY + 1, 3, 2, x % 8 == 0 ? yellow : brightRed);
    }
  }
  if (tier >= 5) drawPennant(stand, x: 4);
  return stand;
}

/// A stone basin with a pedestal and a bowl that spills water: from tier 3
/// the pedestal rises into the row above, tier 4 adds a second bowl.
img.Image _fountain(int tier) {
  final rows = _rows(tier);
  final fountain = blank(2, rows);
  final top = (rows - 2) * tile;
  for (final (x, y, cell) in [(0, 0, (0, 8)), (tile, 0, (2, 8)), (0, tile, (0, 10)), (tile, tile, (2, 10))]) {
    draw(fountain, townCell(cell), x, top + y);
  }
  fillRect(fountain, 5, top + 5, 22, 22, blue);
  fillRect(fountain, 7, top + 8, 5, 1, paleBlue);
  fillRect(fountain, 19, top + 22, 5, 1, paleBlue);
  final bowlY = tier >= 3 ? 10 : top + 7 - (tier == 2 ? 2 : 0);
  _pedestal(fountain, bowlY, top + 18);
  _bowl(fountain, bowlY, tier >= 2 ? 14 : 10);
  if (tier >= 4) {
    _pedestal(fountain, 3, bowlY);
    _bowl(fountain, 3, 8);
  }
  if (tier >= 5) drawPennant(fountain, x: 1);
  return fountain;
}

/// A stone pedestal under the fountain's bowl, from [top] down to [bottom].
void _pedestal(img.Image target, int top, int bottom) {
  fillRect(target, 13, top, 6, bottom - top, outline);
  fillRect(target, 14, top, 4, bottom - top - 1, stoneLight);
  fillRect(target, 16, top, 1, bottom - top - 1, stoneMid);
}

/// A bowl [width] wide at [y], brimming, its water spilling to both sides.
void _bowl(img.Image target, int y, int width) {
  final left = 16 - width ~/ 2;
  fillRect(target, left, y, width, 4, outline);
  fillRect(target, left + 1, y + 1, width - 2, 2, stoneLight);
  fillRect(target, left + 1, y, width - 2, 1, paleBlue);
  for (var step = 0; step < 5; step++) {
    target.setPixel(left - 1 - step ~/ 2, y + 2 + step, paleBlue);
    target.setPixel(left + width + step ~/ 2, y + 2 + step, paleBlue);
  }
}

/// A striped awning [width] px wide, [height] px deep, at ([x], [y]).
void awning(img.Image target, int x, int y, int width, img.Color colour, {int height = 10}) {
  fillRect(target, x, y, width, height, outline);
  for (var column = 1; column < width - 1; column++) {
    final stripe = ((column - 1) ~/ 4).isEven ? colour : white;
    fillRect(target, x + column, y + 1, 1, height - 3, stripe);
    // A scalloped edge: every other stripe hangs a pixel lower.
    if (((column - 1) ~/ 4).isEven) target.setPixel(x + column, y + height - 2, colour);
  }
}

/// A market stall: an awning on posts over crates of produce; from tier 3
/// a shopfront with the awning over its window.
img.Image _stall(int tier) {
  if (tier >= 3) {
    final shop = tallBuilding(const Recipe(redRoof, brickWall), tier);
    awning(shop, 0, 2 * tile - 2, 2 * tile, brightRed, height: 8);
    draw(shop, farmCell((11, 3)), tile, 2 * tile + 4);
    return shop;
  }
  final stall = blank(2, 2);
  for (final x in [1, 29]) {
    fillRect(stall, x, 6, 2, 22, outline);
  }
  draw(stall, farmCell((11, 3)), 0, tile);
  draw(stall, farmCell(tier >= 2 ? (11, 0) : (9, 0)), tile, tile);
  awning(stall, 0, 2, 2 * tile, brightRed);
  return stall;
}

/// The empty plot of each civic quarter, by district art name.
Map<String, img.Image> civicPlots() => {
      'plot.guard_post.empty.idle': _ring4((0, 8), (2, 8), (0, 10), (2, 10)),
      'plot.residential.empty.idle': _ring4((0, 1), (2, 1), (0, 3), (2, 3)),
      'plot.park.empty.idle': _lawnPlot(),
      'plot.market_row.empty.idle': _ring4((7, 3), (7, 3), (7, 3), (7, 3)),
    };

img.Image _ring4(Cell topLeft, Cell topRight, Cell bottomLeft, Cell bottomRight) {
  final plot = blank(2, 2);
  draw(plot, townCell(topLeft), 0, 0);
  draw(plot, townCell(topRight), tile, 0);
  draw(plot, townCell(bottomLeft), 0, tile);
  draw(plot, townCell(bottomRight), tile, tile);
  return plot;
}

/// Mown lawn ringed by flowers.
img.Image _lawnPlot() {
  final plot = blank(2, 2);
  fillRect(plot, 0, 0, 32, 32, grassLight);
  for (var step = 0; step < 32; step += 4) {
    for (final (x, y) in [(step, 0), (step, 30), (0, step), (30, step)]) {
      fillRect(plot, x, y, 2, 2, step % 8 == 0 ? pink : yellow);
    }
  }
  return plot;
}

/// The farmland's "resting" sign: a pale sleep bubble, never a warning.
img.Image restingSign() {
  final sign = blank(1, 1);
  fillRect(sign, 1, 1, 14, 11, outline);
  fillRect(sign, 2, 2, 12, 9, white);
  fillRect(sign, 3, 12, 3, 2, outline);
  fillRect(sign, 4, 12, 1, 1, white);
  // "Z z": a big Z and a small one.
  for (final (x, y, size) in [(3, 3, 5), (9, 6, 3)]) {
    fillRect(sign, x, y, size, 1, blue);
    fillRect(sign, x, y + size - 1, size, 1, blue);
    for (var step = 1; step < size - 1; step++) {
      sign.setPixel(x + size - 1 - step, y + step, blue);
    }
  }
  return sign;
}
