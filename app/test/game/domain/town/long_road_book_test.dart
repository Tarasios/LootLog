/// The town book's long-road pages read the rules' own numbers: homes and
/// what the next tier needs, guards and the fields they cover (with the
/// farms resting until more come), goods in the lofts and the workshops'
/// jobs, and the Castle's progress; and which districts a town can walk
/// into (those it owns, and Castle Hill once it is a city).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/guards.dart';
import 'package:lootlog/game/domain/town/long_road_book.dart';
import 'package:lootlog/game/domain/town/residents.dart';

import '../game_fixtures.dart';
import 'growth_fixtures.dart';

void main() {
  test('homes, guards and fields equal the rules', () {
    final game = projectGameState([
      ...tierWith(TownTier.village),
      districtPurchased('farmland', kFarmlandDistrictId, when: at(0)),
      districtPurchased('homes', kResidentialDistrictId, when: at(0)),
      districtPurchased('guards', kGuardPostDistrictId, when: at(0)),
      civicBuilt('cottage', kResidentialDistrictId, 0, CivicBuildingType.cottage, when: at(1)),
      civicBuilt('tower', kGuardPostDistrictId, 0, CivicBuildingType.watchtower, when: at(1)),
    ]);
    final town = game.townOf(robin);
    final book = longRoadBook(game, robin, at(10));
    expect(book.housing, housingAt(town, at(10)));
    expect(book.housing, greaterThan(0));
    expect(book.nextTier, TownTier.town);
    expect(book.housingNeeded, housingNeededFor(TownTier.town));
    expect(book.housed, housedFor(town, TownTier.town, at(10)));
    expect(book.guards, guardCapacityAt(town, at(10)));
    expect(book.guardedFields, guardedFarmPlots(town, at(10)));
    expect(book.fieldsOpen, Balance.farmlandPlotsByTier[TownTier.village]);
    expect(book.restingFarms, 0);
  });

  test('a farm past the guards counts as resting', () {
    final game = projectGameState([
      ...tierWith(TownTier.town),
      districtPurchased('farmland', kFarmlandDistrictId, when: at(0)),
      farmBuilt('edge', Balance.unguardedFarmPlots, FarmBuildingType.farm, when: at(1)),
    ]);
    final book = longRoadBook(game, robin, at(10));
    expect(book.restingFarms, 1);
    expect(book.fieldsOpen, Balance.farmlandPlotsByTier[TownTier.town]);
  });

  test('goods in store and the workshops\' jobs', () {
    final game = projectGameState([
      ...tierWith(TownTier.town),
      districtPurchased('market', kMarketRowDistrictId, when: at(0)),
      civicBuilt('workshop', kMarketRowDistrictId, 0, CivicBuildingType.workshop, when: at(0)),
      refiningStarted('job', 0, 'planks', when: at(1), completesAt: at(31), output: GoodsBundle({GoodsKind.planks: 4})),
      goodsCollected('got', 0, 'job', GoodsBundle({GoodsKind.planks: 4}), when: at(40)),
      refiningStarted('job2', 0, 'cutStone', when: at(41), completesAt: at(71), output: GoodsBundle({GoodsKind.cutStone: 2})),
    ]);
    final book = longRoadBook(game, robin, at(50));
    expect(book.goods[GoodsKind.planks], 4);
    expect(book.workshops, 1);
    expect(book.jobsWorking, 1);
    expect(book.jobsDone, 0);
    expect(longRoadBook(game, robin, at(80)).jobsDone, 1);
  });

  test('the Castle\'s progress', () {
    final city = projectGameState(tierWith(TownTier.city));
    final empty = longRoadBook(city, robin, at(10));
    expect(empty.castleOpen, isTrue);
    expect(empty.castleStagesDone, 0);
    expect(empty.castleBuilding, isFalse);
    expect(empty.castleNextStage, 1);

    final building = projectGameState([...tierWith(TownTier.city), castleStageStarted('one', 1, when: at(0))]);
    final midway = longRoadBook(building, robin, onDay(2));
    expect(midway.castleBuilding, isTrue);
    expect(midway.castleStagesDone, 0);
    expect(midway.castleNextStage, 1);
    final done = at(0).add(Duration(days: Balance.castleStages.first.buildDays));
    expect(longRoadBook(building, robin, done).castleStagesDone, 1);
    expect(longRoadBook(building, robin, done).castleNextStage, 2);

    expect(longRoadBook(projectGameState(tierWith(TownTier.town)), robin, at(10)).castleOpen, isFalse);
  });

  group('which districts a town can walk into', () {
    test('those it owns', () {
      final game = projectGameState([
        ...tierWith(TownTier.village),
        districtPurchased('guards', kGuardPostDistrictId, when: at(0)),
      ]);
      final town = game.townOf(robin);
      expect(districtVisitable(town, TownTier.village, kOutpostDistrictId), isTrue);
      expect(districtVisitable(town, TownTier.village, kGuardPostDistrictId), isTrue);
      expect(districtVisitable(town, TownTier.village, kParkDistrictId), isFalse);
    });

    test('Castle Hill once the town is a city', () {
      final town = HallState.starter();
      expect(districtVisitable(town, TownTier.town, kCastleHillDistrictId), isFalse);
      expect(districtVisitable(town, TownTier.city, kCastleHillDistrictId), isTrue);
    });
  });
}
