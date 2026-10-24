import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/sprite_region.dart';

void main() {
  test('a single cell with no spacing', () {
    const region = SpriteRegion(sheetPath: 'packs/a/sheet.png', column: 2, row: 3);
    expect([region.left, region.top, region.width, region.height], [32, 48, 16, 16]);
  });

  test('a 2x2 block with 1px spacing spans the gap between its cells', () {
    const region = SpriteRegion(
        sheetPath: 'packs/a/sheet.png', column: 1, row: 1, columns: 2, rows: 2, spacing: 1);
    expect([region.left, region.top, region.width, region.height], [17, 17, 33, 33]);
  });

  test('parsePackRegions reads [column,row] and [column,row,columns,rows]', () {
    final regions = parsePackRegions('tiny_town', {
      'sheet': 'tilemap_packed.png',
      'cellSize': 16,
      'spacing': 0,
      'regions': {
        'town.ground.grass.idle': [0, 0],
        'town.house.default.idle': [4, 5, 2, 2],
      },
    });
    expect(regions['town.ground.grass.idle']!.sheetPath, 'packs/tiny_town/tilemap_packed.png');
    expect(regions['town.house.default.idle']!.columns, 2);
    expect(regions['town.house.default.idle']!.rows, 2);
  });

  test('parsePackRegions skips malformed keys and cells', () {
    final regions = parsePackRegions('tiny_town', {
      'sheet': 'tilemap_packed.png',
      'cellSize': 16,
      'spacing': 0,
      'regions': {
        'not a key': [0, 0],
        'town.ground.grass.idle': [0],
      },
    });
    expect(regions, isEmpty);
  });
}
