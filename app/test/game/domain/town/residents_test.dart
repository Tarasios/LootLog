import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/food.dart';
import 'package:lootlog/game/domain/town/prosperity.dart';
import 'package:lootlog/game/domain/town/residents.dart';

import '../game_fixtures.dart';
import 'growth_fixtures.dart';

int _housing(CivicBuildingType type, int tier) =>
    Balance.civicBuildings[type]!.housingByTier[tier - 1];

void main() {
  final quarter = [
    ...tierWith(TownTier.village),
    districtPurchased('q', kResidentialDistrictId, when: at(1)),
  ];

  group('housing', () {
    test('sums the houses in service: cottages, rowhouses and the well', () {
      final town = projectGameState([
        ...quarter,
        civicBuilt('c', kResidentialDistrictId, 0, CivicBuildingType.cottage, when: at(2)),
        civicBuilt('r', kResidentialDistrictId, 1, CivicBuildingType.rowhouse, when: at(2)),
        civicBuilt('w', kResidentialDistrictId, 2, CivicBuildingType.well, when: at(2)),
      ]).townOf(robin);
      expect(housingAt(town, at(3)),
          _housing(CivicBuildingType.cottage, 1) +
              _housing(CivicBuildingType.rowhouse, 1) +
              _housing(CivicBuildingType.well, 1));
    });

    test('a house being built houses nobody yet, and an upgrade keeps its old tier until done', () {
      final town = projectGameState([
        ...quarter,
        civicBuilt('c1', kResidentialDistrictId, 0, CivicBuildingType.cottage, when: at(2)),
        civicBuilt('c2', kResidentialDistrictId, 0, CivicBuildingType.cottage,
            when: at(3), tier: 2, completesAt: at(63)),
        civicBuilt('n', kResidentialDistrictId, 1, CivicBuildingType.cottage,
            when: at(3), completesAt: at(63)),
      ]).townOf(robin);
      expect(housingAt(town, at(10)), _housing(CivicBuildingType.cottage, 1));
      expect(housingAt(town, at(63)),
          _housing(CivicBuildingType.cottage, 2) + _housing(CivicBuildingType.cottage, 1));
    });

    test('other districts\' buildings house nobody', () {
      final town = projectGameState([
        ...tierWith(TownTier.village),
        districtPurchased('g', kGuardPostDistrictId, when: at(1)),
        civicBuilt('t', kGuardPostDistrictId, 0, CivicBuildingType.watchtower, when: at(2)),
      ]).townOf(robin);
      expect(housingAt(town, at(3)), 0);
    });
  });

  group('people and food', () {
    test('population is the tier\'s residents plus the housed, and food need follows it', () {
      final town = projectGameState([
        ...quarter,
        civicBuilt('c', kResidentialDistrictId, 0, CivicBuildingType.cottage, when: at(2)),
      ]).townOf(robin);
      final housed = _housing(CivicBuildingType.cottage, 1);
      expect(populationAt(town, TownTier.village, at(3)), populationOf(TownTier.village) + housed);
      expect(foodNeedAt(town, TownTier.village, at(3)),
          (populationOf(TownTier.village) + housed) * Balance.foodPerResident[TownTier.village]!);
      expect(dailyFoodNeed(TownTier.village, housing: housed), foodNeedAt(town, TownTier.village, at(3)));
    });
  });

  group('the town and city gates', () {
    test('only the town and the city need housing', () {
      expect(housingNeededFor(TownTier.hamlet), 0);
      expect(housingNeededFor(TownTier.village), 0);
      expect(housingNeededFor(TownTier.town), Balance.housingForTier[TownTier.town]);
      expect(housingNeededFor(TownTier.city), Balance.housingForTier[TownTier.city]);
      expect(housingNeededFor(TownTier.city), greaterThan(housingNeededFor(TownTier.town)));
    });

    test('a town short of housing waits at the village, keeping everything', () {
      const peak = 1 << 30;
      expect(
        tiersDue(
          current: TownTier.village,
          peak: peak,
          foodSecureFor: (_) => true,
          housedFor: (target) => target != TownTier.town,
        ),
        isEmpty,
      );
      expect(
        tiersDue(
          current: TownTier.village,
          peak: peak,
          foodSecureFor: (_) => true,
          housedFor: (target) => target == TownTier.town,
        ),
        [TownTier.town],
      );
    });

    test('housedFor reads the houses in service', () {
      // Tier-3 cottages, as many as the town's housing needs.
      final needed = housingNeededFor(TownTier.town);
      final perCottage = _housing(CivicBuildingType.cottage, 3);
      final cottages = (needed + perCottage - 1) ~/ perCottage;
      expect(cottages, lessThanOrEqualTo(Balance.residentialPlotCount));
      List<CivicBuildingStarted> cottage(int plot) => [
            for (var tier = 1; tier <= 3; tier++)
              civicBuilt('c$plot-$tier', kResidentialDistrictId, plot, CivicBuildingType.cottage,
                  when: at(2 + tier), tier: tier),
          ];
      final events = [...quarter, for (var plot = 0; plot < cottages - 1; plot++) ...cottage(plot)];
      final short = projectGameState(events).townOf(robin);
      expect(housedFor(short, TownTier.town, at(10)), isFalse);
      final enough = projectGameState([...events, ...cottage(cottages - 1)]).townOf(robin);
      expect(housedFor(enough, TownTier.town, at(10)), isTrue);
      expect(housedFor(enough, TownTier.village, at(10)), isTrue);
    });
  });
}
