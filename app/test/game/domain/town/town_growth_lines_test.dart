import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/town_growth_lines.dart';

final _shame = RegExp(
  r'\b(fail|failed|bad|lazy|should have|overspent|wasted|shame|guilt|lost|missed|penalty|starv\w*)\b',
  caseSensitive: false,
);

Map<String, dynamic> _shippedFile() =>
    jsonDecode(File('assets/game/text/town_growth.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  const lines = TownGrowthLines.defaults;

  test('every tier, district and farm building has its built-in lines', () {
    for (final tier in TownTier.values) {
      expect(lines.line(tierNameKey(tier)), isNotEmpty, reason: tier.name);
      if (tier != TownTier.outpost) {
        expect(lines.line(tierReachedKey(tier)), isNotEmpty, reason: tier.name);
      }
    }
    for (final district in kDistricts) {
      expect(lines.line(districtNameKey(district.id)), isNotEmpty, reason: district.id);
      expect(lines.line(districtBlurbKey(district.id)), isNotEmpty, reason: district.id);
    }
    for (final type in FarmBuildingType.values) {
      expect(lines.line(farmBuildingNameKey(type)), isNotEmpty, reason: type.name);
    }
  });

  test('the shipped town_growth.json carries the built-in lines', () {
    final shipped = _shippedFile();
    expect(TownGrowthLines.fromJson(shipped), lines);
    for (final key in lines.keys) {
      expect(shipped[key], lines.line(key), reason: key);
    }
  });

  test('a missing, blank or non-text key keeps its built-in line', () {
    final read = TownGrowthLines.fromJson({
      'tier.name.hamlet': '',
      'tier.name.village': 3,
      'tier.name.town': 'Burgh',
    });
    expect(read.line('tier.name.hamlet'), 'Hamlet');
    expect(read.line('tier.name.village'), 'Village');
    expect(read.line('tier.name.town'), 'Burgh');
    expect(read.line('district.name.skyIsland'), '');
  });

  test('nothing shames, and a hungry town is never framed as a loss', () {
    for (final key in lines.keys) {
      expect(_shame.hasMatch(lines.line(key)), isFalse, reason: '$key: ${lines.line(key)}');
    }
  });
}
