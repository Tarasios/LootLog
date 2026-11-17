/// The scenery of the civic quarters and Castle Hill, composed from Kenney
/// "Tiny Town", "Tiny Farm" and "Tiny Dungeon" tiles (all CC0) with a few
/// hand-drawn pixels in Tiny Town's palette: the Guard Post's walls, towers,
/// gate and weapon racks; the Residential Quarter's vegetable garden; the
/// Park's flowerbeds, lamps and benches; Market Row's awning stalls; and
/// Castle Hill's hill and the Castle at each of its stages (0 is the
/// surveyed hilltop, 5 the finished Castle flying its banners).
library;

import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'town_civic_art.dart';
import 'town_farm_art.dart';

/// Every landmark sprite by region key.
Map<String, img.Image> quarterSprites() => {
      'guard.wall.default.idle': _wallTile(),
      'guard.tower.default.idle': _towerTop(),
      'guard.gate.default.idle': _gateArch(),
      'guard.rack.default.idle': _weaponRack(),
      'residential.garden.default.idle': _vegetableGarden(),
      'park.flowerbed.default.idle': _flowerbed(),
      'park.lamp.default.idle': _lamp(),
      'park.bench.default.idle': _bench(),
      'market.stall.red.idle': _marketStall(brightRed),
      'market.stall.blue.idle': _marketStall(blue),
      'market.stall.green.idle': _marketStall(grassDark),
      'castle.hill.default.idle': _hill(),
      for (var stage = 0; stage <= 5; stage++) 'castle.stage.s$stage.idle': castleStage(stage),
      'castle.scaffold.default.idle': _castleScaffold(),
    };

/// One cell of wall seen from the front: battlements over brick.
img.Image _wallTile() {
  final wall = blank(1, 1);
  draw(wall, img.copyCrop(townCell(battlementMiddle), x: 0, y: 0, width: tile, height: 9), 0, 0);
  draw(wall, img.copyCrop(townCell(brick), x: 0, y: 9, width: tile, height: 7), 0, 9);
  return wall;
}

/// A corner tower's crenellated top: the corners of Tiny Town's stone
/// platform.
img.Image _towerTop() {
  final tower = blank(2, 2);
  for (final (x, y, cell) in [(0, 0, (0, 8)), (tile, 0, (2, 8)), (0, tile, (0, 10)), (tile, tile, (2, 10))]) {
    draw(tower, townCell(cell), x, y);
  }
  fillRect(tower, 12, 12, 8, 8, stoneMid);
  fillRect(tower, 14, 14, 4, 4, stoneDark);
  return tower;
}

/// An open arch over the lane: the arch's top and two brick piers, clear
/// in the middle so the road runs through.
img.Image _gateArch() {
  final gate = blank(2, 2);
  draw(gate, townCell(archLeft), 0, 0);
  draw(gate, townCell(archRight), tile, 0);
  draw(gate, img.copyCrop(townCell(brick), x: 0, y: 0, width: 6, height: tile), 0, tile);
  draw(gate, img.copyCrop(townCell(brick), x: 10, y: 0, width: 6, height: tile), 26, tile);
  fillRect(gate, 5, tile, 1, tile, outline);
  fillRect(gate, 26, tile, 1, tile, outline);
  return gate;
}

/// A rack of practice weapons.
img.Image _weaponRack() {
  final rack = blank(1, 1);
  fillRect(rack, 1, 3, 14, 2, outline);
  fillRect(rack, 1, 12, 14, 2, outline);
  fillRect(rack, 2, 3, 2, 12, outline);
  fillRect(rack, 12, 3, 2, 12, outline);
  fillRect(rack, 2, 4, 12, 1, woodMid);
  fillRect(rack, 2, 12, 12, 1, woodMid);
  draw(rack, img.copyCrop(dungeonCell(sword), x: 4, y: 1, width: 8, height: 14), 4, 1);
  return rack;
}

/// Two long vegetable beds: cabbages, carrots and corn.
img.Image _vegetableGarden() {
  final garden = blank(4, 2);
  for (var column = 0; column < 4; column++) {
    draw(garden, farmCell((column, 4)), column * tile, 0);
    draw(garden, farmCell((column, 5)), column * tile, tile);
    draw(garden, farmCell(column.isEven ? (6, 4) : (5, 2)), column * tile, 0);
    draw(garden, farmCell(column.isEven ? (6, 0) : (4, 4)), column * tile, tile);
  }
  return garden;
}

/// A raised bed of flowers, one cell wide and two tall.
img.Image _flowerbed() {
  final bed = blank(1, 2);
  draw(bed, farmCell((0, 1)), 0, 0);
  draw(bed, farmCell((0, 3)), 0, tile);
  final colours = [pink, yellow, white, brightRed];
  for (var row = 0; row < 7; row++) {
    for (final column in [5, 9]) {
      fillRect(bed, column + (row.isEven ? 0 : 1), 3 + row * 4, 2, 2, colours[(row + column) % colours.length]);
    }
  }
  return bed;
}

/// A lamp post: Tiny Town's lantern on a dark pole.
img.Image _lamp() {
  final lamp = blank(1, 1);
  fillRect(lamp, 7, 6, 2, 10, outline);
  fillRect(lamp, 5, 14, 6, 2, outline);
  draw(lamp, img.copyCrop(townCell((9, 7)), x: 3, y: 2, width: 10, height: 11), 3, -1);
  return lamp;
}

/// A park bench seen from the front: backrest, seat and legs.
img.Image _bench() {
  final bench = blank(1, 1);
  fillRect(bench, 1, 4, 14, 5, outline);
  fillRect(bench, 2, 5, 12, 3, woodLight);
  fillRect(bench, 2, 6, 12, 1, woodMid);
  fillRect(bench, 0, 9, 16, 4, outline);
  fillRect(bench, 1, 10, 14, 2, woodMid);
  for (final x in [2, 12]) {
    fillRect(bench, x, 13, 2, 3, outline);
  }
  return bench;
}

/// A market stall under a [colour] awning, crates and sacks on its
/// counter.
img.Image _marketStall(img.Color colour) {
  final stall = blank(2, 2);
  for (final x in [1, 29]) {
    fillRect(stall, x, 6, 2, 22, outline);
  }
  fillRect(stall, 0, 26, 32, 6, outline);
  fillRect(stall, 1, 27, 30, 4, woodLight);
  draw(stall, farmCell((11, 1)), 0, 12);
  draw(stall, farmCell((10, 0)), tile, 12);
  awning(stall, 0, 2, 2 * tile, colour);
  return stall;
}

/// Castle Hill: a broad grassy hill, sunlit on top and shaded down its
/// southern slope, a dirt road climbing from its west foot to the gate.
img.Image _hill() {
  final hill = blank(10, 10);
  const centreX = 80.0, centreY = 66.0, radiusX = 79.0, radiusY = 70.0;
  for (var y = 0; y < hill.height; y++) {
    for (var x = 0; x < hill.width; x++) {
      final distance = math.pow((x - centreX) / radiusX, 2) + math.pow((y - centreY) / radiusY, 2);
      if (distance > 1) continue;
      final colour = distance > 0.93
          ? grassDark
          : (y > centreY + 8 && distance > 0.45 ? grassShade : (distance < 0.42 ? grassLight : grass));
      hill.setPixel(x, y, colour);
    }
  }
  // Tufts of shading across the slope.
  for (final (x, y) in [(30, 110), (50, 126), (118, 104), (132, 120), (96, 132), (24, 84)]) {
    fillRect(hill, x, y, 4, 1, grassDark);
  }
  _road(hill);
  return hill;
}

/// The road: in along the hill's west foot (rows 6–7 of the hill), east,
/// then up to the gate under the Castle (columns 4–5, row 5), paved with
/// Tiny Town's dirt path.
void _road(img.Image hill) {
  final cells = [
    for (var column = 0; column < 6; column++) ...[(column, 6), (column, 7)],
    (4, 5),
    (5, 5),
  ];
  for (final (column, row) in cells) {
    draw(hill, townCell((1, 2)), column * tile, row * tile);
  }
}

/// The Castle at [stage] (0–5), 6 × 6 cells.
img.Image castleStage(int stage) {
  final castle = blank(6, 6);
  if (stage == 0) {
    _surveyed(castle);
    return castle;
  }
  _foundation(castle);
  if (stage >= 2) _keep(castle);
  if (stage >= 3) _frontWall(castle);
  if (stage >= 4) _towers(castle);
  if (stage >= 5) _banners(castle);
  return castle;
}

/// The surveyed hilltop: four stakes, the line between them, and a flag.
void _surveyed(img.Image castle) {
  const left = 12, top = 24, right = 84, bottom = 84;
  for (var x = left; x <= right; x += 2) {
    castle.setPixel(x, top, white);
    castle.setPixel(x, bottom, white);
  }
  for (var y = top; y <= bottom; y += 2) {
    castle.setPixel(left, y, white);
    castle.setPixel(right, y, white);
  }
  for (final (x, y) in [(left, top), (right, top), (left, bottom), (right, bottom)]) {
    fillRect(castle, x - 1, y - 4, 3, 7, outline);
    fillRect(castle, x, y - 3, 1, 5, woodMid);
  }
  drawPennant(castle, x: 46);
  fillRect(castle, 44, 13, 6, 2, outline);
}

/// The foundation: Tiny Town's stone platform stretched over the Castle's
/// footprint (rows 1–5).
void _foundation(img.Image castle) {
  for (var column = 0; column < 6; column++) {
    for (var row = 1; row < 6; row++) {
      final sheetColumn = column == 0 ? 0 : (column == 5 ? 2 : 1);
      final sheetRow = row == 1 ? 8 : (row == 5 ? 10 : 9);
      draw(castle, townCell((sheetColumn, sheetRow)), column * tile, row * tile);
    }
  }
}

/// The keep: a tall stone tower in the middle, battlements, an arched
/// window and a door.
void _keep(img.Image castle) {
  const x = 2 * tile;
  draw(castle, townCell(battlementLeft), x, 0);
  draw(castle, townCell(battlementRight), x + tile, 0);
  draw(castle, townCell(archLeft), x, tile);
  draw(castle, townCell(archRight), x + tile, tile);
  shadeOpening(castle, tile, x: x);
  draw(castle, townCell(brickWindow), x, 2 * tile);
  draw(castle, townCell(brickWindow), x + tile, 2 * tile);
  draw(castle, townCell(brick), x, 3 * tile);
  draw(castle, townCell(brick), x + tile, 3 * tile);
}

/// The curtain wall across the front with the great gate in its middle.
void _frontWall(img.Image castle) {
  for (var column = 0; column < 6; column++) {
    final x = column * tile;
    if (column == 2 || column == 3) continue;
    draw(castle, townCell(column == 0 ? battlementLeft : (column == 5 ? battlementRight : battlementMiddle)), x, 4 * tile);
    draw(castle, townCell(brick), x, 5 * tile);
  }
  draw(castle, townCell((3, 9)), 2 * tile, 4 * tile);
  draw(castle, townCell((4, 9)), 3 * tile, 4 * tile);
  draw(castle, townCell((3, 10)), 2 * tile, 5 * tile);
  draw(castle, townCell((4, 10)), 3 * tile, 5 * tile);
}

/// Round towers at the four corners.
void _towers(img.Image castle) {
  for (final (column, row) in [(0, 0), (4, 0), (0, 4), (4, 4)]) {
    final x = column * tile, y = row * tile;
    for (final (dx, dy, cell) in [(0, 0, (0, 8)), (tile, 0, (2, 8)), (0, tile, (0, 10)), (tile, tile, (2, 10))]) {
      draw(castle, townCell(cell), x + dx, y + dy);
    }
    fillRect(castle, x + 12, y + 12, 8, 8, stoneMid);
  }
}

/// Banners on every tower and the keep, and torches by the gate.
void _banners(img.Image castle) {
  for (final x in [10, 74]) {
    drawPennant(castle, x: x);
  }
  final low = blank(6, 6);
  for (final x in [10, 74]) {
    drawPennant(low, x: x);
  }
  draw(castle, img.copyCrop(low, x: 0, y: 0, width: castle.width, height: 14), 0, 4 * tile + 2);
  drawPennant(castle, x: 2 * tile + 12);
  for (final x in [2 * tile - 6, 4 * tile - 2]) {
    draw(castle, img.copyCrop(dungeonCell(torch), x: 4, y: 0, width: 8, height: 12), x, 5 * tile);
  }
}

/// Builders' scaffolding over the Castle's footprint, with a hammer at
/// work: drawn over a stage while the next one rises.
img.Image _castleScaffold() {
  final scaffold = blank(6, 6);
  for (final x in [4, 46, 90]) {
    fillRect(scaffold, x, 8, 2, 84, outline);
    fillRect(scaffold, x, 9, 1, 82, woodMid);
  }
  for (final y in [30, 62]) {
    fillRect(scaffold, 4, y, 88, 2, outline);
    fillRect(scaffold, 5, y, 86, 1, woodLight);
  }
  for (var step = 0; step < 40; step++) {
    scaffold.setPixel(6 + step, 30 - step ~/ 2, outline);
    scaffold.setPixel(48 + step, 62 - step ~/ 2, outline);
  }
  draw(scaffold, townCell((8, 10)), 40, 72);
  return scaffold;
}
