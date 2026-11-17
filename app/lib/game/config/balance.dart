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

GoodsBundle _g({int planks = 0, int cutStone = 0, int tools = 0, int cloth = 0}) =>
    GoodsBundle({
      GoodsKind.planks: planks,
      GoodsKind.cutStone: cutStone,
      GoodsKind.tools: tools,
      GoodsKind.cloth: cloth,
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

  /// What a Standard-mode adult's active day sends down the trade road to
  /// each Adventure adult who was active the same day (the supply caravan).
  static final MaterialBundle caravanTradeBundle =
      MaterialBundle({MaterialKind.lumber: 2, MaterialKind.stone: 1});

  /// How many days back activity is still rewarded. Bounds the catch-up when
  /// the game first runs over an existing ledger, while still rewarding a
  /// partner whose device was offline for a few days.
  static const int rewardLookbackDays = 7;

  // ---- Daily town events ---------------------------------------------------

  /// How likely each daily event is when a person opens their day (out of
  /// the total). A windfall needs a producer; without one the roll is among
  /// the others.
  static const Map<DailyEventKind, int> dailyEventWeights = {
    DailyEventKind.trader: 40,
    DailyEventKind.windfall: 40,
    DailyEventKind.visitor: 20,
  };

  /// A windfall is this many hours of one producer's current-tier output.
  static const int windfallHours = 4;

  /// What a trader asks for (of the pool's most plentiful material) and
  /// hands back (of its scarcest), by completed Central Hall tier (index 0 =
  /// none). Fewer back than asked: the trader brings what the hall lacks.
  static const List<int> traderGiveByHallTier = [20, 30, 45, 60, 80, 100];
  static const List<int> traderReceiveByHallTier = [8, 12, 18, 24, 32, 40];

  static int traderGiveAmount(int hallTier) =>
      traderGiveByHallTier[hallTier.clamp(0, traderGiveByHallTier.length - 1)];
  static int traderReceiveAmount(int hallTier) => traderReceiveByHallTier[
      hallTier.clamp(0, traderReceiveByHallTier.length - 1)];

  /// The materials a trader deals in: everything the Storehouse holds.
  static const List<MaterialKind> tradeMaterials = [
    MaterialKind.lumber,
    MaterialKind.stone,
    MaterialKind.ore,
    MaterialKind.herbs,
    MaterialKind.hide,
    MaterialKind.crystal,
    MaterialKind.essence,
  ];

  /// A visitor's gift: [visitorGift] of one of [visitorGiftMaterials], or,
  /// [visitorGemChancePermille] of the time, [visitorGiftGems] gems.
  static const int visitorGift = 5;
  static const List<MaterialKind> visitorGiftMaterials = [
    MaterialKind.lumber,
    MaterialKind.stone,
    MaterialKind.ore,
    MaterialKind.herbs,
    MaterialKind.hide,
  ];
  static const int visitorGemChancePermille = 200;
  static const int visitorGiftGems = 2;

  // ---- Town spirit and the weekend festival --------------------------------

  /// Weekdays logged (Monday to Friday) at or above which the weekend
  /// festival is a fair, and a grand festival. Below [festivalFairWeekdays]
  /// it is a market day — there is always a festival.
  static const int festivalFairWeekdays = 3;
  static const int festivalGrandWeekdays = 5;

  /// What each festival brings (a grand festival also brings one festival
  /// decoration when the catalogue has any).
  static final Map<FestivalTier, Loot> festivalRewards = {
    FestivalTier.marketDay: const Loot(gems: 2),
    FestivalTier.fair: Loot(gems: 6, materials: _m(lumber: 10, stone: 10)),
    FestivalTier.grandFestival:
        Loot(gems: 12, materials: _m(lumber: 20, stone: 20, herbs: 10)),
  };

  /// Gems each Adventure adult at a fair or better gets when at least one
  /// other Adventure adult reached a fair or better the same week. Additive:
  /// nothing is lost when alone.
  static const int jointFestivalGems = 4;

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

  /// The working shift: on a household day the town's own adult logged a
  /// purchase or checked in (freeze-covered days do not count), producers
  /// work the full
  /// day — 24 or more means the whole calendar day, 23 or 25 hours on a
  /// daylight-saving change.
  static const int fullShiftHours = 24;

  /// On any other day producers work only the first hours of the day, like
  /// an idle game's offline cap. Production never stops and nothing already
  /// made is ever lost; logging just keeps the crews on the full day.
  static const int shortShiftHours = 8;

  /// Materials the Storehouse never caps: trophies are mementos of boss
  /// wins, kept on the mantel rather than in the yard.
  static const Set<MaterialKind> uncappedMaterials = {MaterialKind.trophy};

  // ---- Neighbouring towns ---------------------------------------------------

  /// What a neighbour's new town starts with when the shared town is split
  /// (the old shared town goes, whole, to the adult who built most of it).
  static final MaterialBundle welcomeGrant =
      MaterialBundle({MaterialKind.lumber: 40, MaterialKind.stone: 40});

  /// How much one tap of a gift dialog's stepper adds or takes away (the last
  /// step stops at what you hold or what the neighbour has room for).
  static const int giftStepAmount = 10;

  /// What a neighbour's trade caravan brings on a day both of you were
  /// active, by the tier in service of the neighbour's busiest producer
  /// (index 0 = no producer yet). Generated, never taken from them.
  static const List<int> tradeRoadAmountByTier = [3, 4, 6, 9, 13, 18];

  static int tradeRoadAmount(int producerTier) => tradeRoadAmountByTier[
      producerTier.clamp(0, tradeRoadAmountByTier.length - 1)];

  /// What a neighbour with no producer yet sends down the trade road.
  static const MaterialKind tradeRoadFallbackMaterial = MaterialKind.lumber;

  // ---- Town growth: prosperity and tiers ------------------------------------
  //
  // Pace targets for an adult who logs daily and collects once a day (held
  // by `test/game/domain/town/growth_pace_test.dart`): a build or upgrade
  // most days in the first two weeks, the Hamlet within the first week, the
  // Farmland affordable shortly after, the Village in about a month (it needs
  // farms). Town and City are held by `long_road_pace_test.dart` (see the
  // long road section below).

  /// Prosperity per completed building tier, in every district: the town's
  /// growth is mostly what has been built.
  static const int prosperityPerBuildingTier = 10;

  /// Prosperity per district bought beyond the outpost.
  static const int prosperityPerDistrict = 40;

  /// Prosperity per town decoration on display, for up to
  /// [prosperityDecorationCap] of them: a garden helps, a hoard does not.
  static const int prosperityPerDecoration = 5;
  static const int prosperityDecorationCap = 10;

  /// Prosperity per weekend festival held (every week someone shows up).
  static const int prosperityPerFestival = 15;

  /// The peak prosperity each tier needs. Going past the Hamlet also needs
  /// food in store (see the food numbers below), and the Town and City need
  /// houses ([housingForTier]). The Town's 1150 is about four months of a
  /// daily player's building (simulated: day ~122); the City's 2100 needs
  /// the Park and Market Row built up and lands in month 8–9 (day ~262),
  /// which leaves the Castle's stages for the months after.
  static const Map<TownTier, int> tierProsperity = {
    TownTier.outpost: 0,
    TownTier.hamlet: 80,
    TownTier.village: 450,
    TownTier.town: 1150,
    TownTier.city: 2100,
  };

  /// What reaching each tier brings, claimed through the inbox: gems and a
  /// chest-sized bundle of building materials.
  static final Map<TownTier, Loot> tierRewards = {
    TownTier.hamlet: Loot(gems: 20, materials: _m(lumber: 60, stone: 60)),
    TownTier.village:
        Loot(gems: 40, materials: _m(lumber: 120, stone: 120, ore: 40)),
    TownTier.town: Loot(
        gems: 80, materials: _m(lumber: 250, stone: 250, ore: 100, herbs: 60)),
    TownTier.city: Loot(
        gems: 150,
        materials: _m(lumber: 500, stone: 500, ore: 200, crystal: 40)),
  };

  /// The daily cap on further-purchase and timely gems, by tier: it rises
  /// gently, so a bigger town earns a little more from the same habit.
  static const Map<TownTier, int> dailyGemCapByTier = {
    TownTier.outpost: dailyGemCap,
    TownTier.hamlet: 6,
    TownTier.village: 7,
    TownTier.town: 8,
    TownTier.city: 10,
  };

  static int dailyGemCapFor(TownTier tier) =>
      dailyGemCapByTier[tier] ?? dailyGemCap;

  // ---- Districts, farms and food ---------------------------------------------

  /// The farmland district (opens at the hamlet): a few days of gems after
  /// the hamlet's own reward, and stores a tier-2 Storehouse-less town can
  /// hold, so it is affordable shortly after the hamlet.
  static const int farmlandGemPrice = 40;
  static const Map<MaterialKind, int> farmlandMaterialPrice = {
    MaterialKind.lumber: 120,
    MaterialKind.stone: 80,
  };
  static const int farmlandPlotCount = 6;

  /// The farmland's buildings. Farms are cheap and steady; orchards grow
  /// more for herbs; the granary grows nothing and stores more food. Tiers
  /// cost like hall buildings ([buildingCostMultiplierByTier],
  /// [buildingGemCostByTier]) and take [buildTimeByTier].
  static final Map<FarmBuildingType, FarmBuildingSpec> farmBuildings = {
    FarmBuildingType.farm: FarmBuildingSpec(
      upgradeBase: _m(lumber: 20, stone: 10),
      foodPerHour: const [2, 4, 6, 9, 12],
    ),
    FarmBuildingType.orchard: FarmBuildingSpec(
      upgradeBase: _m(lumber: 25, herbs: 10),
      foodPerHour: const [3, 5, 8, 11, 15],
    ),
    FarmBuildingType.granary: FarmBuildingSpec(
      upgradeBase: _m(lumber: 30, stone: 30),
    ),
  };

  /// What farmland building [type] to [tier] costs.
  static Loot farmBuildingCost(FarmBuildingType type, int tier) => Loot(
        gems: buildingGemCostByTier[tier - 1],
        materials: farmBuildings[type]!
            .upgradeBase
            .scaled(buildingCostMultiplierByTier[tier - 1]),
      );

  /// Food a town can store, by completed granary tier (index 0 = none).
  /// Without a granary it holds a few days of a hamlet's need; a village's
  /// stores want a granary.
  static const List<int> granaryFoodCapacityByTier = [
    120,
    300,
    600,
    1200,
    2400,
    4800,
  ];

  /// Residents by tier (houses add more in a later stage).
  static const Map<TownTier, int> populationByTier = {
    TownTier.outpost: 4,
    TownTier.hamlet: 10,
    TownTier.village: 25,
    TownTier.town: 60,
    TownTier.city: 150,
  };

  /// Food each resident eats a day, by tier: a bigger town eats richer, so
  /// the need steepens faster than the population.
  static const Map<TownTier, int> foodPerResident = {
    TownTier.outpost: 1,
    TownTier.hamlet: 1,
    TownTier.village: 2,
    TownTier.town: 3,
    TownTier.city: 4,
  };

  /// A town is food-secure with this many days of its need in store, and
  /// only a food-secure town grows past the hamlet. A short town loses
  /// nothing: it only waits.
  static const int foodSecureDays = 3;

  // ---- The long road: guard post, residential quarter, park, market row ------
  //
  // Pace targets for an adult who logs daily and collects once a day (held
  // by `test/game/domain/town/long_road_pace_test.dart`, 400 simulated days
  // through the real engine and commands): Village about day 30, Town in
  // month 4 (day 90–150), City in month 7–10 (day 200–300), the first
  // Castle stage soon after, and the finished Castle after a year. A player
  // who logs four days a week still reaches Town before day 220.

  /// The Guard Post (opens at the village): about a week of a village's
  /// gems and stores. Its buildings add guard capacity for farms past the first
  /// [unguardedFarmPlots].
  static const int guardPostGemPrice = 80;
  static const Map<MaterialKind, int> guardPostMaterialPrice = {
    MaterialKind.lumber: 300,
    MaterialKind.stone: 300,
  };
  static const int guardPostPlotCount = 4;

  /// The Residential Quarter (opens at the village): its houses hold the
  /// residents a town and a city need ([housingForTier]).
  static const int residentialGemPrice = 80;
  static const Map<MaterialKind, int> residentialMaterialPrice = {
    MaterialKind.lumber: 400,
    MaterialKind.stone: 200,
  };
  static const int residentialPlotCount = 6;

  /// The Park (opens at the town): prosperity and a happier festival.
  static const int parkGemPrice = 150;
  static const Map<MaterialKind, int> parkMaterialPrice = {
    MaterialKind.lumber: 600,
    MaterialKind.stone: 600,
    MaterialKind.herbs: 200,
  };
  static const int parkPlotCount = 4;

  /// Market Row (opens at the town): the market trade and the workshops
  /// that refine goods for the Castle and the top tiers.
  static const int marketRowGemPrice = 150;
  static const Map<MaterialKind, int> marketRowMaterialPrice = {
    MaterialKind.lumber: 600,
    MaterialKind.stone: 600,
    MaterialKind.ore: 200,
  };
  static const int marketRowPlotCount = 5;

  /// The civic buildings. Tiers cost like hall buildings
  /// ([buildingCostMultiplierByTier], [buildingGemCostByTier], built in
  /// [buildTimeByTier]); from [civicGoodsFromTier] on they also want refined
  /// goods, so the top tiers come with the Market Row.
  static final Map<CivicBuildingType, CivicBuildingSpec> civicBuildings = {
    CivicBuildingType.watchtower: CivicBuildingSpec(
      districtId: 'guardPost',
      upgradeBase: _m(lumber: 30, stone: 30),
      goodsBase: _g(planks: 10),
      guardsByTier: const [2, 4, 6, 8, 10],
    ),
    CivicBuildingType.barracks: CivicBuildingSpec(
      districtId: 'guardPost',
      upgradeBase: _m(lumber: 40, ore: 20),
      goodsBase: _g(tools: 5),
      guardsByTier: const [3, 6, 9, 12, 15],
      unique: true,
    ),
    CivicBuildingType.wallSection: CivicBuildingSpec(
      districtId: 'guardPost',
      upgradeBase: _m(stone: 50),
      goodsBase: _g(cutStone: 10),
      guardsByTier: const [1, 2, 3, 4, 5],
    ),
    CivicBuildingType.cottage: CivicBuildingSpec(
      districtId: 'residential',
      upgradeBase: _m(lumber: 30, stone: 15),
      goodsBase: _g(planks: 10),
      housingByTier: const [4, 8, 13, 19, 26],
    ),
    CivicBuildingType.rowhouse: CivicBuildingSpec(
      districtId: 'residential',
      upgradeBase: _m(lumber: 40, stone: 40),
      goodsBase: _g(planks: 10, cutStone: 10),
      housingByTier: const [8, 16, 24, 34, 45],
    ),
    CivicBuildingType.well: CivicBuildingSpec(
      districtId: 'residential',
      upgradeBase: _m(stone: 30),
      goodsBase: _g(cutStone: 10),
      housingByTier: const [2, 4, 6, 8, 10],
      unique: true,
    ),
    CivicBuildingType.garden: CivicBuildingSpec(
      districtId: 'park',
      upgradeBase: _m(lumber: 20, herbs: 20),
      goodsBase: _g(planks: 5),
      prosperityByTier: const [5, 10, 15, 20, 25],
    ),
    CivicBuildingType.bandstand: CivicBuildingSpec(
      districtId: 'park',
      upgradeBase: _m(lumber: 40, ore: 10),
      goodsBase: _g(planks: 10, cloth: 5),
      prosperityByTier: const [10, 20, 30, 40, 50],
      unique: true,
    ),
    CivicBuildingType.fountain: CivicBuildingSpec(
      districtId: 'park',
      upgradeBase: _m(stone: 50, crystal: 5),
      goodsBase: _g(cutStone: 10),
      prosperityByTier: const [8, 16, 24, 32, 40],
    ),
    CivicBuildingType.stall: CivicBuildingSpec(
      districtId: 'marketRow',
      upgradeBase: _m(lumber: 30, hide: 10),
      goodsBase: _g(cloth: 5),
    ),
    CivicBuildingType.workshop: CivicBuildingSpec(
      districtId: 'marketRow',
      upgradeBase: _m(lumber: 40, stone: 40, ore: 10),
      goodsBase: _g(tools: 5),
    ),
    CivicBuildingType.guildHall: CivicBuildingSpec(
      districtId: 'marketRow',
      upgradeBase: _m(stone: 60, ore: 30, crystal: 10),
      goodsBase: _g(tools: 5, cloth: 5),
      prosperityByTier: const [15, 30, 45, 60, 75],
      unique: true,
    ),
  };

  /// Gems per civic tier (index tier − 1): lighter than a hall building's,
  /// since by the village gems are what everything wants and the stores
  /// overflow; the materials and goods carry the cost instead.
  static const List<int> civicGemCostByTier = [0, 0, 5, 15, 30];

  /// Civic tiers from this one on want goods: `goodsBase ×`
  /// [civicGoodsMultiplierByTier] (index tier − 1).
  static const int civicGoodsFromTier = 3;
  static const List<int> civicGoodsMultiplierByTier = [0, 0, 1, 2, 4];

  /// What civic building [type] to [tier] costs, and the goods it wants.
  static ({Loot cost, GoodsBundle goods}) civicBuildingCost(CivicBuildingType type, int tier) {
    final spec = civicBuildings[type]!;
    return (
      cost: Loot(
        gems: civicGemCostByTier[tier - 1],
        materials: spec.upgradeBase.scaled(buildingCostMultiplierByTier[tier - 1]),
      ),
      goods: tier < civicGoodsFromTier
          ? const GoodsBundle.empty()
          : spec.goodsBase.scaled(civicGoodsMultiplierByTier[tier - 1]),
    );
  }

  /// Housing a town needs (beyond the residents of its tier) to grow into
  /// each tier: houses for the people a town and a city draw in. A tier not
  /// listed needs none. 40 is a few cottages raised to tier 2; 120 wants the
  /// quarter's six plots near tier 3, which goods (Market Row) unlock.
  static const Map<TownTier, int> housingForTier = {
    TownTier.town: 40,
    TownTier.city: 120,
  };

  /// Farm plots that work with no guards at all; each farm plot past them
  /// needs [guardsPerFarmPlot] guard capacity, or its farm rests (it keeps
  /// its building and grows again once guarded). A tier-1 watchtower guards
  /// the farmland's last two fields, so the Guard Post is the village's
  /// first step.
  static const int unguardedFarmPlots = 4;
  static const int guardsPerFarmPlot = 2;

  /// The farmland's plots by town tier: more fields open at the town and
  /// the city.
  static const Map<TownTier, int> farmlandPlotsByTier = {
    TownTier.outpost: farmlandPlotCount,
    TownTier.hamlet: farmlandPlotCount,
    TownTier.village: farmlandPlotCount,
    TownTier.town: 9,
    TownTier.city: 12,
  };

  /// The market trade: on a day the town's adult logged, a town with a stall
  /// in service gets one extra trader offer: a little richer than the daily
  /// trader, so the stall is worth raising. What the trader asks for and
  /// hands back, by the best stall tier in service (index 0 = none).
  static const List<int> marketGiveByStallTier = [0, 30, 45, 60, 80, 100];
  static const List<int> marketReceiveByStallTier = [0, 15, 24, 33, 45, 60];

  // ---- Refined goods ---------------------------------------------------------

  /// The workshop recipes by id: planks from lumber, cut stone from stone,
  /// tools from ore and lumber, cloth from hide and herbs. Five raw
  /// materials make one good (the stores overflow by the town, so goods are
  /// where the surplus goes); tools and cloth take twice as long.
  static final Map<String, RefiningRecipe> refiningRecipes = {
    'planks': RefiningRecipe(
      input: _m(lumber: 10),
      output: GoodsKind.planks,
      outputPerBatch: 2,
      minutesPerBatch: 30,
    ),
    'cutStone': RefiningRecipe(
      input: _m(stone: 10),
      output: GoodsKind.cutStone,
      outputPerBatch: 2,
      minutesPerBatch: 30,
    ),
    'tools': RefiningRecipe(
      input: _m(ore: 6, lumber: 4),
      output: GoodsKind.tools,
      outputPerBatch: 1,
      minutesPerBatch: 60,
    ),
    'cloth': RefiningRecipe(
      input: _m(hide: 6, herbs: 4),
      output: GoodsKind.cloth,
      outputPerBatch: 1,
      minutesPerBatch: 60,
    ),
  };

  /// The most batches one job may hold, by the workshop's tier in service
  /// (index 0 = not built): a tier-1 job is three hours of planks, a tier-5
  /// one most of a day, so one visit a day keeps a workshop busy.
  static const List<int> workshopMaxBatchesByTier = [0, 6, 10, 16, 24, 32];

  // ---- The Castle ------------------------------------------------------------

  /// The Castle's five stages, built in order once the town is a city. The
  /// gems stay modest (a week or so of logging each) so the town keeps
  /// growing alongside; the bill is mostly refined goods, which only the
  /// workshops make, a job a day, so the goods set the pace; and each stage
  /// takes [CastleStageSpec.buildDays] days to raise. Together they make the
  /// Castle the work of the months after the city.
  static final List<CastleStageSpec> castleStages = [
    CastleStageSpec(
      key: 'foundation',
      cost: Loot(gems: 60, materials: _m(stone: 2000, lumber: 1500)),
      goods: _g(cutStone: 400, planks: 300),
      buildDays: 14,
      prosperity: 100,
    ),
    CastleStageSpec(
      key: 'keep',
      cost: Loot(gems: 80, materials: _m(stone: 2500, ore: 1000)),
      goods: _g(cutStone: 600, tools: 200),
      buildDays: 18,
      prosperity: 150,
    ),
    CastleStageSpec(
      key: 'walls',
      cost: Loot(gems: 100, materials: _m(stone: 2500, lumber: 1500)),
      goods: _g(cutStone: 800, planks: 500),
      buildDays: 21,
      prosperity: 200,
    ),
    CastleStageSpec(
      key: 'towers',
      cost: Loot(gems: 120, materials: _m(stone: 2500, ore: 1500)),
      goods: _g(cutStone: 800, tools: 400),
      buildDays: 25,
      prosperity: 250,
    ),
    CastleStageSpec(
      key: 'banners',
      cost: Loot(gems: 150, materials: _m(hide: 2000, herbs: 2000)),
      goods: _g(cloth: 500, planks: 600),
      buildDays: 30,
      prosperity: 300,
    ),
  ];

  /// What finishing each Castle stage brings, claimed through the inbox (the
  /// last stage adds a trophy, `town/castle.dart`): a few days of gems, so
  /// each stage is felt without paying for the next.
  static const int castleStageRewardGems = 50;

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

  /// A reached goal earns a custom trophy (its own picture) when it took at
  /// least this many month-end rituals — consistency, never a dollar amount.
  static const int customTrophyMinRituals = 2;

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
