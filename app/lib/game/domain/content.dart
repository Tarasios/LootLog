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

/// One farmland building kind: what building it costs and the food it grows.
class FarmBuildingSpec {
  const FarmBuildingSpec({required this.upgradeBase, this.foodPerHour = const []});

  /// The materials one cost unit takes, scaled per tier like a hall
  /// building's.
  final MaterialBundle upgradeBase;

  /// Food grown per hour, indexed by tier − 1. Empty for a building that
  /// grows nothing (the granary stores it).
  final List<int> foodPerHour;

  bool get growsFood => foodPerHour.isNotEmpty;
}

/// One building of the Guard Post, Residential Quarter, Park or Market Row:
/// its district, what it costs and what it adds to the town. Every list is
/// indexed by tier − 1.
class CivicBuildingSpec {
  const CivicBuildingSpec({
    required this.districtId,
    required this.upgradeBase,
    this.goodsBase = const GoodsBundle.empty(),
    this.housingByTier = const [],
    this.guardsByTier = const [],
    this.prosperityByTier = const [],
    this.unique = false,
  });

  /// The district whose plots it stands on.
  final String districtId;

  /// The materials one cost unit takes, scaled per tier like a hall
  /// building's.
  final MaterialBundle upgradeBase;

  /// The refined goods one goods unit takes, scaled per tier by
  /// `Balance.civicGoodsMultiplierByTier` (tiers below the goods tier cost
  /// none).
  final GoodsBundle goodsBase;

  /// Residents it houses.
  final List<int> housingByTier;

  /// Guard capacity it adds.
  final List<int> guardsByTier;

  /// Prosperity it adds beyond the usual per-tier amount (park buildings
  /// and the guild hall).
  final List<int> prosperityByTier;

  /// Only one may stand in a town.
  final bool unique;

  /// What [list] holds at tier [tier] (0 below tier 1 or past its end).
  static int at(List<int> list, int tier) =>
      tier < 1 || list.isEmpty ? 0 : list[(tier > list.length ? list.length : tier) - 1];
}

/// One Market Row workshop recipe: what a batch takes, what it makes and
/// how long it takes.
class RefiningRecipe {
  const RefiningRecipe({
    required this.input,
    required this.output,
    required this.outputPerBatch,
    required this.minutesPerBatch,
  });

  /// Raw materials one batch takes.
  final MaterialBundle input;

  /// The good it makes, and how many a batch makes.
  final GoodsKind output;
  final int outputPerBatch;

  /// How long one batch takes in the workshop.
  final int minutesPerBatch;
}

/// One stage of the Castle on Castle Hill.
class CastleStageSpec {
  const CastleStageSpec({
    required this.key,
    required this.cost,
    required this.goods,
    required this.buildDays,
    required this.prosperity,
  });

  /// Stable id (`foundation`, `keep`, ...), stored in `CastleStageStarted`
  /// and used in the asset key and reward id.
  final String key;

  /// Gems and materials it takes.
  final Loot cost;

  /// Refined goods it takes.
  final GoodsBundle goods;

  /// How many days the builders work on it.
  final int buildDays;

  /// Prosperity it adds once finished.
  final int prosperity;
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
