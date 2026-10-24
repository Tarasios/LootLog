import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/decor/chest_decor.dart';
import 'package:lootlog/game/domain/game_rng.dart';
import 'package:lootlog/game/domain/game_values.dart';

void main() {
  final catalog = DecorCatalog.fromJson(
      jsonDecode(File('assets/game/catalog.json').readAsStringSync()) as Map<String, dynamic>);

  test('the same event id always rolls the same drop', () {
    ChestDecorDrop roll() => rollChestDecor(GameRng.forEvent('chest-event-1'), ChestType.iron, catalog,
        alreadyOwned: (_) => false);
    expect(roll().item?.id, roll().item?.id);
  });

  test('the spoils chest always holds a decoration', () {
    for (var i = 0; i < 50; i++) {
      final drop = rollChestDecor(GameRng.forEvent('spoils-$i'), ChestType.spoils, catalog, alreadyOwned: (_) => false);
      expect(drop.item, isNotNull);
    }
  });

  test('drops never include exclusive milestone items', () {
    for (var i = 0; i < 200; i++) {
      final drop = rollChestDecor(GameRng.forEvent('gold-$i'), ChestType.gold, catalog, alreadyOwned: (_) => false);
      expect(drop.item?.exclusive ?? false, isFalse);
    }
  });

  test('a duplicate becomes gems instead', () {
    final drop = rollChestDecor(GameRng.forEvent('spoils-dup'), ChestType.spoils, catalog, alreadyOwned: (_) => true);
    expect(drop.item, isNull);
    expect(drop.duplicateGems, Balance.duplicateDecorGems);
  });

  test('rares do turn up from gold chests over many rolls', () {
    final rarities = {
      for (var i = 0; i < 500; i++)
        rollChestDecor(GameRng.forEvent('gold-many-$i'), ChestType.gold, catalog, alreadyOwned: (_) => false).item?.rarity,
    };
    expect(rarities, contains(DecorRarity.rare));
  });
}
