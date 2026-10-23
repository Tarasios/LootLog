/// Every tunable balance number for the guild-hall layer lives here and
/// nowhere else (see `README.md`). Pure Dart, zero Flutter imports.
///
/// Rough economy, for whoever tunes this next: an adult who logs daily earns
/// ~5–10 gems a day plus a wood chest and (with a reconcile) an iron chest a
/// week — roughly 60–90 gems a week. Gems buy plots and the top building and
/// gear tiers; everything else is paid in materials, which only buildings,
/// expeditions, the caravan and (trophies) boss wins produce.
library;

import '../domain/content.dart';
import '../domain/game_values.dart';

MaterialBundle _m({
  int lumber = 0,
  int stone = 0,
  int ore = 0,
  int herbs = 0,
  int hide = 0,
  int crystal = 0,
  int essence = 0,
  int trophy = 0,
}) =>
    MaterialBundle({
      MaterialKind.lumber: lumber,
      MaterialKind.stone: stone,
      MaterialKind.ore: ore,
      MaterialKind.herbs: herbs,
      MaterialKind.hide: hide,
      MaterialKind.crystal: crystal,
      MaterialKind.essence: essence,
      MaterialKind.trophy: trophy,
    });

/// Guild-hall balance numbers.
abstract final class Balance {
  // ---- Reward engine ------------------------------------------------------

  /// The gem pouch for a person's first active-day event of a day.
  static const int activeDayPouchGems = 5;

  /// Gems for each further purchase logged that day.
  static const int extraLogGems = 1;

  /// Gems for logging a purchase within [timelyWindow] of when it happened.
  static const int timelyBonusGems = 1;
  static const Duration timelyWindow = Duration(hours: 24);

  /// The most further-purchase and timely grants per person per day (the
  /// pouch is outside the cap). The anti-spam measure.
  static const int dailyGemCap = 5;

  /// Active days within one Monday-to-Sunday week that earn the wood chest.
  static const int weeklyCheckInActiveDays = 4;

  /// Gems that come with the iron chest for a completed weekly reconcile.
  static const int weeklyReconcileGems = 10;

  /// Streak length that earns each freeze token.
  static const int streakDaysPerFreezeToken = 7;

  /// The most freeze tokens a person holds at once (claimed or waiting).
  static const int maxFreezeTokens = 3;

  /// What a Standard-mode adult's active day sends to the party pool.
  static final MaterialBundle caravanMaterials =
      MaterialBundle({MaterialKind.lumber: 2, MaterialKind.stone: 1});

  /// How many days back activity is still rewarded. Bounds the catch-up when
  /// the game first runs over an existing ledger, while still rewarding a
  /// partner whose device was offline for a few days.
  static const int rewardLookbackDays = 7;

  // ---- Chests -------------------------------------------------------------

  /// What each chest rolls when opened. Every chest is earned by budgeting
  /// (rule 9), so chests hold gems and the odd freeze token — never
  /// materials, which stay the product of buildings, expeditions and the
  /// caravan. Rarer chests roll richer: wood (weekly check-in) < party <
  /// iron (weekly reconcile) < gold (a category under budget) < spoils (the
  /// month-end ritual, the biggest habit of all).
  static const Map<ChestType, ChestSpec> chests = {
    ChestType.wood: ChestSpec(minGems: 8, maxGems: 15, tokenChancePermille: 50),
    ChestType.party:
        ChestSpec(minGems: 10, maxGems: 18, tokenChancePermille: 100),
    ChestType.iron:
        ChestSpec(minGems: 15, maxGems: 25, tokenChancePermille: 100),
    ChestType.gold:
        ChestSpec(minGems: 20, maxGems: 35, tokenChancePermille: 150),
    ChestType.spoils:
        ChestSpec(minGems: 30, maxGems: 50, tokenChancePermille: 250),
  };

  /// Gems a chest's freeze token turns into when the person already holds
  /// [maxFreezeTokens]: a full pouch never wastes a find.
  static const int tokenOverflowGems = 5;

  // ---- Decorations from chests and milestones ---------------------------------

  /// Chance (per mille) that a chest holds a decoration. The month-end spoils
  /// chest always does.
  static const Map<ChestType, int> chestDecorChancePermille = {
    ChestType.wood: 350,
    ChestType.party: 450,
    ChestType.iron: 500,
    ChestType.gold: 650,
    ChestType.spoils: 1000,
  };

  /// Of a decoration drop: chance it is rare, then chance it is uncommon;
  /// otherwise it is common.
  static const Map<ChestType, int> chestRareChancePermille = {
    ChestType.wood: 20,
    ChestType.party: 40,
    ChestType.iron: 50,
    ChestType.gold: 100,
    ChestType.spoils: 150,
  };
  static const Map<ChestType, int> chestUncommonChancePermille = {
    ChestType.wood: 200,
    ChestType.party: 300,
    ChestType.iron: 300,
    ChestType.gold: 400,
    ChestType.spoils: 450,
  };

  /// Gems a duplicate decoration turns into, so no drop is ever wasted.
  static const int duplicateDecorGems = 5;

  /// Consecutive active days that unlock a title and an exclusive decoration.
  static const List<int> streakMilestoneDays = [7, 30, 100];

  static const Map<int, List<String>> streakMilestoneItemIds = {
    7: ['streak_7_title', 'streak_7_item'],
    30: ['streak_30_title', 'streak_30_item'],
    100: ['streak_100_title', 'streak_100_item'],
  };

  // ---- Plots --------------------------------------------------------------

  /// Hall plots unlocked before any `PlotUnlocked` event (indices
  /// `0 .. startingPlotCount - 1`).
  static const int startingPlotCount = 3;

  /// The most plots a hall can have: one for every building type.
  static const int maxPlots = 11;

  /// Gems to unlock plots `startingPlotCount ..< maxPlots`, in index order.
  /// Gentle at first (a week of logging buys the fourth plot), steeper later.
  static const List<int> plotUnlockGems = [20, 30, 40, 55, 70, 90, 110, 135];

  /// The gem cost of unlocking plot [index], or null if it cannot be
  /// unlocked (a starting plot, or beyond [maxPlots]).
  static int? plotUnlockCost(int index) {
    final i = index - startingPlotCount;
    if (i < 0 || i >= plotUnlockGems.length) return null;
    return plotUnlockGems[i];
  }

  // ---- Buildings ----------------------------------------------------------

  /// Every building tops out at tier 5.
  static const int maxBuildingTier = 5;

  /// How long construction to each tier takes (index tier − 1): t1 instant,
  /// t2 1h, t3 4h, t4–t5 12h.
  static const List<Duration> buildTimeByTier = [
    Duration.zero,
    Duration(hours: 1),
    Duration(hours: 4),
    Duration(hours: 12),
    Duration(hours: 12),
  ];

  /// Material cost multiplier per tier (index tier − 1), applied to a
  /// building's `upgradeBase`.
  static const List<int> buildingCostMultiplierByTier = [1, 3, 7, 14, 25];

  /// Gems per tier (index tier − 1): the top tiers want a little budgeting
  /// too, so the hall grows with the habit, not just with idle time.
  static const List<int> buildingGemCostByTier = [0, 0, 15, 35, 70];

  /// Each building's cost unit and output. Lumberyard and Quarry are free at
  /// tier 1 so a brand-new hall can bootstrap materials; the Central Hall and
  /// Scribe's Desk are free at tier 1 because they are the hall's front door
  /// and the way into the ledger (the UI must never gate the ledger on them).
  /// Producers make one material each, except the Arcane Well (crystal and
  /// essence). Rates are per hour, index tier − 1; a tier-1 Lumberyard fills
  /// an empty yard in about a day, so checking in once a day is plenty.
  static final Map<BuildingType, BuildingSpec> buildings = {
    BuildingType.centralHall: BuildingSpec(
      upgradeBase: _m(lumber: 20, stone: 20),
      freeFirstTier: true,
    ),
    BuildingType.scribesDesk: BuildingSpec(
      upgradeBase: _m(lumber: 15, herbs: 5),
      freeFirstTier: true,
    ),
    BuildingType.storehouse: BuildingSpec(
      upgradeBase: _m(lumber: 25, stone: 15),
    ),
    BuildingType.forge: BuildingSpec(
      upgradeBase: _m(stone: 20, ore: 15),
    ),
    BuildingType.vault: BuildingSpec(
      upgradeBase: _m(stone: 25, ore: 10),
    ),
    BuildingType.lumberyard: BuildingSpec(
      upgradeBase: _m(lumber: 15, stone: 5),
      freeFirstTier: true,
      productionPerHour: const {
        MaterialKind.lumber: [6, 10, 15, 21, 28],
      },
    ),
    BuildingType.quarry: BuildingSpec(
      upgradeBase: _m(lumber: 10, stone: 10),
      freeFirstTier: true,
      productionPerHour: const {
        MaterialKind.stone: [5, 9, 13, 18, 24],
      },
    ),
    BuildingType.mine: BuildingSpec(
      upgradeBase: _m(lumber: 20, stone: 10),
      productionPerHour: const {
        MaterialKind.ore: [3, 6, 9, 13, 17],
      },
    ),
    BuildingType.herbGarden: BuildingSpec(
      upgradeBase: _m(lumber: 15, stone: 5),
      productionPerHour: const {
        MaterialKind.herbs: [3, 6, 9, 13, 17],
      },
    ),
    BuildingType.huntersLodge: BuildingSpec(
      upgradeBase: _m(lumber: 20, herbs: 5),
      productionPerHour: const {
        MaterialKind.hide: [3, 6, 9, 13, 17],
      },
    ),
    BuildingType.arcaneWell: BuildingSpec(
      upgradeBase: _m(stone: 30, ore: 15, herbs: 10),
      productionPerHour: const {
        MaterialKind.crystal: [1, 2, 3, 5, 7],
        MaterialKind.essence: [1, 1, 2, 3, 4],
      },
    ),
  };

  /// What building [type] to [tier] costs.
  static Loot buildingCost(BuildingType type, int tier) {
    final spec = buildings[type]!;
    if (tier == 1 && spec.freeFirstTier) return Loot.none;
    return Loot(
      gems: buildingGemCostByTier[tier - 1],
      materials: spec.upgradeBase.scaled(buildingCostMultiplierByTier[tier - 1]),
    );
  }

  /// The highest tier other buildings may reach while the hall has no
  /// (completed) Central Hall. With one, they may reach its tier.
  static const int maxTierWithoutCentralHall = 1;

  /// How much of each material the shared pool holds, by completed
  /// Storehouse tier (index 0 = no Storehouse). Also caps what a building's
  /// uncollected production can bank in one collection.
  static const List<int> storehouseCapacityByTier = [
    150,
    300,
    600,
    1000,
    1800,
    3000,
  ];

  /// Materials the Storehouse never caps: trophies are mementos of boss
  /// wins, kept on the mantel rather than in the yard.
  static const Set<MaterialKind> uncappedMaterials = {MaterialKind.trophy};

  // ---- Hero gear ----------------------------------------------------------

  /// Gear tops out at tier 5, and never above the Forge's completed tier
  /// (no Forge, no gear).
  static const int maxGearTier = 5;

  /// Material cost multiplier per gear tier (index tier − 1).
  static const List<int> gearCostMultiplierByTier = [1, 3, 7, 14, 25];

  /// Gems per gear tier (index tier − 1).
  static const List<int> gearGemCostByTier = [0, 0, 10, 25, 50];

  /// The three gear slots, the types each accepts, and their cost units:
  /// weapons want ore, armour hide, trinkets herbs. Every tier of gear a hero
  /// wears adds to their power on expeditions and against the boss.
  static final Map<String, GearSlotSpec> gearSlots = {
    'weapon': GearSlotSpec(
      gearTypes: const ['sword', 'bow', 'staff'],
      baseCost: _m(ore: 10, lumber: 5),
    ),
    'armor': GearSlotSpec(
      gearTypes: const ['mail', 'leather', 'robe'],
      baseCost: _m(hide: 10, ore: 5),
    ),
    'trinket': GearSlotSpec(
      gearTypes: const ['amulet', 'ring', 'lantern'],
      baseCost: _m(herbs: 8, hide: 4),
    ),
  };

  /// What gear for [slot] at [tier] costs.
  static Loot gearCost(String slot, int tier) => Loot(
        gems: gearGemCostByTier[tier - 1],
        materials:
            gearSlots[slot]!.baseCost.scaled(gearCostMultiplierByTier[tier - 1]),
      );

  /// Longest hero cosmetic field name and value (`HeroCustomized`), so a
  /// stray paste can't bloat the synced log.
  static const int maxCosmeticFieldLength = 32;
  static const int maxCosmeticValueLength = 64;

  // ---- Expeditions --------------------------------------------------------

  /// Extra expedition loot per tier of gear the hero wears, in permille
  /// (40 = +4%; a fully geared hero brings home +60%).
  static const int lootBonusPermillePerGearTier = 40;

  /// The regions, themed on everyday spending: short trips to the Market
  /// Catacombs (groceries) and Tavern Cellars (eating out) are open from the
  /// start; the Old Roads (transport), Hearthstone Keep (home), Bazaar of
  /// Whims (impulse buys), Subscription Swamp and The Wilds open as the
  /// Central Hall grows. Longer trips find more and rarer materials.
  static const Map<ExpeditionRegion, RegionSpec> regions = {
    ExpeditionRegion.marketCatacombs: RegionSpec(
      durationMinutes: 30,
      minHallTier: 0,
      loot: [
        LootLine(MaterialKind.herbs, 4, 8),
        LootLine(MaterialKind.hide, 1, 3, chancePermille: 600),
      ],
    ),
    ExpeditionRegion.tavernCellars: RegionSpec(
      durationMinutes: 60,
      minHallTier: 0,
      loot: [
        LootLine(MaterialKind.lumber, 4, 8),
        LootLine(MaterialKind.herbs, 3, 6),
        LootLine(MaterialKind.essence, 1, 2, chancePermille: 250),
      ],
    ),
    ExpeditionRegion.oldRoads: RegionSpec(
      durationMinutes: 120,
      minHallTier: 1,
      loot: [
        LootLine(MaterialKind.stone, 6, 12),
        LootLine(MaterialKind.ore, 2, 5, chancePermille: 800),
      ],
    ),
    ExpeditionRegion.hearthstoneKeep: RegionSpec(
      durationMinutes: 240,
      minHallTier: 2,
      loot: [
        LootLine(MaterialKind.stone, 10, 18),
        LootLine(MaterialKind.lumber, 10, 18),
        LootLine(MaterialKind.ore, 3, 6, chancePermille: 500),
      ],
    ),
    ExpeditionRegion.bazaarOfWhims: RegionSpec(
      durationMinutes: 240,
      minHallTier: 2,
      loot: [
        LootLine(MaterialKind.hide, 4, 8),
        LootLine(MaterialKind.crystal, 1, 3, chancePermille: 700),
        LootLine(MaterialKind.essence, 1, 2, chancePermille: 300),
      ],
    ),
    ExpeditionRegion.subscriptionSwamp: RegionSpec(
      durationMinutes: 480,
      minHallTier: 3,
      loot: [
        LootLine(MaterialKind.herbs, 6, 10),
        LootLine(MaterialKind.essence, 2, 4),
        LootLine(MaterialKind.crystal, 1, 3),
      ],
    ),
    ExpeditionRegion.theWilds: RegionSpec(
      durationMinutes: 720,
      minHallTier: 4,
      loot: [
        LootLine(MaterialKind.lumber, 12, 20),
        LootLine(MaterialKind.hide, 10, 16),
        LootLine(MaterialKind.ore, 5, 9),
        LootLine(MaterialKind.crystal, 2, 4, chancePermille: 400),
      ],
    ),
  };

  // ---- Spoils ritual and the seasonal boss ---------------------------------

  /// How many closed months back a ritual can still be started: last month
  /// and the one before, so a busy start to the month never loses a ritual.
  static const int ritualOpenMonths = 2;

  /// One boss per season; HP grows by [bossHpPerMonthInSeason] each month
  /// into the season. Tuned so a hero with no gear who logged every day of
  /// the month wins a little under half the time, each gear tier tilts it
  /// further, and a well-geared hero always wins. Losing costs nothing: the
  /// spoils chest comes either way.
  static const Map<Season, BossSpec> bosses = {
    Season.winter: BossSpec(key: 'frostWyrm', baseHp: 150),
    Season.spring: BossSpec(key: 'thawHydra', baseHp: 130),
    Season.summer: BossSpec(key: 'sunDrake', baseHp: 140),
    Season.autumn: BossSpec(key: 'harvestLich', baseHp: 145),
  };
  static const int bossHpPerMonthInSeason = 10;

  /// The fight lasts at most this many rounds.
  static const int bossMaxTurns = 6;

  /// A hero's damage per round: base + per gear tier + a bonus for how
  /// completely the month was logged (up to [bossLoggingBonusMax] for every
  /// day) + a random 0..[bossAttackVariance].
  static const int heroBaseAttack = 12;
  static const int heroAttackPerGearTier = 1;
  static const int bossLoggingBonusMax = 8;
  static const int bossAttackVariance = 8;

  /// What felling the boss adds (the spoils chest comes win or lose: the
  /// ritual is what earns it, never the fight's outcome).
  static final Loot bossWinRewards = Loot(materials: _m(trophy: 1));

  // ---- Month-end ritual bonus (cosmetic loot only) ---------------------------

  /// Gems per consecutive on-time month-end ritual, capped.
  static const int ritualBonusGemsPerOnTimeMonth = 3;
  static const int ritualBonusMaxOnTimeMonths = 6;

  /// Gems per point of hero gear power.
  static const int ritualBonusGemsPerHeroPower = 1;

  // ---- Month-end and Vault rewards -----------------------------------------

  /// How many closed months back month-end rewards are still granted
  /// (bounds the catch-up over an existing ledger).
  static const int monthEndLookbackMonths = 2;

  /// The gold chest is a bonus for a personal category that ended a closed
  /// month at or under its limit — but only for someone who logged on at
  /// least this many days that month, so not logging never looks like
  /// staying under budget.
  static const int goldChestMinLoggedDays = 10;

  /// Vault milestones for a savings quest (percent of goal → gems). Rule 8:
  /// progress is measured as a share of the goal, never in dollars.
  static const Map<int, int> questMilestoneGems = {
    25: 5,
    50: 10,
    75: 15,
    100: 30,
  };

  /// Vault milestones for consecutive closed months with a savings
  /// allocation (months → gems): consistency, not amounts.
  static const Map<int, int> savingsStreakGems = {
    3: 15,
    6: 30,
    12: 60,
  };

  // ---- Daily shop -----------------------------------------------------------

  /// Items in the daily shop.
  static const int shopSlotCount = 6;

  /// The first slot always holds an item at or under this price, so there is
  /// a small win every day.
  static const int shopCheapMaxPriceGems = 10;
}
