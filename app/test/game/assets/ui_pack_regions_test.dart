/// The bundled Kenney UI pack maps every kit key to an in-bounds cell, so the
/// kit's frames resolve to pack art on every device.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/sprite_region.dart';

void main() {
  const requiredKeys = [
    'ui.panel.parchment.idle',
    'ui.panel.wood.idle',
    'ui.panel.slate.idle',
    'ui.panel.ornate.idle',
    'ui.panel.inset.idle',
    'ui.banner.ribbon.idle',
    'ui.banner.plain.idle',
    'ui.button.round.idle',
  ];

  test('every kit key resolves to a cell inside the 416x224 sheet', () {
    final manifest = jsonDecode(
      File('assets/game/packs/ui_pixel_adventure/regions.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final regions = parsePackRegions('ui_pixel_adventure', manifest);
    for (final key in requiredKeys) {
      final region = regions[key];
      expect(region, isNotNull, reason: key);
      expect(region!.cellSize, 32);
      expect(region.left + region.width, lessThanOrEqualTo(416), reason: key);
      expect(region.top + region.height, lessThanOrEqualTo(224), reason: key);
    }
  });

  test('pubspec bundles the pack and declares both pixel fonts', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/game/packs/ui_pixel_adventure/'));
    expect(pubspec, contains('family: LootPixel'));
    expect(pubspec, contains('family: LootPixelMono'));
  });
}
