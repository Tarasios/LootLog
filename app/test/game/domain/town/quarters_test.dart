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
import 'package:lootlog/game/domain/town/quarters.dart';

import '../game_fixtures.dart';
import 'growth_fixtures.dart';

/// Plenty of every material (the tier-5 Storehouse holds it all).
final MaterialBundle _plenty = MaterialBundle({
  for (final kind in MaterialKind.values) kind: 2500,
});

void main() {
  var ids = 0;
  GameCommands commandsFor(GameState state, {DateTime? now, String actor = robin}) =>
      GameCommands(
        state: state,
        clock: FixedClock(now ?? at(10)),
        actorId: actor,
        stamp: GameEventStamp(deviceId: 'dev-1', newEventId: () => 'cmd-${ids++}'),
      );

  GameState rich(TownTier tier, {List<GameEvent> more = const []}) =>
      projectGameState([...tierWith(tier, gems: 2000, materials: _plenty), ...more]);

  group('the catalogue', () {
    test('the guard post and residential quarter open at the village, the park and market row at the town', () {
      expect(districtById(kGuardPostDistrictId)!.requiredTier, TownTier.village);
      expect(districtById(kResidentialDistrictId)!.requiredTier, TownTier.village);
      expect(districtById(kParkDistrictId)!.requiredTier, TownTier.town);
      expect(districtById(kMarketRowDistrictId)!.requiredTier, TownTier.town);
      for (final id in [kGuardPostDistrictId, kResidentialDistrictId, kParkDistrictId, kMarketRowDistrictId]) {
        final district = districtById(id)!;
        expect(district.purchasable, isTrue, reason: id);
        expect(district.plotCount, greaterThan(0), reason: id);
        expect(district.price.gems, greaterThan(0), reason: id);
        expect(district.buildingKeys, hasLength(3), reason: id);
      }
    });

    test('castle hill is a city teaser, never for sale', () {
      final hill = districtById(kCastleHillDistrictId)!;
      expect(hill.requiredTier, TownTier.city);
      expect(hill.purchasable, isFalse);
    });

    test('every civic building belongs to exactly the district that lists it', () {
      for (final type in CivicBuildingType.values) {
        final spec = Balance.civicBuildings[type]!;
        final district = districtById(spec.districtId)!;
        expect(district.allows(type.name), isTrue, reason: type.name);
        expect(civicBuildingByKey(type.name), type);
      }
      expect(civicBuildingByKey('farm'), isNull);
    });
  });

  group('buying the new districts', () {
    test('a village buys the guard post and remembers when', () {
      final state = rich(TownTier.village);
      final result = commandsFor(state).buyDistrict(kGuardPostDistrictId);
      expect(result.accepted, isTrue, reason: '$result');
      final after = state.apply(result.events.single);
      expect(after.townOf(robin).districts.owns(kGuardPostDistrictId), isTrue);
      expect(after.townOf(robin).districts.purchasedAt[kGuardPostDistrictId], at(10));
      expect(after.person(robin).gems, 2000 - Balance.guardPostGemPrice);
    });

    test('a hamlet waits for the guard post, and a village for the park', () {
      expect(commandsFor(rich(TownTier.hamlet)).buyDistrict(kGuardPostDistrictId).rejection,
          GameRejection.townTierTooLow);
      expect(commandsFor(rich(TownTier.village)).buyDistrict(kParkDistrictId).rejection,
          GameRejection.townTierTooLow);
      expect(commandsFor(rich(TownTier.town)).buyDistrict(kParkDistrictId).accepted, isTrue);
    });

    test('a district bought on two devices keeps the earlier instant and is charged once', () {
      final state = projectGameState([
        ...tierWith(TownTier.village, gems: 1000),
        districtPurchased('p1', kResidentialDistrictId, when: at(5), cost: const Loot(gems: 80)),
        districtPurchased('p2', kResidentialDistrictId, when: at(6), cost: const Loot(gems: 80)),
      ]);
      expect(state.townOf(robin).districts.purchasedAt[kResidentialDistrictId], at(5));
      expect(state.person(robin).gems, 920);
    });
  });

  group('startCivicBuilding', () {
    GameState withQuarter(String districtId, {TownTier tier = TownTier.town, List<GameEvent> more = const []}) =>
        rich(tier, more: [districtPurchased('q', districtId, when: at(1)), ...more]);

    test('builds a cottage on an empty residential plot for its price', () {
      final state = withQuarter(kResidentialDistrictId);
      final result = commandsFor(state).startCivicBuilding(kResidentialDistrictId, 0, CivicBuildingType.cottage);
      expect(result.accepted, isTrue, reason: '$result');
      final started = result.events.single as CivicBuildingStarted;
      expect(started.buildingKey, 'cottage');
      expect(started.tier, 1);
      expect(started.cost, Balance.civicBuildingCost(CivicBuildingType.cottage, 1).cost);
      final after = state.apply(started);
      final building = after.townOf(robin).districts.buildingAt(const PlotAddress(kResidentialDistrictId, 0))!;
      expect(building.civicType, CivicBuildingType.cottage);
      expect(after.warnings, isEmpty);
    });

    test('only the district\'s own buildings, on its own plots, in a district it owns', () {
      final state = withQuarter(kResidentialDistrictId);
      final commands = commandsFor(state);
      expect(commands.startCivicBuilding(kResidentialDistrictId, 0, CivicBuildingType.watchtower).rejection,
          GameRejection.wrongDistrict);
      expect(commands.startCivicBuilding(kGuardPostDistrictId, 0, CivicBuildingType.watchtower).rejection,
          GameRejection.districtNotOwned);
      expect(commands.startCivicBuilding(kResidentialDistrictId, Balance.residentialPlotCount,
              CivicBuildingType.cottage).rejection,
          GameRejection.invalidPlot);
    });

    test('a unique building stands once; others may repeat', () {
      final state = withQuarter(kResidentialDistrictId, more: [
        civicBuilt('w', kResidentialDistrictId, 0, CivicBuildingType.well, when: at(2)),
        civicBuilt('c', kResidentialDistrictId, 1, CivicBuildingType.cottage, when: at(2)),
      ]);
      final commands = commandsFor(state);
      expect(commands.startCivicBuilding(kResidentialDistrictId, 2, CivicBuildingType.well).rejection,
          GameRejection.buildingAlreadyInHall);
      expect(commands.startCivicBuilding(kResidentialDistrictId, 2, CivicBuildingType.cottage).accepted, isTrue);
    });

    test('upgrades one tier at a time, after the last one finishes, under the Central Hall', () {
      final busy = withQuarter(kResidentialDistrictId, more: [
        civicBuilt('c', kResidentialDistrictId, 0, CivicBuildingType.cottage,
            when: at(2), completesAt: at(100)),
      ]);
      expect(commandsFor(busy).startCivicBuilding(kResidentialDistrictId, 0, CivicBuildingType.cottage).rejection,
          GameRejection.underConstruction);
      final done = withQuarter(kResidentialDistrictId, more: [
        civicBuilt('c', kResidentialDistrictId, 0, CivicBuildingType.cottage, when: at(2)),
      ]);
      final upgrade = commandsFor(done).startCivicBuilding(kResidentialDistrictId, 0, CivicBuildingType.cottage);
      expect((upgrade.events.single as CivicBuildingStarted).tier, 2);
      expect((upgrade.events.single as CivicBuildingStarted).completesAt,
          at(10).add(Balance.buildTimeByTier[1]));
      final lowHall = projectGameState([
        ...tierWith(TownTier.town, gems: 2000, materials: _plenty, hallTier: 1),
        districtPurchased('q', kResidentialDistrictId, when: at(1)),
        civicBuilt('c', kResidentialDistrictId, 0, CivicBuildingType.cottage, when: at(2)),
      ]);
      expect(commandsFor(lowHall).startCivicBuilding(kResidentialDistrictId, 0, CivicBuildingType.cottage).rejection,
          GameRejection.needsCentralHall);
    });

    test('is refused when the wallet or the stores are short', () {
      final poor = projectGameState([
        ...tierWith(TownTier.town),
        districtPurchased('q', kResidentialDistrictId, when: at(1)),
      ]);
      expect(commandsFor(poor).startCivicBuilding(kResidentialDistrictId, 0, CivicBuildingType.cottage).rejection,
          GameRejection.notEnoughMaterials);
    });
  });

  group('the projection', () {
    test('sets aside a civic building it does not know, or on a district not owned, charging nothing', () {
      final state = projectGameState([
        ...tierWith(TownTier.town, gems: 500),
        districtPurchased('q', kResidentialDistrictId, when: at(1)),
        CivicBuildingStarted(
          eventId: 'x1', deviceId: 'dev-1', actorId: robin, occurredAt: at(2), createdAt: at(2),
          districtId: kResidentialDistrictId, plotIndex: 0, buildingKey: 'skyTower', tier: 1,
          cost: const Loot(gems: 10), completesAt: at(2),
        ),
        civicBuilt('x2', kGuardPostDistrictId, 0, CivicBuildingType.watchtower,
            when: at(3), cost: const Loot(gems: 10)),
        civicBuilt('x3', kResidentialDistrictId, 0, CivicBuildingType.watchtower,
            when: at(4), cost: const Loot(gems: 10)),
      ]);
      expect(state.townOf(robin).districts.buildings, isEmpty);
      expect(state.person(robin).gems, 500);
      expect(state.warnings.map((w) => w.code), [
        GameWarningCode.unknownDistrict,
        GameWarningCode.districtNotOwned,
        GameWarningCode.unknownDistrict,
      ]);
    });

    test('a farm event naming a civic building is set aside, as on a stage-2 build', () {
      final state = projectGameState([
        ...tierWith(TownTier.town),
        districtPurchased('q', kResidentialDistrictId, when: at(1)),
        DistrictBuildingStarted(
          eventId: 'x1', deviceId: 'dev-1', actorId: robin, occurredAt: at(2), createdAt: at(2),
          districtId: kResidentialDistrictId, plotIndex: 0, buildingKey: 'cottage', tier: 1,
          cost: Loot.none, completesAt: at(2),
        ),
      ]);
      expect(state.townOf(robin).districts.buildings, isEmpty);
      expect(state.warnings.single.code, GameWarningCode.unknownDistrict);
    });

    test('a second device\'s copy of the same upgrade is ignored and not charged', () {
      final state = projectGameState([
        ...tierWith(TownTier.town, gems: 500),
        districtPurchased('q', kResidentialDistrictId, when: at(1)),
        civicBuilt('c1', kResidentialDistrictId, 0, CivicBuildingType.cottage, when: at(2)),
        civicBuilt('c2a', kResidentialDistrictId, 0, CivicBuildingType.cottage,
            when: at(3), tier: 2, cost: const Loot(gems: 10)),
        civicBuilt('c2b', kResidentialDistrictId, 0, CivicBuildingType.cottage,
            when: at(4), tier: 2, cost: const Loot(gems: 10)),
      ]);
      expect(state.person(robin).gems, 490);
      expect(state.warnings.single.code, GameWarningCode.duplicateBuild);
    });

    test('after the split, a civic building the town cannot pay for is not applied', () {
      final state = projectGameState([
        townsSplit('split', robin, when: at(-20)),
        ...tierWith(TownTier.town, gems: 5),
        districtPurchased('q', kResidentialDistrictId, when: at(1)),
        civicBuilt('c1', kResidentialDistrictId, 0, CivicBuildingType.cottage,
            when: at(2), cost: const Loot(gems: 10)),
      ]);
      expect(state.townOf(robin).districts.buildings, isEmpty);
      expect(state.person(robin).gems, 5);
      expect(state.warnings.single.code, GameWarningCode.gemsClamped);
    });
  });

  group('prosperity', () {
    test('civic tiers count like any building, and park buildings add their own', () {
      final base = rich(TownTier.town, more: [
        districtPurchased('q', kResidentialDistrictId, when: at(1)),
        districtPurchased('p', kParkDistrictId, when: at(1)),
      ]);
      final built = base
          .apply(civicBuilt('c', kResidentialDistrictId, 0, CivicBuildingType.cottage, when: at(2)))
          .apply(civicBuilt('g', kParkDistrictId, 0, CivicBuildingType.garden, when: at(3)));
      final gain = prosperityOf(built, robin, at(10)) - prosperityOf(base, robin, at(10));
      expect(gain,
          2 * Balance.prosperityPerBuildingTier +
              Balance.civicBuildings[CivicBuildingType.garden]!.prosperityByTier.first);
    });

    test('a building under construction adds nothing extra until it finishes', () {
      final base = rich(TownTier.town, more: [districtPurchased('p', kParkDistrictId, when: at(1))]);
      final building = base.apply(civicBuilt('g', kParkDistrictId, 0, CivicBuildingType.garden,
          when: at(2), completesAt: at(60)));
      expect(prosperityOf(building, robin, at(10)), prosperityOf(base, robin, at(10)));
      expect(civicProsperityAt(building.townOf(robin), at(60)),
          Balance.civicBuildings[CivicBuildingType.garden]!.prosperityByTier.first);
    });
  });
}
