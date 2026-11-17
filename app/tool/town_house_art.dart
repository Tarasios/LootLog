/// House-shaped buildings from Kenney "Tiny Town" (CC0), shared by the hall
/// buildings (`compose_town_buildings.dart`) and the civic quarters'
/// buildings (`town_civic_art.dart`): a roof over a wall row, with a door
/// and either a window or a sign that tells the buildings apart.
///
/// - tiers 1–2: 2×2 cells, a squat roof row over the wall row;
/// - tiers 3–4: 2×3 cells, a full two-row roof (the extra row overhangs the
///   cell above the plot), tier 4 with a dormer;
/// - tier 5: the tier-4 look with a pennant flying from the roof.
library;

import 'package:image/image.dart' as img;

import 'town_farm_art.dart';

/// Roof colours: the left tile's column on the sheet (the right is two on).
const int blueRoof = 0, redRoof = 4;

/// Wall materials: the column of the material's first tile on rows 6 and 7.
const int brickWall = 0, stoneWall = 4;

/// Tool signs hung on a wall.
const Cell pickaxe = (7, 9), pitchfork = (8, 9), keySign = (9, 9), bowSign = (10, 9);
const Cell axe = (7, 10), hammer = (8, 10), bucket = (10, 10);

/// One building: its roof, wall, whether it has double doors, and its sign
/// (a Tiny Town cell, or any picture in [signArt]).
class Recipe {
  const Recipe(this.roof, this.wall, {this.doubleDoor = false, this.sign, this.signArt});
  final int roof;
  final int wall;
  final bool doubleDoor;
  final Cell? sign;
  final img.Image Function()? signArt;
}

/// A squat roof row: the top half of the roof's upper tile over the bottom
/// half of its lower tile, so one 16 px row carries both ridge and eave.
void drawSquatRoof(img.Image target, int roofColumn, int y) {
  for (final (offset, column) in [(0, roofColumn), (tile, roofColumn + 2)]) {
    final ridge = img.copyCrop(townCell((column, 4)), x: 0, y: 0, width: tile, height: 8);
    final eave = img.copyCrop(townCell((column, 5)), x: 0, y: 8, width: tile, height: 8);
    draw(target, ridge, offset, y);
    draw(target, eave, offset, y + 8);
  }
}

/// A full roof: the upper roof tiles over the lower ones, with a dormer
/// (the roof sheet's own window tile) on the right of the upper row.
void drawTallRoof(img.Image target, int roofColumn, {required bool dormer}) {
  draw(target, townCell((roofColumn, 4)), 0, 0);
  draw(target, townCell(dormer ? (roofColumn + 3, 4) : (roofColumn + 2, 4)), tile, 0);
  draw(target, townCell((roofColumn, 5)), 0, tile);
  draw(target, townCell((roofColumn + 2, 5)), tile, tile);
}

/// The wall row at [y]: double doors, a wall with its sign beside a door,
/// or a window beside a door.
void drawWall(img.Image target, Recipe recipe, int y) {
  final wall = recipe.wall;
  final signArt = recipe.signArt;
  if (recipe.doubleDoor) {
    draw(target, townCell((wall + 2, 7)), 0, y);
    draw(target, townCell((wall + 3, 7)), tile, y);
    if (signArt != null) draw(target, signArt(), 0, y - 4);
  } else if (recipe.sign != null || signArt != null) {
    draw(target, townCell((wall, 6)), 0, y);
    draw(target, signArt != null ? signArt() : townCell(recipe.sign!), 0, y);
    draw(target, townCell((wall + 1, 7)), tile, y);
  } else {
    draw(target, townCell((wall, 7)), 0, y);
    draw(target, townCell((wall + 1, 7)), tile, y);
  }
}

/// A building at tiers 1–2: the squat roof over the wall.
img.Image squatBuilding(Recipe recipe) {
  final building = blank(2, 2);
  drawSquatRoof(building, recipe.roof, 0);
  drawWall(building, recipe, tile);
  return building;
}

/// A building at tiers 3–5: the full roof over the wall, a dormer from tier
/// 4 and a pennant at tier 5.
img.Image tallBuilding(Recipe recipe, int tier) {
  final building = blank(2, 3);
  drawTallRoof(building, recipe.roof, dormer: tier >= 4);
  drawWall(building, recipe, 2 * tile);
  if (tier >= 5) drawPennant(building, x: 4);
  return building;
}
