import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';

void main() {
  final raw = jsonDecode(File('assets/game/catalog.json').readAsStringSync()) as Map<String, dynamic>;
  final catalog = DecorCatalog.fromJson(raw);

  test('every entry parses', () {
    expect(catalog.items, hasLength((raw['items'] as List).length));
  });

  test('ids are unique', () {
    final ids = catalog.items.map((item) => item.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('the shop has enough items for a full daily rotation, with cheap ones', () {
    expect(catalog.shopPool.length, greaterThanOrEqualTo(12));
    expect(catalog.shopPool.where((item) => item.priceGems! <= 10), isNotEmpty);
  });

  test('the starter set resolves and fits a room', () {
    expect(catalog.starterSet, hasLength(4));
    expect(catalog.starterSet.where((item) => item.equippable), hasLength(1));
  });

  test('every rarity has chest items', () {
    for (final rarity in DecorRarity.values) {
      expect(catalog.chestPool(rarity), isNotEmpty, reason: rarity.name);
    }
  });

  test('equippable ids follow the naming the projection relies on', () {
    for (final item in catalog.items) {
      if (item.kind == DecorKind.outfit) expect(item.id, startsWith('outfit_'));
      if (item.kind == DecorKind.title) expect(item.id, endsWith('_title'));
    }
  });

  test('every purchasable town decoration id starts with town_', () {
    for (final item in catalog.shopPool) {
      if (item.kind == DecorKind.townDecor) expect(item.id, startsWith('town_'));
      if (item.kind != DecorKind.townDecor) expect(item.id, isNot(startsWith('town_')));
    }
  });
}
