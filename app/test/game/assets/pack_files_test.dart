// app/test/game/assets/pack_files_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const packNames = ['tiny_town', 'tiny_dungeon', 'roguelike_indoors'];

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
}
