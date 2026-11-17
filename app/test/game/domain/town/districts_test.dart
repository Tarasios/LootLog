import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/prosperity.dart';

import '../game_fixtures.dart';
import 'growth_fixtures.dart';

DistrictSpec get _farmland => districtById(kFarmlandDistrictId)!;

void main() {
  var ids = 0;
  GameCommands commandsFor(GameState state, {DateTime? now, String actor = robin}) =>
      GameCommands(
        state: state,
        clock: FixedClock(now ?? at(10)),
        actorId: actor,
        stamp: GameEventStamp(deviceId: 'dev-1', newEventId: () => 'cmd-${ids++}'),
      );

  group('the district catalogue', () {
    test('the outpost is the eleven plots every town starts with', () {
      final outpost = districtById(kOutpostDistrictId)!;
      expect(outpost.ownedFromStart, isTrue);
      expect(outpost.plotCount, Balance.maxPlots);
      expect(outpost.requiredTier, TownTier.outpost);
      expect(outpost.buildingKeys, [for (final type in BuildingType.values) type.name]);
    });

    test('the farmland opens at the hamlet with six plots of farm buildings', () {
      expect(_farmland.requiredTier, TownTier.hamlet);
      expect(_farmland.plotCount, Balance.farmlandPlotCount);
      expect(_farmland.plotCount, 6);
      expect(_farmland.buildingKeys, [for (final type in FarmBuildingType.values) type.name]);
      expect(_farmland.purchasable, isTrue);
      expect(_farmland.price,
          Loot(gems: Balance.farmlandGemPrice, materials: MaterialBundle(Balance.farmlandMaterialPrice)));
      expect(_farmland.tilesetKey, isNotEmpty);
    });

    test('later districts are listed as teasers that cannot be bought yet', () {
      for (final id in ['guardPost', 'residential', 'park', 'marketRow']) {
        final teaser = districtById(id);
        expect(teaser, isNotNull, reason: id);
        expect(teaser!.purchasable, isFalse, reason: id);
        expect(teaser.requiredTier.index, greaterThan(TownTier.hamlet.index), reason: id);
      }
      expect({for (final district in kDistricts) district.id}, hasLength(kDistricts.length));
      expect(districtById('nowhere'), isNull);
    });
  });

  group('plots by (district, index)', () {
    test('legacy plot events, which name no district, land in the outpost', () {
      // Stage-1 JSON as older builds wrote it: no district anywhere.
      final legacy = [
        {
          'eventId': 'l1', 'deviceId': 'old', 'actorId': robin,
          'occurredAt': at(0).toIso8601String(), 'createdAt': at(0).toIso8601String(),
          'schemaVersion': 1, 'type': 'PlotUnlocked',
          'payload': {'plotIndex': 3, 'gemCost': 0},
        },
        {
          'eventId': 'l2', 'deviceId': 'old', 'actorId': robin,
          'occurredAt': at(1).toIso8601String(), 'createdAt': at(1).toIso8601String(),
          'schemaVersion': 1, 'type': 'BuildingStarted',
          'payload': {
            'plotIndex': 3, 'buildingType': 'storehouse', 'tier': 1,
            'cost': const Loot().toJson(), 'completesAt': at(1).toIso8601String(),
          },
        },
      ].map(GameEvent.fromJson);
      final town = projectGameState(legacy).townOf(robin);
      expect(plotIsOpen(town, const PlotAddress(kOutpostDistrictId, 3)), isTrue);
      expect(town.plots[3]!.building!.type, BuildingType.storehouse);
      expect(town.districts.owns(kOutpostDistrictId), isTrue);
      expect(town.districts.owns(kFarmlandDistrictId), isFalse);
      expect(plotIsOpen(town, const PlotAddress(kFarmlandDistrictId, 0)), isFalse);
      expect(town.districts.buildings, isEmpty);
    });

    test('a bought district opens all its plots', () {
      final town = projectGameState([
        districtPurchased('d1', kFarmlandDistrictId, when: at(0)),
      ]).townOf(robin);
      for (var i = 0; i < _farmland.plotCount; i++) {
        expect(plotIsOpen(town, PlotAddress(kFarmlandDistrictId, i)), isTrue, reason: '$i');
      }
      expect(plotIsOpen(town, PlotAddress(kFarmlandDistrictId, _farmland.plotCount)), isFalse);
    });
  });

  group('buyDistrict', () {
    final price = _farmland.price;
    List<GameEvent> funded() => hamletWith(
          gems: price.gems,
          lumber: price.materials[MaterialKind.lumber],
          stone: price.materials[MaterialKind.stone],
        );

    test('buys the farmland for its price', () {
      final state = projectGameState(funded());
      final result = commandsFor(state).buyDistrict(kFarmlandDistrictId);
      expect(result.accepted, isTrue, reason: '$result');
      final purchase = result.events.whereType<DistrictPurchased>().single;
      expect(purchase.districtId, kFarmlandDistrictId);
      expect(purchase.cost, price);

      final after = state.apply(purchase);
      expect(after.townOf(robin).districts.owns(kFarmlandDistrictId), isTrue);
      expect(after.person(robin).gems, 0);
      expect(after.townOf(robin).materials.isEmpty, isTrue);
      expect(after.warnings, isEmpty);
    });

    test('refuses an unknown district, the outpost, a teaser and a second purchase', () {
      final state = projectGameState(funded());
      expect(commandsFor(state).buyDistrict('nowhere').rejection, GameRejection.unknownDistrict);
      expect(commandsFor(state).buyDistrict(kOutpostDistrictId).rejection,
          GameRejection.districtAlreadyOwned);
      expect(commandsFor(state).buyDistrict('park').rejection, GameRejection.districtNotOpenYet);

      final bought = projectGameState([...funded(), districtPurchased('d1', kFarmlandDistrictId, when: at(1))]);
      expect(commandsFor(bought).buyDistrict(kFarmlandDistrictId).rejection,
          GameRejection.districtAlreadyOwned);
    });

    test('refuses before the hamlet, and without the gems or materials', () {
      final outpost = projectGameState(funded().skip(1));
      expect(commandsFor(outpost).buyDistrict(kFarmlandDistrictId).rejection,
          GameRejection.townTierTooLow);

      final noGems = projectGameState(hamletWith(
          gems: price.gems - 1,
          lumber: price.materials[MaterialKind.lumber],
          stone: price.materials[MaterialKind.stone]));
      expect(commandsFor(noGems).buyDistrict(kFarmlandDistrictId).rejection,
          GameRejection.notEnoughGems);

      final noStone = projectGameState(hamletWith(
          gems: price.gems,
          lumber: price.materials[MaterialKind.lumber],
          stone: price.materials[MaterialKind.stone] - 1));
      expect(commandsFor(noStone).buyDistrict(kFarmlandDistrictId).rejection,
          GameRejection.notEnoughMaterials);
    });

    test('two devices buying at once are charged once', () {
      final state = projectGameState([
        ...funded(),
        districtPurchased('d1', kFarmlandDistrictId, when: at(1), cost: price),
        districtPurchased('d2', kFarmlandDistrictId, when: at(1), cost: price),
      ]);
      expect(state.person(robin).gems, 0);
      expect(state.townOf(robin).materials.isEmpty, isTrue);
      expect(state.warnings.map((w) => w.code), [GameWarningCode.duplicateDistrict]);
    });

    test('a district this build does not know is ignored and charges nothing', () {
      final state = projectGameState([
        ...funded(),
        districtPurchased('d1', 'skyIsland', when: at(1), cost: price),
      ]);
      expect(state.person(robin).gems, price.gems);
      expect(state.townOf(robin).districts.purchased, isEmpty);
      expect(state.warnings.map((w) => w.code), [GameWarningCode.unknownDistrict]);
    });
  });

  group('farm buildings', () {
    List<GameEvent> farmland({int lumber = 150, int stone = 150, int gems = 0}) => [
          ...hamletWith(gems: gems, lumber: lumber, stone: stone),
          districtPurchased('fl', kFarmlandDistrictId, when: at(1)),
        ];

    test('builds a farm on an open farmland plot for its cost', () {
      final state = projectGameState(farmland());
      final result = commandsFor(state).startFarmBuilding(0, FarmBuildingType.farm);
      expect(result.accepted, isTrue, reason: '$result');
      final started = result.events.whereType<DistrictBuildingStarted>().single;
      expect(started.districtId, kFarmlandDistrictId);
      expect(started.buildingKey, 'farm');
      expect(started.tier, 1);
      expect(started.cost, Balance.farmBuildingCost(FarmBuildingType.farm, 1));
      final after = state.apply(started);
      final building = after.townOf(robin).districts
          .buildingAt(const PlotAddress(kFarmlandDistrictId, 0))!;
      expect(building.farmType, FarmBuildingType.farm);
      expect(after.townOf(robin).materials[MaterialKind.lumber],
          150 - started.cost.materials[MaterialKind.lumber]);
    });

    test('refuses without the farmland, off the plots, and over another building', () {
      final none = projectGameState(hamletWith(lumber: 150, stone: 150));
      expect(commandsFor(none).startFarmBuilding(0, FarmBuildingType.farm).rejection,
          GameRejection.districtNotOwned);

      final state = projectGameState([
        ...farmland(),
        farmBuilt('f1', 0, FarmBuildingType.farm, when: at(2)),
      ]);
      expect(commandsFor(state).startFarmBuilding(-1, FarmBuildingType.farm).rejection,
          GameRejection.invalidPlot);
      expect(commandsFor(state).startFarmBuilding(_farmland.plotCount, FarmBuildingType.farm).rejection,
          GameRejection.invalidPlot);
      expect(commandsFor(state).startFarmBuilding(0, FarmBuildingType.orchard).rejection,
          GameRejection.plotOccupied);
      expect(commandsFor(state).startFarmBuilding(1, FarmBuildingType.farm).accepted, isTrue,
          reason: 'a town may have many farms');
    });

    test('one granary per town; upgrades wait for the Central Hall', () {
      final state = projectGameState([
        ...farmland(),
        farmBuilt('g1', 0, FarmBuildingType.granary, when: at(2)),
        farmBuilt('f1', 1, FarmBuildingType.farm, when: at(2)),
      ]);
      expect(commandsFor(state).startFarmBuilding(2, FarmBuildingType.granary).rejection,
          GameRejection.buildingAlreadyInHall);
      expect(commandsFor(state).startFarmBuilding(1, FarmBuildingType.farm).rejection,
          GameRejection.needsCentralHall);
    });

    test('refuses an upgrade under way and one the town cannot afford', () {
      final state = projectGameState([
        ...farmland(lumber: 0, stone: 0),
        built('ch1', 0, BuildingType.centralHall, when: at(1)),
        built('ch2', 0, BuildingType.centralHall, when: at(1), tier: 2),
        farmBuilt('f1', 0, FarmBuildingType.farm, when: at(2), tier: 1),
        farmBuilt('f2', 1, FarmBuildingType.farm, when: at(3), tier: 1),
        farmBuilt('f3', 1, FarmBuildingType.farm, when: at(4), tier: 2, completesAt: at(400)),
      ]);
      expect(commandsFor(state).startFarmBuilding(1, FarmBuildingType.farm).rejection,
          GameRejection.underConstruction);
      expect(commandsFor(state).startFarmBuilding(2, FarmBuildingType.farm).rejection,
          GameRejection.notEnoughMaterials);
    });

    test('the projection ignores a build on a district the town does not own, '
        'and a building key this build does not know', () {
      final state = projectGameState([
        ...hamletWith(lumber: 150, stone: 150),
        farmBuilt('f1', 0, FarmBuildingType.farm, when: at(2),
            cost: Balance.farmBuildingCost(FarmBuildingType.farm, 1)),
        DistrictBuildingStarted(
          eventId: 'f2', deviceId: 'dev-9', actorId: robin,
          occurredAt: at(3), createdAt: at(3),
          districtId: kFarmlandDistrictId, plotIndex: 1, buildingKey: 'windmill',
          tier: 1, cost: const Loot(gems: 5), completesAt: at(3),
        ),
      ]);
      expect(state.townOf(robin).districts.buildings, isEmpty);
      expect(state.townOf(robin).materials[MaterialKind.lumber], 150, reason: 'nothing charged');
      expect(state.warnings.map((w) => w.code),
          [GameWarningCode.districtNotOwned, GameWarningCode.unknownDistrict]);
    });
  });

  test('districts and farm tiers add to prosperity', () {
    final state = projectGameState([
      districtPurchased('fl', kFarmlandDistrictId, when: at(0)),
      farmBuilt('f1', 0, FarmBuildingType.farm, when: at(1)),
      farmBuilt('f2', 1, FarmBuildingType.farm, when: at(2)),
      farmBuilt('f3', 1, FarmBuildingType.farm, when: at(3), tier: 2, completesAt: at(100)),
    ]);
    expect(
      townProsperity(state.townOf(robin), townDecorationsPlaced: 0, festivalsHeld: 0, at: at(10)),
      Balance.prosperityPerDistrict + 2 * Balance.prosperityPerBuildingTier,
    );
    expect(
      townProsperity(state.townOf(robin), townDecorationsPlaced: 0, festivalsHeld: 0, at: at(100)),
      Balance.prosperityPerDistrict + 3 * Balance.prosperityPerBuildingTier,
    );
  });
}
