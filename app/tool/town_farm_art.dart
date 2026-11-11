/// The shared drawing helpers of `compose_town_buildings.dart` and the
/// farmland's art: the farm, orchard and granary at each tier, the empty
/// field plot and the barn, all from Kenney "Tiny Farm" (CC0) with a few
/// Tiny Town tiles. Also packs the composed sprites onto one sheet.
library;

import 'dart:io';

import 'package:image/image.dart' as img;

const int tile = 16;
const String _townSheet = 'assets/game/packs/tiny_town/tilemap_packed.png';
const String _farmSheet = 'assets/game/packs/tiny_farm/tilemap_packed.png';

/// A sheet cell, as (column, row).
typedef Cell = (int, int);

late img.Image _town;
late img.Image _farm;

/// Reads the Tiny Town and Tiny Farm sheets.
void loadSourceSheets() {
  _town = img.decodePng(File(_townSheet).readAsBytesSync())!.convert(numChannels: 4);
  _farm = img.decodePng(File(_farmSheet).readAsBytesSync())!.convert(numChannels: 4);
}

img.Image _crop(img.Image sheet, Cell cell) =>
    img.copyCrop(sheet, x: cell.$1 * tile, y: cell.$2 * tile, width: tile, height: tile);

img.Image townCell(Cell cell) => _crop(_town, cell);
img.Image farmCell(Cell cell) => _crop(_farm, cell);

/// A transparent image [columns] × [rows] cells.
img.Image blank(int columns, int rows) =>
    img.Image(width: columns * tile, height: rows * tile, numChannels: 4);

void draw(img.Image target, img.Image source, int x, int y) =>
    img.compositeImage(target, source, dstX: x, dstY: y);

/// A red pennant on a dark pole, planted at [x] on the top row: the
/// tier-5 mark.
void drawPennant(img.Image target, {required int x}) {
  final pole = img.ColorRgba8(0x44, 0x24, 0x34, 0xFF);
  final cloth = img.ColorRgba8(0xD0, 0x46, 0x48, 0xFF);
  final shade = img.ColorRgba8(0x85, 0x4C, 0x30, 0xFF);
  final trim = img.ColorRgba8(0xDA, 0xD4, 0x5E, 0xFF);
  for (var y = 0; y < 13; y++) {
    target.setPixel(x, y, pole);
    target.setPixel(x + 1, y, pole);
  }
  for (var row = 0; row < 7; row++) {
    final length = 8 - (row - 3).abs() * 2;
    for (var column = 0; column < length; column++) {
      final edge = row == 0 || row == 6 || column == length - 1;
      target.setPixel(x + 2 + column, 1 + row, edge ? shade : (row == 3 ? trim : cloth));
    }
  }
}

// ---- Farmland ---------------------------------------------------------------

/// The farm buildings' art keys (`building.<name>.t<tier>.idle`).
const List<String> farmBuildingNames = ['farm', 'orchard', 'granary'];

const Cell _bedTop = (0, 1), _bedMiddle = (0, 2), _bedBottom = (0, 3);
const Cell _sprout = (4, 5), _youngWheat = (5, 5), _wheat = (6, 5);
const Cell _carrot = (6, 0), _cabbage = (6, 4), _berryBush = (6, 6);
const Cell _hay = (0, 8), _tomatoCrate = (11, 3), _cornCrate = (11, 2);
const Cell _barnDoor = (7, 10), _barnWindow = (8, 10), _barnGable = (6, 7);

/// [name]'s look at [tier]: 2×2 cells at tiers 1–2, 2×3 from tier 3.
img.Image farmBuildingLook(String name, int tier) => switch (name) {
      'farm' => _farmLook(tier),
      'orchard' => _orchardLook(tier),
      _ => _granaryLook(tier),
    };

/// Two tilled beds (three rows tall from tier 3) with a crop on each tile:
/// sprouts, then young wheat, then ripe wheat with carrots and cabbages.
img.Image _farmLook(int tier) {
  final rows = tier < 3 ? 2 : 3;
  final farm = blank(2, rows);
  for (var column = 0; column < 2; column++) {
    for (var row = 0; row < rows; row++) {
      final bed = row == 0 ? _bedTop : (row == rows - 1 ? _bedBottom : _bedMiddle);
      draw(farm, farmCell((bed.$1 + column, bed.$2)), column * tile, row * tile);
      final crop = switch (tier) {
        1 => _sprout,
        2 => _youngWheat,
        3 => _wheat,
        _ => [_wheat, _carrot, _cabbage][row],
      };
      draw(farm, farmCell(crop), column * tile, row * tile);
    }
  }
  if (tier >= 4) draw(farm, farmCell(_hay), tile, 0);
  if (tier >= 5) drawPennant(farm, x: 3);
  return farm;
}

/// Berry bushes, then fruit trees over the bushes from tier 3, with a crate
/// of the harvest from tier 4.
img.Image _orchardLook(int tier) {
  if (tier < 3) {
    final orchard = blank(2, 2);
    for (final (x, y) in tier == 1 ? [(0, tile), (tile, tile)] : [(0, 0), (tile, 0), (0, tile), (tile, tile)]) {
      draw(orchard, farmCell(_berryBush), x, y);
    }
    return orchard;
  }
  final orchard = blank(2, 3);
  for (final x in [0, tile]) {
    // Tiny Town's tall green tree, its fruit picked out in red.
    draw(orchard, townCell((4, 0)), x, 0);
    draw(orchard, townCell((4, 1)), x, tile);
    _dotFruit(orchard, x, 0);
    draw(orchard, farmCell(_berryBush), x, 2 * tile);
  }
  if (tier >= 4) draw(orchard, farmCell(tier.isEven ? _tomatoCrate : _cornCrate), tile, 2 * tile);
  if (tier >= 5) drawPennant(orchard, x: 1);
  return orchard;
}

/// Red fruit on the tree whose crown starts at ([x], [y]).
void _dotFruit(img.Image target, int x, int y) {
  final fruit = img.ColorRgba8(0xD0, 0x46, 0x48, 0xFF);
  for (final (dx, dy) in [(5, 6), (10, 9), (6, 13), (9, 18), (4, 21)]) {
    target
      ..setPixel(x + dx, y + dy, fruit)
      ..setPixel(x + dx + 1, y + dy, fruit);
  }
}

/// A red barn-plank granary: a squat Tiny Town roof at tiers 1–2, a full
/// roof from tier 3 (the barn's crossed gable in its upper row from tier 4),
/// hay by the door from tier 2.
img.Image _granaryLook(int tier) {
  final rows = tier < 3 ? 2 : 3;
  final granary = blank(2, rows);
  if (tier < 3) {
    for (final (offset, column) in [(0, 4), (tile, 6)]) {
      final ridge = img.copyCrop(townCell((column, 4)), x: 0, y: 0, width: tile, height: 8);
      final eave = img.copyCrop(townCell((column, 5)), x: 0, y: 8, width: tile, height: 8);
      draw(granary, ridge, offset, 0);
      draw(granary, eave, offset, 8);
    }
  } else {
    draw(granary, townCell((4, 4)), 0, 0);
    draw(granary, townCell(tier >= 4 ? (7, 4) : (6, 4)), tile, 0);
    draw(granary, townCell((4, 5)), 0, tile);
    draw(granary, townCell((6, 5)), tile, tile);
    if (tier >= 4) draw(granary, farmCell(_barnGable), 8, tile);
  }
  final wallY = (rows - 1) * tile;
  draw(granary, farmCell(_barnDoor), 0, wallY);
  draw(granary, farmCell(_barnWindow), tile, wallY);
  if (tier >= 2) draw(granary, farmCell(_hay), tile, wallY);
  if (tier >= 5) drawPennant(granary, x: 3);
  return granary;
}

/// An empty farmland plot: two freshly tilled beds, nothing planted yet.
img.Image emptyField() {
  final field = blank(2, 2);
  draw(field, farmCell(_bedTop), 0, 0);
  draw(field, farmCell((1, 1)), tile, 0);
  draw(field, farmCell(_bedBottom), 0, tile);
  draw(field, farmCell((1, 3)), tile, tile);
  return field;
}

/// The farmland's barn (3 × 6 cells): Tiny Farm's green roof, its notch
/// showing the red crossed gable, over the barn's doors.
img.Image barn() {
  final barn = blank(3, 6);
  for (var column = 0; column < 3; column++) {
    final x = column * tile;
    draw(barn, farmCell((6 + column, 9)), x, 4 * tile);
    draw(barn, farmCell((6 + column, 7)), x, 4 * tile - 8);
    // The roof's top row holds other sprites beside its peak.
    for (var row = column == 1 ? 0 : 1; row < 5; row++) {
      draw(barn, farmCell((9 + column, 6 + row)), x, row * tile);
    }
    draw(barn, farmCell((6 + column, 10)), x, 5 * tile);
  }
  return barn;
}

// ---- Packing ----------------------------------------------------------------

/// [sprites] packed in shelves [columns] cells wide. Keys whose image is the
/// same object share one region.
({img.Image sheet, Map<String, List<int>> regions}) packSheet(
  Map<String, img.Image> sprites, {
  required int columns,
}) {
  final placed = Map<img.Image, List<int>>.identity();
  var x = 0, y = 0, shelfHeight = 0;
  for (final sprite in sprites.values) {
    if (placed.containsKey(sprite)) continue;
    final width = sprite.width ~/ tile, height = sprite.height ~/ tile;
    if (x + width > columns) {
      x = 0;
      y += shelfHeight;
      shelfHeight = 0;
    }
    placed[sprite] = [x, y, width, height];
    x += width;
    if (height > shelfHeight) shelfHeight = height;
  }
  final sheet = blank(columns, y + shelfHeight);
  for (final MapEntry(key: sprite, value: region) in placed.entries) {
    draw(sheet, sprite, region[0] * tile, region[1] * tile);
  }
  return (
    sheet: sheet,
    regions: {
      for (final MapEntry(:key, :value) in sprites.entries)
        key: value.width == tile && value.height == tile ? [placed[value]![0], placed[value]![1]] : placed[value]!,
    },
  );
}
