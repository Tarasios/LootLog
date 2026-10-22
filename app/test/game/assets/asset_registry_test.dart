import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_catalog.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/domain/game_values.dart';

void main() {
  group('GameAssetKeys catalogue', () {
    test('every catalogued key is valid and unique', () {
      final all = GameAssetKeys.all;
      for (final k in all) {
        expect(k.isValid, isTrue, reason: k.value);
      }
      expect(all.toSet().length, all.length);
    });

    test('covers all 11 buildings at tiers 1..5', () {
      expect(GameAssetKeys.buildings, hasLength(11 * 5));
      expect(GameAssetKeys.building(BuildingType.lumberyard, 2).value,
          'building.lumberyard.t2.idle');
      expect(GameAssetKeys.building(BuildingType.centralHall, 1).value,
          'building.central_hall.t1.idle');
      expect(
          GameAssetKeys.building(BuildingType.arcaneWell, 5,
                  state: 'constructing')
              .value,
          'building.arcane_well.t5.constructing');
    });

    test('covers the 8 materials, 5 chests open/closed and 7 regions', () {
      expect(GameAssetKeys.materials, hasLength(8));
      expect(GameAssetKeys.material(MaterialKind.ore).value,
          'material.ore.icon.idle');
      expect(GameAssetKeys.chests, hasLength(10));
      expect(GameAssetKeys.chest(ChestType.gold).value,
          'chest.gold.closed.idle');
      expect(GameAssetKeys.chest(ChestType.spoils, open: true).value,
          'chest.spoils.open.idle');
      expect(GameAssetKeys.regions, hasLength(7));
      expect(GameAssetKeys.region(ExpeditionRegion.subscriptionSwamp).value,
          'region.subscription_swamp.banner.idle');
    });

    test('hero portraits, gear slots, bosses, currency and UI panels', () {
      expect(GameAssetKeys.heroPortrait.value, 'hero.portrait.default.idle');
      expect(GameAssetKeys.supplyCaravan.value, 'hero.caravan.default.idle');
      expect(GameAssetKeys.gear('weapon').value, 'gear.weapon.default.idle');
      expect(GameAssetKeys.gear('weapon', tier: 3).value, 'gear.weapon.t3.idle');
      expect(GameAssetKeys.boss('Frost Wyrm').value,
          'boss.frost_wyrm.default.idle');
      expect(GameAssetKeys.boss('frostWyrm', state: 'defeated').value,
          'boss.frost_wyrm.default.defeated');
      expect(GameAssetKeys.gem.value, 'currency.gem.icon.idle');
      expect(GameAssetKeys.panel('hall_plot').value, 'ui.panel.hall_plot.idle');
      expect(GameAssetKeys.gearSlots, isNotEmpty);
      expect(GameAssetKeys.panels, isNotEmpty);
      expect(GameAssetKeys.bosses, isNotEmpty);
    });

    test('guildHall excludes the dungeon keys; all includes both', () {
      expect(GameAssetKeys.guildHall.any((k) => k.category == 'dungeon'),
          isFalse);
      expect(GameAssetKeys.all.toSet(),
          containsAll([...GameAssetKeys.guildHall, ...GameAssetKeys.dungeon]));
    });
  });

  group('AssetRegistry', () {
    const registry = AssetRegistry({
      'building.forge.default.idle': 'building.forge.default.idle_1f.png',
      'building.forge.t3.idle': 'building.forge.t3.idle_4f.png',
      'chest.gold.closed.idle': 'chest.gold.closed.idle_1f.png',
    });

    test('resolves an exact key', () {
      expect(registry.fileFor(AssetKey.parse('building.forge.t3.idle')),
          'building.forge.t3.idle_4f.png');
    });

    test('walks the fallback chain: state -> idle, then variant -> default',
        () {
      expect(
          registry.fileFor(AssetKey.parse('building.forge.t3.constructing')),
          'building.forge.t3.idle_4f.png');
      expect(registry.fileFor(AssetKey.parse('building.forge.t5.idle')),
          'building.forge.default.idle_1f.png');
    });

    test('never crosses subjects or categories; misses resolve to null', () {
      expect(registry.fileFor(AssetKey.parse('chest.gold.open.idle')), isNull);
      expect(registry.fileFor(AssetKey.parse('building.mine.t1.idle')), isNull);
      expect(registry.hasArt(AssetKey.parse('chest.gold.closed.idle')), isTrue);
      expect(registry.hasArt(AssetKey.parse('chest.iron.closed.idle')), isFalse);
    });

    test('merge prefers the other registry on clashes', () {
      final merged = registry.merge(const AssetRegistry({
        'chest.gold.closed.idle': 'override_1f.png',
        'chest.gold.open.idle': 'open_1f.png',
      }));
      expect(merged.fileFor(AssetKey.parse('chest.gold.closed.idle')),
          'override_1f.png');
      expect(merged.fileFor(AssetKey.parse('chest.gold.open.idle')),
          'open_1f.png');
      expect(merged.fileFor(AssetKey.parse('building.forge.t3.idle')),
          'building.forge.t3.idle_4f.png');
    });

    group('discover', () {
      test('picks up files named after their key under assets/game/', () {
        final found = AssetRegistry.discover(const [
          'assets/game/building.lumberyard.t2.idle_4f.png',
          'assets/game/chest.gold.open.idle.png',
          'assets/game/monster_idle_4f.png', // legacy name: not a key
          'assets/game/text/voice.json', // not an image
          'assets/game/sub/material.ore.icon.idle_1f.png', // not top level
          'assets/branding/region.old_roads.banner.idle_1f.png', // elsewhere
          'assets/game/Bad.Key.x.idle_1f.png', // invalid key
        ]);
        expect(found.files, {
          'building.lumberyard.t2.idle': 'building.lumberyard.t2.idle_4f.png',
          'chest.gold.open.idle': 'chest.gold.open.idle.png',
        });
      });

      test('a strip with more frames wins over a duplicate key', () {
        final found = AssetRegistry.discover(const [
          'assets/game/hero.portrait.default.idle_1f.png',
          'assets/game/hero.portrait.default.idle_4f.png',
        ]);
        expect(found.files['hero.portrait.default.idle'],
            'hero.portrait.default.idle_4f.png');
      });
    });

    test('bundled maps the existing dungeon art, and every file exists', () {
      final bundled = AssetRegistry.bundled;
      expect(bundled.fileFor(GameAssetKeys.dungeonMonster),
          'monster_idle_4f.png');
      expect(bundled.fileFor(GameAssetKeys.dungeonMonsterEnraged),
          'monster_enraged_4f.png');
      expect(bundled.fileFor(GameAssetKeys.dungeonCoin), 'coin_spin_6f.png');
      for (final entry in bundled.files.entries) {
        expect(AssetKey.tryParse(entry.key), isNotNull, reason: entry.key);
        expect(File('assets/game/${entry.value}').existsSync(), isTrue,
            reason: '${entry.key} -> ${entry.value}');
      }
    });

    test('no guild-hall key has bundled art yet, so all render as text', () {
      for (final k in GameAssetKeys.guildHall) {
        expect(AssetRegistry.bundled.fileFor(k), isNull, reason: k.value);
      }
    });
  });
}
