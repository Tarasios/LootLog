/// A simulated adult on the long road, through the real reward engine and
/// commands: each day they log (or not), claim and open whatever came,
/// collect, harvest and collect goods once, keep the workshops busy, and
/// spend greedily on the next district, the Castle, houses for the next
/// tier, guards for their farms, and then any build or upgrade, saving gems
/// for a district or Castle stage they cannot afford yet.
library;

import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/content.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';
import 'package:lootlog/game/domain/town/castle.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/guards.dart';
import 'package:lootlog/game/domain/town/residents.dart';

const String simAdult = 'ada';
const Party _solo = Party([PartyAdult(simAdult, inAdventure: true)]);

/// What one simulated day ended with.
class SimDay {
  const SimDay(this.day, this.tier, this.steps, this.castleStages, this.prosperity,
      {this.castleComplete = false});

  final int day;
  final TownTier tier;

  /// Builds, upgrades, plots, districts and Castle stages begun that day,
  /// plus a tier reached.
  final int steps;
  final int castleStages;
  final int prosperity;

  /// The Castle stands finished at the day's end.
  final bool castleComplete;
}

/// The outpost's buildings in the order the player puts them up.
const _buildOrder = [
  BuildingType.centralHall,
  BuildingType.lumberyard,
  BuildingType.quarry,
  BuildingType.scribesDesk,
  BuildingType.storehouse,
  BuildingType.mine,
  BuildingType.herbGarden,
  BuildingType.huntersLodge,
  BuildingType.forge,
  BuildingType.vault,
  BuildingType.arcaneWell,
];

/// The districts in the order the player buys them.
const _districtOrder = [
  kFarmlandDistrictId,
  kResidentialDistrictId,
  kGuardPostDistrictId,
  kMarketRowDistrictId,
  kParkDistrictId,
];

/// What the player puts up in each civic district, plot by plot.
const Map<String, List<CivicBuildingType>> _civicPlan = {
  kResidentialDistrictId: [
    CivicBuildingType.cottage, CivicBuildingType.cottage, CivicBuildingType.rowhouse,
    CivicBuildingType.cottage, CivicBuildingType.rowhouse, CivicBuildingType.well,
  ],
  kGuardPostDistrictId: [
    CivicBuildingType.watchtower, CivicBuildingType.barracks,
    CivicBuildingType.watchtower, CivicBuildingType.wallSection,
  ],
  kMarketRowDistrictId: [
    CivicBuildingType.workshop, CivicBuildingType.stall, CivicBuildingType.workshop,
    CivicBuildingType.guildHall, CivicBuildingType.workshop,
  ],
  kParkDistrictId: [
    CivicBuildingType.garden, CivicBuildingType.bandstand,
    CivicBuildingType.fountain, CivicBuildingType.garden,
  ],
};

class LongRoadPlayer {
  final List<GameEvent> _log = [];

  /// Every game event so far.
  List<GameEvent> get log => _log;
  GameState state = GameState.initial();
  int _ids = 0;

  GameEventStamp get _stamp => GameEventStamp(
        deviceId: 'sim',
        newEventId: () => 'sim-${(_ids++).toString().padLeft(8, '0')}',
      );

  HallState get town => state.townOf(simAdult);
  PersonState get me => state.person(simAdult);

  void _append(List<GameEvent> events) {
    if (events.isEmpty) return;
    _log.addAll(events);
    final sorted = [...events]..sort(compareGameEvents);
    final cursor = state.cursor;
    if (cursor != null && compareGameEvents(sorted.first, cursor) < 0) {
      state = projectGameState(_log);
    } else {
      for (final event in sorted) {
        state = state.apply(event);
      }
    }
  }

  GameCommands _commands(DateTime now, [GameEventStamp? stamp]) =>
      GameCommands(state: state, clock: FixedClock(now), actorId: simAdult, stamp: stamp ?? _stamp);

  bool act(DateTime now, GameCommandResult Function(GameCommands commands) body) {
    final result = body(_commands(now));
    if (result.accepted) _append(result.events);
    return result.accepted;
  }

  GameCommandResult preview(DateTime now, GameCommandResult Function(GameCommands commands) body) =>
      body(_commands(now, GameEventStamp(deviceId: 'preview', newEventId: () => 'preview')));

  void engine(List<Event> ledger, DateTime now) => _append(const RewardEngine(monthEnd: NoMonthEndRewards())
      .evaluate(ledger, state, FixedClock(now), party: _solo, stamp: _stamp));
}

PurchaseAdded _buy(DateTime at, String id) => PurchaseAdded(
      eventId: id,
      deviceId: 'phone',
      userId: simAdult,
      occurredAt: at,
      createdAt: at,
      purchaseId: 'p-$id',
      target: const VaultCharge(),
      amountCents: 1000,
    );

/// Simulates [days] days; [logsOn] says which days (1-based, day 1 a
/// Monday) the player logs and plays.
List<SimDay> simulateLongRoad(int days,
    {bool Function(int day)? logsOn, void Function(int day, LongRoadPlayer player, DateTime at)? trace}) {
  final player = LongRoadPlayer();
  final firstDay = DateTime.utc(2026, 10, 5); // a Monday
  final out = <SimDay>[];
  for (var day = 1; day <= days; day++) {
    final midnightUtc = firstDay.add(Duration(days: day - 1));
    final morning = midnightUtc.add(const Duration(hours: 17)); // 9–10am Vancouver
    final plays = logsOn?.call(day) ?? true;
    final tierBefore = player.me.townTier;
    var steps = 0;
    if (plays) {
      player.engine([
        _buy(morning, 'd$day-a'),
        _buy(morning.add(const Duration(minutes: 5)), 'd$day-b'),
      ], morning.add(const Duration(minutes: 10)));
      final choresAt = morning.add(const Duration(minutes: 15));
      _chores(player, choresAt);
      steps = _spend(player, choresAt);
      _refine(player, choresAt.add(const Duration(minutes: 1)));
    }
    // The evening's run sees builds that finished during the day.
    player.engine(const [], midnightUtc.add(const Duration(hours: 23)));
    if (player.me.townTier != tierBefore) steps++;
    final evening = midnightUtc.add(const Duration(hours: 23));
    out.add(SimDay(day, player.me.townTier, steps, player.town.castle.stagesStarted, player.me.peakProsperity,
        castleComplete: player.town.castle.isCompleteAt(evening)));
    trace?.call(day, player, midnightUtc.add(const Duration(hours: 23)));
  }
  return out;
}

/// One morning's chores: claim, open, collect, harvest, collect goods.
void _chores(LongRoadPlayer player, DateTime now) {
  for (final rewardId in player.me.unclaimedRewards.keys.toList()) {
    player.act(now, (commands) => commands.claimReward(rewardId));
  }
  for (final chestId in player.me.unopenedChests.keys.toList()) {
    player.act(now, (commands) => commands.openChest(chestId));
  }
  for (final plot in player.town.plots.keys.toList()) {
    player.act(now, (commands) => commands.collectMaterials(plot));
  }
  for (final address in player.town.districts.buildings.keys.toList()) {
    if (address.districtId != kFarmlandDistrictId) continue;
    player.act(now, (commands) => commands.harvestFood(address.plotIndex));
  }
  player.act(now, (commands) => commands.collectGoods());
}

/// Keeps every idle workshop busy with the good the town has least of
/// (against what the next Castle stage wants), using at most half of the
/// stores of what goes in.
void _refine(LongRoadPlayer player, DateTime now) {
  for (var attempt = 0; attempt < 6; attempt++) {
    final stage = castleStageSpec(player.town.castle.stagesStarted + 1);
    final stored = player.town.goods.stored;
    final recipes = Balance.refiningRecipes.entries.toList()
      ..sort((first, second) {
        int want(RefiningRecipe recipe) => stage == null ? 100 : stage.goods[recipe.output] + 50;
        final firstShare = stored[first.value.output] * 1000 ~/ want(first.value);
        final secondShare = stored[second.value.output] * 1000 ~/ want(second.value);
        return firstShare.compareTo(secondShare);
      });
    var started = false;
    for (final entry in recipes) {
      final recipe = entry.value;
      var batches = Balance.workshopMaxBatchesByTier.last;
      for (final input in recipe.input.amounts.entries) {
        final affordable = player.town.materials[input.key] ~/ 2 ~/ input.value;
        if (affordable < batches) batches = affordable;
      }
      for (; batches >= 1; batches--) {
        if (player.act(now, (commands) => commands.startRefining(entry.key, batches))) {
          started = true;
          break;
        }
        final why = player.preview(now, (commands) => commands.startRefining(entry.key, 1)).rejection;
        if (why == GameRejection.workshopBusy || why == GameRejection.noWorkshop) return;
      }
      if (started) break;
    }
    if (!started) return;
  }
}

/// Spends greedily; returns how many steps it bought.
int _spend(LongRoadPlayer player, DateTime now) {
  var bought = 0;
  while (bought < 60 && _tryOnce(player, now)) {
    bought++;
  }
  return bought;
}

bool _tryOnce(LongRoadPlayer player, DateTime now) {
  // The next district, then the Castle, come first; while one is out of
  // reach the player saves their gems for it.
  var saving = false;
  for (final id in _districtOrder) {
    if (player.town.districts.owns(id)) continue;
    if (player.act(now, (commands) => commands.buyDistrict(id))) return true;
    final why = player.preview(now, (commands) => commands.buyDistrict(id)).rejection;
    if (why == GameRejection.notEnoughGems) saving = true;
    break;
  }
  if (player.act(now, (commands) => commands.startCastleStage())) return true;
  if (player.preview(now, (commands) => commands.startCastleStage()).rejection == GameRejection.notEnoughGems) {
    saving = true;
  }

  bool free(GameCommandResult Function(GameCommands commands) body) {
    final preview = player.preview(now, body);
    if (!preview.accepted) return false;
    if (saving && preview.events.any(_costsGems)) return false;
    return player.act(now, body);
  }

  if (_civic(player, now, free)) return true;
  if (_farms(player, now, free)) return true;
  for (final type in _buildOrder) {
    final standing = player.town.plotOf(type);
    if (standing != null) {
      if (free((commands) => commands.startBuilding(standing.index, type))) return true;
      continue;
    }
    final empty = player.town.plots.values.where((plot) => plot.building == null);
    if (empty.isEmpty) continue;
    if (free((commands) => commands.startBuilding(empty.first.index, type))) return true;
  }
  final nextPlot = player.town.plots.length;
  return free((commands) => commands.unlockPlot(nextPlot));
}

/// Houses until the next tier is housed, guards until every farm works,
/// then the rest of each civic district's plan, plot by plot.
bool _civic(LongRoadPlayer player, DateTime now, bool Function(GameCommandResult Function(GameCommands)) free) {
  bool build(String districtId) {
    final plan = _civicPlan[districtId]!;
    if (!player.town.districts.owns(districtId)) return false;
    for (var plot = 0; plot < plan.length; plot++) {
      final standing = player.town.districts.buildingAt(PlotAddress(districtId, plot));
      if (standing == null) {
        if (free((commands) => commands.startCivicBuilding(districtId, plot, plan[plot]))) return true;
        return false; // plots fill in order
      }
    }
    for (var plot = 0; plot < plan.length; plot++) {
      if (free((commands) => commands.startCivicBuilding(districtId, plot, plan[plot]))) return true;
    }
    return false;
  }

  final next = player.me.townTier.index + 1 < TownTier.values.length
      ? TownTier.values[player.me.townTier.index + 1]
      : null;
  final housed = next == null || housedFor(player.town, next, now);
  if (!housed && build(kResidentialDistrictId)) return true;
  final farms = player.town.districts.buildings.keys.where((a) => a.districtId == kFarmlandDistrictId).length;
  if (farms > guardedFarmPlots(player.town, now) && build(kGuardPostDistrictId)) return true;
  for (final districtId in [kMarketRowDistrictId, kResidentialDistrictId, kParkDistrictId, kGuardPostDistrictId]) {
    if (build(districtId)) return true;
  }
  return false;
}

/// The first farm, the granary, then upgrades and more farms.
bool _farms(LongRoadPlayer player, DateTime now, bool Function(GameCommandResult Function(GameCommands)) free) {
  if (!player.town.districts.owns(kFarmlandDistrictId)) return false;
  final farms = {
    for (final entry in player.town.districts.buildings.entries)
      if (entry.key.districtId == kFarmlandDistrictId) entry.key: entry.value,
  };
  if (farms.isEmpty) return free((commands) => commands.startFarmBuilding(0, FarmBuildingType.farm));
  final hasGranary = farms.values.any((b) => b.farmType == FarmBuildingType.granary);
  if (!hasGranary) return free((commands) => commands.startFarmBuilding(1, FarmBuildingType.granary));
  for (final address in farms.keys) {
    final type = farms[address]!.farmType!;
    if (free((commands) => commands.startFarmBuilding(address.plotIndex, type))) return true;
  }
  final plots = districtPlotCount(districtById(kFarmlandDistrictId)!, player.me.townTier);
  for (var plot = 0; plot < plots; plot++) {
    if (farms.containsKey(PlotAddress(kFarmlandDistrictId, plot))) continue;
    // Every open field is planted; one past the guards rests (but still
    // counts towards prosperity) until the Guard Post covers it.
    return free((commands) => commands.startFarmBuilding(plot, FarmBuildingType.farm));
  }
  return false;
}

bool _costsGems(GameEvent event) => switch (event) {
      PlotUnlocked(:final gemCost) => gemCost > 0,
      BuildingStarted(:final cost) => cost.gems > 0,
      DistrictBuildingStarted(:final cost) => cost.gems > 0,
      CivicBuildingStarted(:final cost) => cost.gems > 0,
      _ => false,
    };
