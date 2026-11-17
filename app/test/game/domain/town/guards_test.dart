import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/reason_codes.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/food.dart';
import 'package:lootlog/game/domain/town/guards.dart';

import '../game_fixtures.dart';
import 'growth_fixtures.dart';

int _farmRate(int tier) => Balance.farmBuildings[FarmBuildingType.farm]!.foodPerHour[tier - 1];
int _guards(CivicBuildingType type, int tier) =>
    Balance.civicBuildings[type]!.guardsByTier[tier - 1];

/// The first farm plot past the unguarded ones.
final int _firstGuardedPlot = Balance.unguardedFarmPlots;

void main() {
  var ids = 0;
  GameCommands commandsFor(GameState state, DateTime now) => GameCommands(
        state: state,
        clock: FixedClock(now),
        actorId: robin,
        stamp: GameEventStamp(deviceId: 'dev-1', newEventId: () => 'cmd-${ids++}'),
      );

  /// A village with the farmland and the guard post, Robin logging today so
  /// the crews work the whole day, and a farm on the first plot that needs
  /// guards, finished at [kBase].
  List<GameEvent> farmPastTheEdge() => [
        ...tierWith(TownTier.village),
        granted('log', when: at(-5), rewardId: 'log', reasonCode: GameReasonCodes.dailyLog),
        districtPurchased('farmland', kFarmlandDistrictId, when: at(-1)),
        districtPurchased('guards', kGuardPostDistrictId, when: at(-1)),
        farmBuilt('farm', _firstGuardedPlot, FarmBuildingType.farm, when: at(0)),
      ];

  group('guard capacity', () {
    test('sums the guard post\'s buildings in service', () {
      final town = projectGameState([
        ...farmPastTheEdge(),
        civicBuilt('t', kGuardPostDistrictId, 0, CivicBuildingType.watchtower, when: at(1)),
        civicBuilt('b', kGuardPostDistrictId, 1, CivicBuildingType.barracks, when: at(1)),
        civicBuilt('w', kGuardPostDistrictId, 2, CivicBuildingType.wallSection,
            when: at(1), completesAt: at(90)),
      ]).townOf(robin);
      expect(guardCapacityAt(town, at(2)),
          _guards(CivicBuildingType.watchtower, 1) + _guards(CivicBuildingType.barracks, 1));
      expect(guardCapacityAt(town, at(90)),
          guardCapacityAt(town, at(2)) + _guards(CivicBuildingType.wallSection, 1));
    });

    test('the first plots need no guards; each further plot needs its share', () {
      final none = projectGameState(farmPastTheEdge()).townOf(robin);
      expect(guardedFarmPlots(none, at(2)), Balance.unguardedFarmPlots);
      expect(farmPlotGuarded(none, _firstGuardedPlot - 1, at(2)), isTrue);
      expect(farmPlotGuarded(none, _firstGuardedPlot, at(2)), isFalse);
      final guarded = projectGameState([
        ...farmPastTheEdge(),
        civicBuilt('t', kGuardPostDistrictId, 0, CivicBuildingType.watchtower, when: at(1)),
      ]).townOf(robin);
      expect(guardedFarmPlots(guarded, at(2)),
          Balance.unguardedFarmPlots + _guards(CivicBuildingType.watchtower, 1) ~/ Balance.guardsPerFarmPlot);
      expect(farmPlotGuarded(guarded, _firstGuardedPlot, at(2)), isTrue);
    });
  });

  group('a farm past the guards rests', () {
    test('it can still be built, keeps its building and grows nothing', () {
      final state = projectGameState(farmPastTheEdge());
      final town = state.townOf(robin);
      final address = PlotAddress(kFarmlandDistrictId, _firstGuardedPlot);
      expect(town.districts.buildingAt(address)!.farmType, FarmBuildingType.farm);
      expect(uncollectedFood(town, address, at(240), activeDays: state.townActiveDaysOf(robin)), 0);
      expect(commandsFor(state, at(240)).harvestFood(_firstGuardedPlot).rejection,
          GameRejection.nothingToCollect);
      expect(farmResting(town, address, at(240)), isTrue);
    });

    test('building on a plot past the guards is allowed', () {
      final state = projectGameState([
        ...tierWith(TownTier.town,
            materials: MaterialBundle({MaterialKind.lumber: 500, MaterialKind.stone: 500})),
        districtPurchased('farmland', kFarmlandDistrictId, when: at(-1)),
      ]);
      expect(commandsFor(state, at(10)).startFarmBuilding(_firstGuardedPlot, FarmBuildingType.farm).accepted,
          isTrue);
    });

    test('it grows again from the moment guards arrive, never for the time it rested', () {
      // The watchtower finishes two hours after the farm.
      final state = projectGameState([
        ...farmPastTheEdge(),
        civicBuilt('t', kGuardPostDistrictId, 0, CivicBuildingType.watchtower,
            when: at(60), completesAt: at(120)),
      ]);
      final town = state.townOf(robin);
      final address = PlotAddress(kFarmlandDistrictId, _firstGuardedPlot);
      final activeDays = state.townActiveDaysOf(robin);
      expect(uncollectedFood(town, address, at(120), activeDays: activeDays), 0);
      expect(uncollectedFood(town, address, at(180), activeDays: activeDays), _farmRate(1));
      expect(farmResting(town, address, at(180)), isFalse);
      final harvest = commandsFor(state, at(180)).harvestFood(_firstGuardedPlot);
      expect((harvest.events.single as FoodHarvested).amount, _farmRate(1));
    });

    test('a watchtower upgraded since counts for nothing before its first build finished', () {
      // The farm finishes at kBase; the watchtower's first build only two
      // hours later, and it has been raised to tier 2 since.
      final state = projectGameState([
        ...farmPastTheEdge(),
        civicBuilt('t1', kGuardPostDistrictId, 0, CivicBuildingType.watchtower,
            when: at(60), completesAt: at(120)),
        civicBuilt('t2', kGuardPostDistrictId, 0, CivicBuildingType.watchtower,
            when: at(150), tier: 2, completesAt: at(210)),
      ]);
      final town = state.townOf(robin);
      final address = PlotAddress(kFarmlandDistrictId, _firstGuardedPlot);
      expect(town.districts.buildingAt(const PlotAddress(kGuardPostDistrictId, 0))!.firstCompletedAt, at(120));
      expect(guardCapacityAt(town, at(119)), 0);
      expect(farmPlotGuardedSince(town, _firstGuardedPlot), at(120));
      expect(uncollectedFood(town, address, at(180), activeDays: state.townActiveDaysOf(robin)), _farmRate(1),
          reason: 'only the hour since the first watch began');
    });

    test('a farm within the unguarded plots never rests', () {
      final state = projectGameState([
        ...tierWith(TownTier.village),
        granted('log', when: at(-5), rewardId: 'log', reasonCode: GameReasonCodes.dailyLog),
        districtPurchased('farmland', kFarmlandDistrictId, when: at(-1)),
        farmBuilt('farm', 0, FarmBuildingType.farm, when: at(0)),
      ]);
      final town = state.townOf(robin);
      const address = PlotAddress(kFarmlandDistrictId, 0);
      expect(uncollectedFood(town, address, at(60), activeDays: state.townActiveDaysOf(robin)),
          _farmRate(1));
    });
  });

  group('a stage-2 farmland', () {
    test('farms on all six fields keep growing with no Guard Post', () {
      final state = projectGameState([
        ...tierWith(TownTier.village),
        granted('log', when: at(-5), rewardId: 'log', reasonCode: GameReasonCodes.dailyLog),
        districtPurchased('farmland', kFarmlandDistrictId, when: at(-1)),
        for (var plot = 0; plot < Balance.farmlandPlotCount; plot++)
          farmBuilt('farm-$plot', plot, FarmBuildingType.farm, when: at(0)),
      ]);
      final town = state.townOf(robin);
      expect(town.districts.owns(kGuardPostDistrictId), isFalse);
      for (var plot = 0; plot < Balance.farmlandPlotCount; plot++) {
        final address = PlotAddress(kFarmlandDistrictId, plot);
        expect(farmResting(town, address, at(60)), isFalse, reason: 'plot $plot');
        expect(uncollectedFood(town, address, at(60), activeDays: state.townActiveDaysOf(robin)), _farmRate(1),
            reason: 'plot $plot');
        expect(commandsFor(state, at(60)).harvestFood(plot).accepted, isTrue, reason: 'plot $plot');
      }
    });
  });

  group('more fields at the town', () {
    test('the farmland gains plots at the town and the city', () {
      final farmland = districtById(kFarmlandDistrictId)!;
      expect(districtPlotCount(farmland, TownTier.village), Balance.farmlandPlotCount);
      expect(districtPlotCount(farmland, TownTier.town), greaterThan(Balance.farmlandPlotCount));
      expect(districtPlotCount(farmland, TownTier.city),
          greaterThan(districtPlotCount(farmland, TownTier.town)));
    });

    test('a town may plant the new fields; a village may not', () {
      final materials = MaterialBundle({MaterialKind.lumber: 500, MaterialKind.stone: 500});
      final plot = Balance.farmlandPlotCount;
      final village = projectGameState([
        ...tierWith(TownTier.village, materials: materials),
        districtPurchased('farmland', kFarmlandDistrictId, when: at(-1)),
      ]);
      expect(commandsFor(village, at(10)).startFarmBuilding(plot, FarmBuildingType.farm).rejection,
          GameRejection.invalidPlot);
      final town = projectGameState([
        ...tierWith(TownTier.town, materials: materials),
        districtPurchased('farmland', kFarmlandDistrictId, when: at(-1)),
      ]);
      final result = commandsFor(town, at(10)).startFarmBuilding(plot, FarmBuildingType.farm);
      expect(result.accepted, isTrue, reason: '$result');
      final after = town.apply(result.events.single);
      expect(after.townOf(robin).districts.buildingAt(PlotAddress(kFarmlandDistrictId, plot)), isNotNull);
    });
  });
}
