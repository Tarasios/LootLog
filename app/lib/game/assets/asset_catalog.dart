/// The game's asset-key vocabulary: every key a screen asks for and an artist
/// can fill. Each key is individually optional — with no art it renders as a
/// text/ASCII card (see `text_sprite.dart`). The list an artist works from is
/// in `docs/art-assets.md` §9; keep the two in step.
///
/// Pure Dart, zero Flutter imports.
library;

import '../domain/game_values.dart';
import 'asset_key.dart';

/// Builders and lists for the guild-hall and dungeon asset keys.
abstract final class GameAssetKeys {
  // ---- Guild hall: buildings ----------------------------------------------

  /// Buildings are drawn per tier, `t1`..`t5`.
  static const buildingTiers = 5;

  /// `building.<type>.t<tier>.<state>`, e.g. `building.lumberyard.t2.idle`.
  /// A missing tier falls back to `building.<type>.default.idle`.
  static AssetKey building(BuildingType type, int tier,
          {String state = AssetKey.idleState}) =>
      AssetKey('building', AssetKey.snakeSegment(type.name), 't$tier', state);

  static List<AssetKey> get buildings => [
        for (final type in BuildingType.values)
          for (var tier = 1; tier <= buildingTiers; tier++)
            building(type, tier),
      ];

  // ---- Materials, currency, chests ----------------------------------------

  /// `material.<kind>.icon.idle`, e.g. `material.ore.icon.idle`.
  static AssetKey material(MaterialKind kind) =>
      AssetKey('material', kind.name, 'icon');

  static List<AssetKey> get materials =>
      [for (final m in MaterialKind.values) material(m)];

  /// The gem (premium currency) icon.
  static const gem = AssetKey('currency', 'gem', 'icon');

  /// The streak-freeze token icon.
  static const freezeToken = AssetKey('currency', 'freeze_token', 'icon');

  static const currencies = [gem, freezeToken];

  /// `chest.<type>.closed.idle` / `chest.<type>.open.idle`.
  static AssetKey chest(ChestType type, {bool open = false}) =>
      AssetKey('chest', type.name, open ? 'open' : 'closed');

  static List<AssetKey> get chests => [
        for (final c in ChestType.values) ...[
          chest(c),
          chest(c, open: true),
        ],
      ];

  // ---- Regions ------------------------------------------------------------

  /// `region.<region>.banner.idle`, e.g.
  /// `region.subscription_swamp.banner.idle`.
  static AssetKey region(ExpeditionRegion region) =>
      AssetKey('region', AssetKey.snakeSegment(region.name), 'banner');

  static List<AssetKey> get regions =>
      [for (final r in ExpeditionRegion.values) region(r)];

  // ---- Heroes & gear ------------------------------------------------------

  /// The generic adventurer portrait (48x48), used until a member has a
  /// custom sprite.
  static const heroPortrait = AssetKey('hero', 'portrait');

  /// A Standard-mode adult, shown as the supply caravan backing the party.
  static const supplyCaravan = AssetKey('hero', 'caravan');

  static const heroes = [heroPortrait, supplyCaravan];

  /// Suggested gear slots. [gear] accepts any slot name, normalised to a
  /// segment, so a new slot needs no change here to get its text card.
  static const gearSlots = ['weapon', 'armor', 'helm', 'trinket'];

  /// `gear.<slot>.t<tier>.idle`, or `gear.<slot>.default.idle` without a tier.
  static AssetKey gear(String slot, {int? tier}) => AssetKey(
        'gear',
        AssetKey.snakeSegment(slot),
        tier == null ? AssetKey.defaultVariant : 't$tier',
      );

  static List<AssetKey> get gearItems => [for (final s in gearSlots) gear(s)];

  // ---- Bosses -------------------------------------------------------------

  /// `boss.<bossKey>.default.<state>`. [bossKey] is the `BossFought` event's
  /// key, normalised to a segment (`frostWyrm` -> `frost_wyrm`).
  static AssetKey boss(String bossKey, {String state = AssetKey.idleState}) =>
      AssetKey('boss', AssetKey.snakeSegment(bossKey), AssetKey.defaultVariant,
          state);

  /// The starter seasonal bosses an artist can draw first; any other boss key
  /// still renders through [boss] as text.
  static const bossKeys = ['winter', 'spring', 'summer', 'autumn'];

  static List<AssetKey> get bosses => [for (final b in bossKeys) boss(b)];

  // ---- UI panels & homestead ---------------------------------------------

  /// 9-slice panel names. `ui.panel.<name>.idle` falls back to
  /// `ui.panel.default.idle`, so one generic panel frames everything.
  static const panelNames = [
    'default',
    'party_frame',
    'log',
    'viewport',
    'hall_plot',
    'chest',
    'ritual',
  ];

  static AssetKey panel(String name) =>
      AssetKey('ui', 'panel', AssetKey.snakeSegment(name));

  static List<AssetKey> get panels => [for (final p in panelNames) panel(p)];

  /// Homestead stages 0..5 (the war chest made visible), `homestead.stage.s<n>`.
  static AssetKey homesteadStage(int stage) =>
      AssetKey('homestead', 'stage', 's$stage');

  static List<AssetKey> get homesteadStages =>
      [for (var s = 0; s <= 5; s++) homesteadStage(s)];

  // ---- Dungeon (existing art) ---------------------------------------------

  static const dungeonHeroA = AssetKey('dungeon', 'hero', 'a');
  static const dungeonHeroB = AssetKey('dungeon', 'hero', 'b');
  static const dungeonMonster = AssetKey('dungeon', 'monster');
  static const dungeonMonsterEnraged =
      AssetKey('dungeon', 'monster', AssetKey.defaultVariant, 'enraged');
  static const dungeonOverbudget = AssetKey('dungeon', 'overbudget');
  static const dungeonPet = AssetKey('dungeon', 'pet');
  static const dungeonQuestMonster = AssetKey('dungeon', 'quest_monster');
  static const dungeonGoldPouch = AssetKey('dungeon', 'gold_pouch');
  static const dungeonWarChest = AssetKey('dungeon', 'war_chest');
  static const dungeonReserveCache = AssetKey('dungeon', 'reserve_cache');
  static const dungeonCoin = AssetKey('dungeon', 'coin');
  static const dungeonTrophy = AssetKey('dungeon', 'trophy');
  static const dungeonCampfire = AssetKey('dungeon', 'campfire');
  static const dungeonAnvil = AssetKey('dungeon', 'anvil');
  static const dungeonContractSeal = AssetKey('dungeon', 'contract_seal');
  static const dungeonRansack = AssetKey('dungeon', 'ransack');
  static const dungeonScrollSeal = AssetKey('dungeon', 'scroll_seal');
  static const dungeonSupplies = AssetKey('dungeon', 'supplies');
  static const dungeonWrit = AssetKey('dungeon', 'writ');

  static const dungeon = [
    dungeonHeroA,
    dungeonHeroB,
    dungeonMonster,
    dungeonMonsterEnraged,
    dungeonOverbudget,
    dungeonPet,
    dungeonQuestMonster,
    dungeonGoldPouch,
    dungeonWarChest,
    dungeonReserveCache,
    dungeonCoin,
    dungeonTrophy,
    dungeonCampfire,
    dungeonAnvil,
    dungeonContractSeal,
    dungeonRansack,
    dungeonScrollSeal,
    dungeonSupplies,
    dungeonWrit,
  ];

  // ---- Aggregates ---------------------------------------------------------

  /// Every guild-hall key an artist can fill.
  static List<AssetKey> get guildHall => [
        ...buildings,
        ...materials,
        ...currencies,
        ...chests,
        ...regions,
        ...heroes,
        ...gearItems,
        ...bosses,
        ...panels,
        ...homesteadStages,
      ];

  /// Every catalogued key: the guild hall plus the dungeon.
  static List<AssetKey> get all => [...guildHall, ...dungeon];
}
