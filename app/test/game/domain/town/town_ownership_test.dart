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

  group('convergence', () {
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
