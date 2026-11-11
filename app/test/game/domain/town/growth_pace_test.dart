/// The town-growth pace, held so balance edits can't silently break it: a
/// simulated adult who logs two purchases every morning, claims and opens
/// whatever came, collects and harvests once, and spends greedily (saving
/// gems for the farmland once at the hamlet) — through the real reward
/// engine and commands.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';
import 'package:lootlog/game/domain/town/districts.dart';

const _ada = 'ada';
const _solo = Party([PartyAdult(_ada, inAdventure: true)]);

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

class _Player {
  final List<GameEvent> _log = [];
  GameState state = GameState.initial();
  int _ids = 0;

  GameEventStamp get _stamp => GameEventStamp(
        deviceId: 'sim',
        newEventId: () => 'sim-${(_ids++).toString().padLeft(7, '0')}',
      );

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

  bool act(DateTime now, GameCommandResult Function(GameCommands commands) body) {
    final result = body(GameCommands(
        state: state, clock: FixedClock(now), actorId: _ada, stamp: _stamp));
    if (result.accepted) _append(result.events);
    return result.accepted;
  }

  void engine(List<Event> ledger, DateTime now) => _append(
      const RewardEngine(monthEnd: NoMonthEndRewards())
          .evaluate(ledger, state, FixedClock(now), party: _solo, stamp: _stamp));

  HallState get town => state.townOf(_ada);
  PersonState get me => state.person(_ada);
}

PurchaseAdded _buy(DateTime at, String id) => PurchaseAdded(
      eventId: id,
      deviceId: 'phone',
      userId: _ada,
      occurredAt: at,
      createdAt: at,
      purchaseId: 'p-$id',
      target: const VaultCharge(),
      amountCents: 1000,
    );

/// One morning's chores: claim, open, collect, harvest.
void _chores(_Player player, DateTime now) {
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
    player.act(now, (commands) => commands.harvestFood(address.plotIndex));
  }
}

/// Spends greedily; returns how many builds, upgrades, plots and districts
/// it bought.
int _spend(_Player player, DateTime now) {
  var bought = 0;
  bool savingForFarmland() =>
      player.me.townTier.index >= TownTier.hamlet.index &&
      !player.town.districts.owns(kFarmlandDistrictId);

  bool tryOnce() {
    if (player.act(now, (commands) => commands.buyDistrict(kFarmlandDistrictId))) return true;
    final saving = savingForFarmland();
    bool free(GameCommandResult Function(GameCommands commands) body) {
      final preview = body(GameCommands(
          state: player.state,
          clock: FixedClock(now),
          actorId: _ada,
          stamp: GameEventStamp(deviceId: 'preview', newEventId: () => 'preview')));
      if (!preview.accepted) return false;
      if (saving && preview.events.any(_costsGems)) return false;
      return player.act(now, body);
    }

    if (player.town.districts.owns(kFarmlandDistrictId)) {
      final farms = player.town.districts.buildings;
      if (farms.isEmpty && free((commands) => commands.startFarmBuilding(0, FarmBuildingType.farm))) {
        return true;
      }
      // A village needs more food than the fields' edge can hold, so the
      // granary comes right after the first farm, before any more fields.
      final hasGranary = farms.values.any((b) => b.farmType == FarmBuildingType.granary);
      if (!hasGranary) {
        return farms.isNotEmpty &&
            free((commands) => commands.startFarmBuilding(1, FarmBuildingType.granary));
      }
      for (final address in farms.keys) {
        final type = farms[address]!.farmType!;
        if (free((commands) => commands.startFarmBuilding(address.plotIndex, type))) return true;
      }
      for (var plot = 0; plot < districtById(kFarmlandDistrictId)!.plotCount; plot++) {
        if (farms.containsKey(PlotAddress(kFarmlandDistrictId, plot))) continue;
        if (free((commands) => commands.startFarmBuilding(plot, FarmBuildingType.farm))) return true;
        break;
      }
    }
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

  while (bought < 40 && tryOnce()) {
    bought++;
  }
  return bought;
}

bool _costsGems(GameEvent event) => switch (event) {
      PlotUnlocked(:final gemCost) => gemCost > 0,
      BuildingStarted(:final cost) => cost.gems > 0,
      DistrictBuildingStarted(:final cost) => cost.gems > 0,
      _ => false,
    };

/// The simulated days, with the tier at the end of each and what was bought.
List<({int day, TownTier tier, int bought, bool farmland, int prosperity})> _simulate(int days) {
  final player = _Player();
  final firstDay = DateTime.utc(2026, 10, 5); // a Monday
  final out = <({int day, TownTier tier, int bought, bool farmland, int prosperity})>[];
  for (var day = 1; day <= days; day++) {
    final midnightUtc = firstDay.add(Duration(days: day - 1));
    final morning = midnightUtc.add(const Duration(hours: 17)); // 9–10am Vancouver
    player.engine([
      _buy(morning, 'd$day-a'),
      _buy(morning.add(const Duration(minutes: 5)), 'd$day-b'),
    ], morning.add(const Duration(minutes: 10)));
    final choresAt = morning.add(const Duration(minutes: 15));
    _chores(player, choresAt);
    final bought = _spend(player, choresAt);
    // The afternoon's run sees builds that finished during the day.
    player.engine(const [], midnightUtc.add(const Duration(hours: 23)));
    out.add((
      day: day,
      tier: player.me.townTier,
      bought: bought,
      farmland: player.town.districts.owns(kFarmlandDistrictId),
      prosperity: player.me.peakProsperity,
    ));
  }
  return out;
}

void main() {
  test('a daily player reaches the hamlet within a week and the village in about a month', () {
    final days = _simulate(50);
    int firstDay(bool Function(({int day, TownTier tier, int bought, bool farmland, int prosperity}) d) test) =>
        days.firstWhere(test, orElse: () => (day: 999, tier: TownTier.outpost, bought: 0, farmland: false, prosperity: 0)).day;

    final hamlet = firstDay((d) => d.tier.index >= TownTier.hamlet.index);
    final farmland = firstDay((d) => d.farmland);
    final village = firstDay((d) => d.tier.index >= TownTier.village.index);
    final busyDays = days.take(14).where((d) => d.bought > 0).length;
    final summary = 'hamlet day $hamlet, farmland day $farmland, village day $village, '
        '$busyDays of the first 14 days with a build; prosperity by day: '
        '${days.map((d) => d.prosperity).toList()}';
    expect(hamlet, lessThanOrEqualTo(7), reason: summary);
    expect(farmland, lessThanOrEqualTo(hamlet + 7), reason: 'shortly after the hamlet. $summary');
    expect(village, inInclusiveRange(21, 45), reason: summary);
    expect(busyDays, greaterThanOrEqualTo(10), reason: summary);
    expect(days.every((d) => d.tier.index < TownTier.town.index), isTrue,
        reason: 'the town tier is far beyond the first weeks. $summary');
  });
}
