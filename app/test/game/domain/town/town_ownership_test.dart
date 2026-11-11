import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/reason_codes.dart';
import 'package:lootlog/game/domain/town/town_ownership.dart';
import 'package:lootlog/game/domain/town/town_view.dart';

import '../game_fixtures.dart';
import 'growth_fixtures.dart' show districtPurchased, farmBuilt;

MaterialBundle _lumber(int amount) => MaterialBundle({MaterialKind.lumber: amount});

final MaterialBundle _welcome = MaterialBundle({MaterialKind.stone: 7});

/// Robin and Sam build up the shared town, then it splits to Robin.
List<GameEvent> _sharedThenSplit() => [
      granted('a01', when: at(0), gems: 50, materials: _lumber(30)),
      claimed('a02', 'reward-a01', when: at(1)),
      unlocked('a03', 3, when: at(2), gemCost: 10),
      built('a04', 3, BuildingType.lumberyard, when: at(3)),
      built('a05', 0, BuildingType.quarry, when: at(4), actor: sam),
      townsSplit('a06', robin, when: at(10), welcome: _welcome),
    ];

void main() {
  group('before the split', () {
    test('every adult reads the one shared town', () {
      final state = projectGameState(_sharedThenSplit().take(5));
      expect(state.townsSplit, isFalse);
      expect(state.townOf(robin), state.townOf(sam));
      expect(state.townOf(robin).plots[3]?.building?.type, BuildingType.lumberyard);
      expect(state.townOf(sam).plots[0]?.building?.type, BuildingType.quarry);
      expect(state.townOf(sam).materials, _lumber(30));
      expect(state.towns, isEmpty);
    });

    test('town commands are counted per adult', () {
      final state = projectGameState(_sharedThenSplit().take(5));
      expect(state.ownership.hallCommandCounts, {robin: 2, sam: 1});
    });
  });

  group('the split', () {
    test('the shared town goes whole to the owner', () {
      final before = projectGameState(_sharedThenSplit().take(5));
      final after = projectGameState(_sharedThenSplit());
      expect(after.townsSplit, isTrue);
      expect(after.townOf(robin), before.townOf(robin));
      expect(after.towns.keys, [robin]);
    });

    test("a neighbour's town is the starter town plus the welcome grant", () {
      final state = projectGameState(_sharedThenSplit());
      expect(state.townOf(sam).plots, HallState.starter().plots);
      expect(state.townOf(sam).materials, _welcome);
    });

    test('after the split each town event acts on its actor only', () {
      final state = projectGameState([
        ..._sharedThenSplit(),
        built('b01', 1, BuildingType.storehouse, when: at(11), actor: sam),
        granted('b02', when: at(12), actor: sam, materials: _lumber(5)),
        claimed('b03', 'reward-b02', when: at(13), actor: sam),
        collected('b04', 'plot-3', _lumber(4), when: at(14)),
      ]);
      expect(state.townOf(sam).plots[1]?.building?.type, BuildingType.storehouse);
      expect(state.townOf(sam).plots[0]?.building, isNull);
      expect(state.townOf(sam).materials, _welcome + _lumber(5));
      expect(state.townOf(robin).plots[1]?.building, isNull);
      expect(state.townOf(robin).materials, _lumber(34));
    });

    test("an adult's first town event after the split starts from the welcome", () {
      final state = projectGameState([
        ..._sharedThenSplit(),
        unlocked('b01', 4, when: at(11), actor: sam),
      ]);
      expect(state.towns.keys, unorderedEquals([robin, sam]));
      expect(state.townOf(sam).plots.keys, unorderedEquals([0, 1, 2, 4]));
      expect(state.townOf(sam).materials, _welcome);
    });

    test('chests, expeditions and daily events pay into the own town', () {
      final state = projectGameState([
        ..._sharedThenSplit(),
        chestGranted('b01', 'chest-1', ChestType.wood, when: at(11), actor: sam),
        chestOpened('b02', 'chest-1', Loot(materials: _lumber(2)), when: at(12), actor: sam),
        expeditionStarted('b03', ExpeditionRegion.oldRoads, when: at(13), hero: sam),
        expeditionResolved('b04', ExpeditionRegion.oldRoads, _lumber(3), when: at(80), hero: sam),
      ]);
      expect(state.townOf(sam).materials, _welcome + _lumber(5));
      expect(state.townOf(robin).materials, _lumber(30));
    });

    test('the shift is per person: own logged days, freeze days excluded', () {
      final state = projectGameState([
        granted('d1', when: onDay(0), reasonCode: GameReasonCodes.dailyLog),
        granted('d2', when: onDay(1), actor: sam, reasonCode: GameReasonCodes.dailyLog),
        freezeUsed('d3', GameDay.fromInstant(onDay(2)), when: onDay(3)),
        granted('d4',
            when: onDay(2),
            actor: sam,
            rewardId: caravanRewardId(sam, GameDay.fromInstant(onDay(2))),
            reasonCode: GameReasonCodes.caravan),
      ]);
      expect(state.townActiveDaysOf(robin), {GameDay.fromInstant(onDay(0))});
      expect(state.townActiveDaysOf(sam), {GameDay.fromInstant(onDay(1))});
    });
  });

  test("the town view shows the viewing adult's own town", () {
    final state = projectGameState([
      ..._sharedThenSplit(),
      built('b01', 1, BuildingType.storehouse, when: at(11), actor: sam),
    ]);
    const adults = [
      TownAdult(memberId: robin, name: 'Robin', inAdventure: true),
      TownAdult(memberId: sam, name: 'Sam', inAdventure: true),
    ];
    final robinsView = TownView.from(state, robin, adults, at(12));
    final samsView = TownView.from(state, sam, adults, at(12));
    expect(robinsView.plots[3].buildingType, BuildingType.lumberyard);
    expect(robinsView.plots[1].buildingType, isNull);
    expect(samsView.plots[1].buildingType, BuildingType.storehouse);
    expect(samsView.plots[3].unlocked, isFalse);
  });

  group("a stale town event after the split never lands on the wrong town", () {
    // Sam's device had not seen the split (offline, or an older build) and
    // kept acting on the shared town, which Robin now owns.
    List<GameWarningCode> codesOf(GameState state) =>
        [for (final warning in state.warnings) warning.code];

    test('collecting a building that only stands in the owner town credits '
        'nothing, and the owner can still collect it once', () {
      final split = projectGameState(_sharedThenSplit());
      final stale = projectGameState([
        ..._sharedThenSplit(),
        collected('s1', 'plot-3', _lumber(6), when: at(30), actor: sam),
        collected('s2', 'plot-0', MaterialBundle({MaterialKind.stone: 4}),
            when: at(31), actor: sam),
      ]);
      expect(stale.townOf(sam), split.townOf(sam));
      expect(stale.townOf(robin), split.townOf(robin));
      expect(stale.townOf(robin).lastCollectedAt, isEmpty);
      expect(codesOf(stale),
          [GameWarningCode.unknownBuilding, GameWarningCode.unknownBuilding]);

      final owner = projectGameState([
        ..._sharedThenSplit(),
        collected('s1', 'plot-3', _lumber(6), when: at(30), actor: sam),
        collected('r1', 'plot-3', _lumber(6), when: at(32)),
      ]);
      expect(owner.townOf(robin).materials, _lumber(36));
      expect(owner.townOf(sam).materials, _welcome);
    });

    test("a collect naming another building's materials credits nothing", () {
      final state = projectGameState([
        ..._sharedThenSplit(),
        built('b1', 0, BuildingType.lumberyard, when: at(20), actor: sam),
        // The shared town's quarry on plot 0, collected from a stale view.
        collected('s1', 'plot-0', MaterialBundle({MaterialKind.stone: 4}),
            when: at(30), actor: sam),
      ]);
      expect(state.townOf(sam).materials, _welcome);
      expect(state.townOf(sam).lastCollectedAt, isEmpty);
      expect(codesOf(state), [GameWarningCode.unknownBuilding]);
    });

    test('building on a plot locked in the actor town is not applied or charged', () {
      final split = projectGameState(_sharedThenSplit());
      final state = projectGameState([
        ..._sharedThenSplit(),
        built('s1', 3, BuildingType.storehouse,
            when: at(30), actor: sam, cost: Loot(materials: _welcome)),
      ]);
      expect(state.townOf(sam), split.townOf(sam));
      expect(state.townOf(robin), split.townOf(robin));
      expect(codesOf(state), [GameWarningCode.plotLocked]);
    });

    test('upgrading a building the actor town does not have is not applied', () {
      final split = projectGameState(_sharedThenSplit());
      final state = projectGameState([
        ..._sharedThenSplit(),
        // The shared town's quarry (plot 0) to tier 2, from a stale view.
        built('s1', 0, BuildingType.quarry,
            when: at(30), actor: sam, tier: 2, cost: Loot(materials: _welcome)),
      ]);
      expect(state.townOf(sam), split.townOf(sam));
      expect(state.townOf(robin), split.townOf(robin));
      expect(codesOf(state), [GameWarningCode.unknownBuilding]);
    });

    test('unlocking a plot already open in the actor town charges nothing', () {
      final state = projectGameState([
        ..._sharedThenSplit(),
        granted('g1', when: at(20), actor: sam, gems: 30),
        claimed('g2', 'reward-g1', when: at(21), actor: sam),
        unlocked('s1', 1, when: at(30), actor: sam, gemCost: 20),
      ]);
      expect(state.person(sam).gems, 30);
      expect(codesOf(state), [GameWarningCode.duplicateUnlock]);
    });
  });

  group('a build the actor cannot pay for after the split is not applied', () {
    // An older build or a stale device can write a cost the actor's own town
    // and wallet do not hold. Clamping the pool would make it nearly free.
    List<GameWarningCode> codesOf(GameState state) =>
        [for (final warning in state.warnings) warning.code];

    test('a building whose materials the town lacks stands nowhere, charged nothing', () {
      final split = projectGameState(_sharedThenSplit());
      final state = projectGameState([
        ..._sharedThenSplit(),
        built('s1', 1, BuildingType.lumberyard, when: at(30), actor: sam, cost: Loot(materials: _lumber(20))),
      ]);
      expect(state.townOf(sam), split.townOf(sam));
      expect(codesOf(state), [GameWarningCode.materialsClamped]);
    });

    test('a build the town can pay for still applies and is charged', () {
      final state = projectGameState([
        ..._sharedThenSplit(),
        built('s1', 1, BuildingType.lumberyard, when: at(30), actor: sam, cost: Loot(materials: _welcome)),
      ]);
      expect(state.townOf(sam).plots[1]?.building?.type, BuildingType.lumberyard);
      expect(state.townOf(sam).materials, const MaterialBundle.empty());
      expect(state.warnings, isEmpty);
    });

    test('a plot unlock the wallet cannot pay for is not applied', () {
      final split = projectGameState(_sharedThenSplit());
      final state = projectGameState([
        ..._sharedThenSplit(),
        unlocked('s1', 5, when: at(30), actor: sam, gemCost: 20),
      ]);
      expect(state.townOf(sam), split.townOf(sam));
      expect(state.person(sam).gems, 0);
      expect(codesOf(state), [GameWarningCode.gemsClamped]);
    });

    test('a district or farm building the actor cannot pay for is not applied', () {
      final split = projectGameState(_sharedThenSplit());
      final state = projectGameState([
        ..._sharedThenSplit(),
        districtPurchased('s1', 'farmland', when: at(30), actor: sam, cost: const Loot(gems: 40)),
      ]);
      expect(state.townOf(sam), split.townOf(sam));
      expect(codesOf(state), [GameWarningCode.gemsClamped]);
      final farmed = projectGameState([
        ..._sharedThenSplit(),
        districtPurchased('s1', 'farmland', when: at(30), actor: sam),
        farmBuilt('s2', 0, FarmBuildingType.farm, when: at(31), actor: sam, cost: Loot(materials: _lumber(20))),
      ]);
      expect(farmed.townOf(sam).districts.buildings, isEmpty);
      expect(codesOf(farmed), [GameWarningCode.materialsClamped]);
    });
  });

  group('convergence', () {
    test('device B acted between two competing splits: both devices converge, nothing doubles', () {
      final shared = _sharedThenSplit().take(5).toList();
      // Device A split first, to Robin.
      final deviceA = [
        townsSplit('x-a', robin, when: at(20), welcome: _welcome),
        collected('x-a1', 'plot-3', _lumber(6), when: at(25)),
      ];
      // Device B, unsynced, split a minute later to Sam and kept playing:
      // Sam collected and upgraded "his" shared quarry, and Robin built in
      // what B showed as Robin's new welcome town.
      final deviceB = [
        townsSplit('x-b', sam, when: at(21), welcome: _lumber(10)),
        collected('x-b1', 'plot-0', MaterialBundle({MaterialKind.stone: 4}), when: at(22), actor: sam),
        built('x-b2', 0, BuildingType.quarry, when: at(23), actor: sam, tier: 2, cost: Loot(materials: _lumber(10))),
        built('x-b3', 1, BuildingType.storehouse, when: at(24), cost: Loot(materials: _lumber(10))),
      ];
      final onA = projectGameState([...shared, ...deviceA, ...deviceB]);
      final onB = projectGameState([...deviceB, ...shared, ...deviceA].reversed);
      expect(onA, onB);
      expect(onA.ownership.split?.ownerId, robin, reason: 'the earliest split stands');
      // Sam's quarry collect and upgrade were in the town that went to
      // Robin: credited and charged nowhere.
      expect(onA.townOf(sam).materials, _welcome);
      expect(onA.townOf(sam).plots.values.every((plot) => plot.building == null), isTrue);
      expect(onA.townOf(robin).plots[0]?.building?.tier, 1);
      // Robin's build on B fits Robin's real town and is paid from it, once.
      expect(onA.townOf(robin).plots[1]?.building?.type, BuildingType.storehouse);
      expect(onA.townOf(robin).materials, _lumber(26),
          reason: '30 shared + 6 collected - 10 paid once');
      final random = Random(11);
      for (var round = 0; round < 20; round++) {
        final shuffled = [...shared, ...deviceA, ...deviceB]..shuffle(random);
        expect(projectGameState(shuffled), onA);
      }
    });

    test('two devices emitting different splits agree on the earliest', () {
      final shared = _sharedThenSplit().take(5).toList();
      final fromRobin = townsSplit('z-robin', robin, when: at(20), welcome: _welcome);
      final fromSam = townsSplit('z-sam', sam, when: at(21), welcome: _lumber(1));
      final later = built('z-later', 1, BuildingType.storehouse, when: at(22), actor: sam);
      final events = [...shared, fromRobin, fromSam, later];

      final reference = projectGameState(events);
      expect(reference.ownership.split?.ownerId, robin);
      expect(reference.townOf(sam).materials, _welcome);
      final random = Random(7);
      for (var round = 0; round < 20; round++) {
        final shuffled = [...events]..shuffle(random);
        expect(projectGameState(shuffled), reference);
      }
    });

    test('a same-instant tie is broken by event id', () {
      final first = townsSplit('t-1', sam, when: at(20));
      final second = townsSplit('t-2', robin, when: at(20));
      expect(projectGameState([second, first]).ownership.split?.ownerId, sam);
      expect(projectGameState([first, second]).ownership.split?.ownerId, sam);
    });

    test('a town event stamped before the split applies to the shared town '
        'whenever it arrives', () {
      final split = townsSplit('s-1', robin, when: at(20), welcome: _welcome);
      final early = built('s-0', 1, BuildingType.storehouse, when: at(15), actor: sam);
      final arrivedLate = projectGameState([split, early]);
      expect(arrivedLate, projectGameState([early, split]));
      // Sam built it in the shared town, which Robin kept.
      expect(arrivedLate.townOf(robin).plots[1]?.building?.type, BuildingType.storehouse);
      expect(arrivedLate.townOf(sam).plots[1]?.building, isNull);

      final incremental = GameState.initial().apply(split);
      expect(() => incremental.apply(early), throwsStateError);
    });

    test('the incremental fold matches the rebuild', () {
      final events = [
        ..._sharedThenSplit(),
        townsSplit('a07', sam, when: at(11)),
        unlocked('a08', 4, when: at(12), actor: sam),
      ];
      var state = GameState.initial();
      for (final event in events) {
        state = state.apply(event);
      }
      expect(state, projectGameState(events));
    });
  });

  group('who keeps the shared town', () {
    test('the Adventure adult with the most town commands', () {
      expect(townsSplitOwner({robin: 2, sam: 5}, [robin, sam]), sam);
    });

    test('ties go to the smallest member id', () {
      expect(townsSplitOwner({robin: 3, sam: 3}, [sam, robin]), robin);
    });

    test('with no town activity, the smallest Adventure member id', () {
      expect(townsSplitOwner(const {}, [sam, robin]), robin);
    });

    test('a Standard adult never keeps it', () {
      expect(townsSplitOwner({sam: 9}, [robin]), robin);
    });

    test('nobody without an Adventure adult', () {
      expect(townsSplitOwner({robin: 1}, const []), isNull);
    });
  });

  test('Balance has a welcome grant for new neighbours', () {
    expect(Balance.welcomeGrant.isEmpty, isFalse);
  });
}
