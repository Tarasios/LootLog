/// Drawing a sprite region cell by cell: a sheet with spacing between its
/// cells must never carry those transparent gaps into the drawn sprite.
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/region_cells.dart';
import 'package:lootlog/game/assets/sprite_region.dart';

void main() {
  test('a packed region is drawn as one cell per sheet cell, edge to edge', () {
    const region = SpriteRegion(sheetPath: 'packs/a/sheet.png', column: 2, row: 1, columns: 2);
    final cells = regionCellRects(region, const Rect.fromLTWH(0, 0, 64, 32));
    expect(cells.map((cell) => cell.source), [
      const Rect.fromLTWH(32, 16, 16, 16),
      const Rect.fromLTWH(48, 16, 16, 16),
    ]);
    expect(cells.map((cell) => cell.destination), [
      const Rect.fromLTWH(0, 0, 32, 32),
      const Rect.fromLTWH(32, 0, 32, 32),
    ]);
  });

  test('with 1px spacing the sources skip the gaps and the destinations abut', () {
    const region = SpriteRegion(
        sheetPath: 'packs/a/sheet.png', column: 3, row: 0, columns: 2, rows: 2, spacing: 1);
    final cells = regionCellRects(region, const Rect.fromLTWH(10, 20, 96, 96));
    expect(cells.map((cell) => cell.source), [
      const Rect.fromLTWH(51, 0, 16, 16),
      const Rect.fromLTWH(68, 0, 16, 16),
      const Rect.fromLTWH(51, 17, 16, 16),
      const Rect.fromLTWH(68, 17, 16, 16),
    ]);
    expect(cells.map((cell) => cell.destination), [
      const Rect.fromLTWH(10, 20, 48, 48),
      const Rect.fromLTWH(58, 20, 48, 48),
      const Rect.fromLTWH(10, 68, 48, 48),
      const Rect.fromLTWH(58, 68, 48, 48),
    ]);
  });

  test('a single cell is one source rectangle filling the destination', () {
    const region = SpriteRegion(sheetPath: 'packs/a/sheet.png', column: 1, row: 1, spacing: 1);
    final cells = regionCellRects(region, const Rect.fromLTWH(0, 0, 48, 48));
    expect(cells, hasLength(1));
    expect(cells.single.source, const Rect.fromLTWH(17, 17, 16, 16));
    expect(cells.single.destination, const Rect.fromLTWH(0, 0, 48, 48));
  });

  test('the packed size leaves the sheet gaps out', () {
    const region = SpriteRegion(
        sheetPath: 'packs/a/sheet.png', column: 0, row: 0, columns: 2, rows: 1, spacing: 1);
    expect([region.packedWidth, region.packedHeight], [32, 16]);
  });
}
