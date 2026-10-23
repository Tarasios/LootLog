import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lootlog/game/assets/asset_catalog.dart';
import 'package:lootlog/game/domain/game_values.dart';

const packNames = ['tiny_town', 'tiny_dungeon', 'roguelike_indoors'];

/// Non-building keys the town, dungeon and room scenes ask the packs for
/// (the brief's Step 5 plus the Task 7 catalogue extras).
const requiredKeys = [
  'town.ground.grass.idle',
  'town.ground.path.idle',
  'town.ground.water.idle',
  'town.ground.square.idle',
  'town.tree.default.idle',
  'town.bush.default.idle',
  'town.fence.default.idle',
  'town.gate.dungeon.idle',
  'town.house.default.idle',
  'town.wagon.default.idle',
  'town.scaffold.default.idle',
  'town.plot.locked.idle',
  'town.plot.empty.idle',
  'town_decor.flowerbed.default.idle',
  'town_decor.lamp_post.default.idle',
  'town_decor.bench.default.idle',
  'town_decor.well.default.idle',
  'town_decor.well.fountain.idle',
  'town_decor.statue.default.idle',
  'dungeon.floor.default.idle',
  'dungeon.wall.default.idle',
  'dungeon.torch.default.idle',
  'hero.body.default.idle',
  'hero.body.knight.idle',
  'hero.body.wizard.idle',
  'hero.body.rogue.idle',
  'hero.body.ranger.idle',
  'boss.goal.default.idle',
  'boss.goal.food.idle',
  'boss.goal.entertainment.idle',
  'boss.goal.transport.idle',
  'boss.goal.housing.idle',
  'boss.overbudget.default.idle',
  'npc.villager.a.idle',
  'npc.villager.b.idle',
  'npc.pet.default.idle',
  'item.weapon.default.idle',
  'chest.wood.closed.idle',
  'chest.wood.open.idle',
  'chest.gold.closed.idle',
  'room.floor.wood.idle',
  'room.wall.default.idle',
  'furniture.bed.default.idle',
  'furniture.bed.canopy.idle',
  'furniture.rug.default.idle',
  'furniture.rug.dragon.idle',
  'furniture.lamp.default.idle',
  'furniture.lamp.crown.idle',
  'furniture.lamp.ember.idle',
  'furniture.table.default.idle',
  'furniture.chair.default.idle',
  'furniture.bookshelf.default.idle',
  'furniture.plant.default.idle',
  'furniture.painting.default.idle',
  'furniture.painting.banner.idle',
  'furniture.wardrobe.default.idle',
  'furniture.desk.default.idle',
  'furniture.armchair.default.idle',
  'furniture.clock.default.idle',
  'furniture.trophy_stand.default.idle',
];

Map<String, List<dynamic>> readRegions(String packName) {
  final manifest = jsonDecode(
          File('assets/game/packs/$packName/regions.json').readAsStringSync())
      as Map<String, dynamic>;
  return (manifest['regions'] as Map).cast<String, List<dynamic>>();
}

void main() {
  for (final packName in packNames) {
    group(packName, () {
      final folder = Directory('assets/game/packs/$packName');
      final regionsFile = File('${folder.path}/regions.json');
      late Map<String, dynamic> manifest;

      setUpAll(() {
        manifest = jsonDecode(regionsFile.readAsStringSync()) as Map<String, dynamic>;
      });

      test('ships a CC0 licence', () {
        final licence = File('${folder.path}/License.txt').readAsStringSync();
        expect(licence.toUpperCase(), contains('CC0'));
      });

      test('every region lies inside the sheet', () {
        final sheetBytes =
            File('${folder.path}/${manifest['sheet']}').readAsBytesSync();
        final sheet = img.decodePng(sheetBytes)!;
        final cellSize = manifest['cellSize'] as int;
        final spacing = manifest['spacing'] as int;
        final regions = (manifest['regions'] as Map).cast<String, List<dynamic>>();
        expect(regions, isNotEmpty);
        for (final entry in regions.entries) {
          final cell = entry.value.cast<int>();
          final columns = cell.length > 2 ? cell[2] : 1;
          final rows = cell.length > 3 ? cell[3] : 1;
          final right = cell[0] * (cellSize + spacing) + columns * cellSize + (columns - 1) * spacing;
          final bottom = cell[1] * (cellSize + spacing) + rows * cellSize + (rows - 1) * spacing;
          expect(right <= sheet.width && bottom <= sheet.height, isTrue,
              reason: '${entry.key} falls outside ${manifest['sheet']}');
        }
      });
    });
  }

  group('required keys', () {
    test('every building type has all five tiers in tiny_town', () {
      final regions = readRegions('tiny_town');
      for (final type in BuildingType.values) {
        for (var tier = 1; tier <= GameAssetKeys.buildingTiers; tier++) {
          final key = GameAssetKeys.building(type, tier).value;
          expect(regions, contains(key));
        }
      }
    });

    test('the other required keys exist in some pack', () {
      final allKeys = {
        for (final packName in packNames) ...readRegions(packName).keys,
      };
      for (final key in requiredKeys) {
        expect(allKeys, contains(key));
      }
    });

    test('every region is [column, row] or [column, row, columns, rows]', () {
      for (final packName in packNames) {
        for (final entry in readRegions(packName).entries) {
          final cell = entry.value;
          expect(cell.length == 2 || cell.length == 4, isTrue,
              reason: '$packName/${entry.key} has ${cell.length} values');
          expect(cell.every((value) => value is int && value >= 0), isTrue,
              reason: '$packName/${entry.key} must be non-negative ints');
        }
      }
    });

    test('no two building types share the same tier cells', () {
      final regions = readRegions('tiny_town');
      final looks = <String, BuildingType>{};
      for (final type in BuildingType.values) {
        final cells = {
          for (var tier = 1; tier <= GameAssetKeys.buildingTiers; tier++)
            regions[GameAssetKeys.building(type, tier).value]!.join(','),
        }.toList()
          ..sort();
        final look = cells.join('|');
        expect(looks, isNot(contains(look)),
            reason: '$type looks identical to ${looks[look]}');
        looks[look] = type;
      }
    });
  });
}
