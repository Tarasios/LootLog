/// The shapes of the guild hall's content tables: what a chest, a building, a
/// gear slot, an expedition region and a seasonal boss are made of. The
/// numbers that fill them live in `lib/game/config/balance.dart` and nowhere
/// else.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../domain/time.dart';
import 'game_values.dart';

/// What a chest of one type can roll. Chests are earned only by budgeting, so
/// they may carry gems and streak-freeze tokens; they carry no materials
/// (materials come from buildings, expeditions and the caravan).
class ChestSpec {
  const ChestSpec({
    required this.minGems,
    required this.maxGems,
    required this.tokenChancePermille,
  });

  final int minGems;
  final int maxGems;

  /// The chance (out of 1000) the chest also holds a streak-freeze token.
  final int tokenChancePermille;
}

/// One building kind: what upgrading it costs and what it produces.
class BuildingSpec {
  const BuildingSpec({
    required this.upgradeBase,
    this.freeFirstTier = false,
    this.productionPerHour = const {},
  });

  /// The materials one cost unit of this building takes. Tier `t` costs
  /// `upgradeBase × costMultiplier[t]` plus that tier's gems.
  final MaterialBundle upgradeBase;

  /// Tier 1 costs nothing (the buildings a brand-new hall starts from, before
  /// any material exists).
  final bool freeFirstTier;

  /// Hourly output per material, indexed by tier − 1. Empty for buildings
  /// that produce nothing.
  final Map<MaterialKind, List<int>> productionPerHour;

  bool get isProducer => productionPerHour.isNotEmpty;
}

/// One hero gear slot: the gear types it accepts and its cost unit.
class GearSlotSpec {
  const GearSlotSpec({required this.gearTypes, required this.baseCost});

  /// The gear types the slot accepts (asset subjects, e.g. `sword`).
  final List<String> gearTypes;

  /// The materials one cost unit of gear in this slot takes.
  final MaterialBundle baseCost;
}

/// One possible find on an expedition: [min]..[max] of [kind], found with
/// probability [chancePermille] / 1000.
class LootLine {
  const LootLine(this.kind, this.min, this.max, {this.chancePermille = 1000});

  final MaterialKind kind;
  final int min;
  final int max;
  final int chancePermille;
}

/// An expedition region: how long a trip takes, when it opens, what it finds.
class RegionSpec {
  const RegionSpec({
    required this.durationMinutes,
    required this.minHallTier,
    required this.loot,
  });

  final int durationMinutes;

  /// The Central Hall tier (completed) the region needs; 0 = always open.
  final int minHallTier;
  final List<LootLine> loot;
}

/// The four seasons of the year's boss calendar.
enum Season { winter, spring, summer, autumn }

/// [month]'s season: December–February is winter, and so on.
Season seasonOf(Month month) => Season.values[(month.month % 12) ~/ 3];

/// How far into its season [month] is: 0, 1 or 2 (December is winter's 0).
int monthInSeason(Month month) => (month.month % 12) % 3;

/// A seasonal boss closing the spoils ritual.
class BossSpec {
  const BossSpec({required this.key, required this.baseHp});

  /// Stable id, stored in `BossFightResolved.bossKey` and used as the asset
  /// subject (`boss.<key>.*`).
  final String key;

  /// HP in the season's first month; later months add
  /// `Balance.bossHpPerMonthInSeason` each.
  final int baseHp;
}
