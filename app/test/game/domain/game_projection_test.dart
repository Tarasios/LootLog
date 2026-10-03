import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/reason_codes.dart';

import 'game_fixtures.dart';

MaterialBundle mats(Map<MaterialKind, int> m) => MaterialBundle(m);

List<GameWarningCode> codes(GameState s) => [for (final w in s.warnings) w.code];

/// A ledger-like history touching every event type and both adults, with a
/// few same-instant ties so the eventId tiebreak matters.
List<GameEvent> richHistory() => [
      partyJoined('a01', 'party-1', when: at(0)),
      partyJoined('a02', 'party-1', when: at(0), actor: sam),
      granted('a03', when: at(1), gems: 40, materials: mats({MaterialKind.lumber: 10})),
      granted('a04', when: at(1), actor: sam, gems: 15, tokens: 2),
      claimed('a05', 'reward-a03', when: at(2)),
      claimed('a06', 'reward-a04', when: at(2), actor: sam),
      unlocked('a07', 3, when: at(3), gemCost: 20),
      built('a08', 3, BuildingType.lumberyard,
          when: at(4), cost: Loot(gems: 5, materials: mats({MaterialKind.lumber: 4}))),
      collected('a09', 'plot-3', mats({MaterialKind.lumber: 6}), when: at(5)),
      gearUpgraded('a10', when: at(6), cost: const Loot(gems: 3)),
      customized('a11', 'cloak', 'green', when: at(6), hero: sam),
      expeditionStarted('a12', ExpeditionRegion.oldRoads, when: at(7), hero: sam),
      expeditionResolved('a13', ExpeditionRegion.oldRoads,
          mats({MaterialKind.hide: 2}), when: at(67), hero: sam),
      chestGranted('a14', 'chest-1', ChestType.wood, when: at(68)),
      chestOpened('a15', 'chest-1',
          Loot(gems: 2, materials: mats({MaterialKind.stone: 3})), when: at(69)),
      granted('a16', when: onDay(0), reasonCode: GameReasonCodes.dailyLog, gems: 1),
      granted('a17', when: onDay(2), reasonCode: GameReasonCodes.dailyLog, gems: 1),
      freezeUsed('a18', GameDay.fromInstant(onDay(1)), when: onDay(2), actor: sam),
      freezeUsed('a19', GameDay.fromInstant(onDay(1)), when: onDay(2)),
      ritualStep('a20', const Month(2026, 9), RitualStep.reconcile, when: at(70)),
      ritualStep('a21', const Month(2026, 9), RitualStep.review, when: at(70)),
      bossFight('a22', const Month(2026, 9),
          when: at(71), rewards: Loot(gems: 9, materials: mats({MaterialKind.trophy: 1}))),
      bossFight('a23', const Month(2026, 9), when: at(72), rewards: const Loot(gems: 9)),
      partyLeft('a24', 'party-1', when: at(73), actor: sam),
      unlocked('a25', 3, when: at(74), gemCost: 20, actor: sam),
    ];

void main() {
  group('initial state', () {
    test('the hall starts with the starting plots unlocked and empty', () {
      final s = projectGameState(const []);
      expect(s.hall.plots.keys, List.generate(Balance.startingPlotCount, (i) => i));
      expect(s.hall.plots.values.every((p) => p.building == null), isTrue);
      expect(s.hall.materials.isEmpty, isTrue);
      expect(s.warnings, isEmpty);
    });

    test('an unseen person reads as an empty person', () {
      final p = projectGameState(const []).person(robin);
      expect(p.gems, 0);
      expect(p.freezeTokens, 0);
      expect(p.unclaimedRewards, isEmpty);
      expect(p.streak.count, 0);
      expect(p.partyId, isNull);
    });
  });

  group('rewards', () {
    test('a grant waits unclaimed; claiming credits wallet, pool and tokens', () {
      final grant = granted('g1',
          when: at(0), gems: 5, materials: mats({MaterialKind.ore: 2}), tokens: 1);
      final pending = projectGameState([grant]);
      expect(pending.person(robin).unclaimedRewards.keys, ['reward-g1']);
      expect(pending.person(robin).gems, 0);

      final s = projectGameState([grant, claimed('c1', 'reward-g1', when: at(1))]);
      final p = s.person(robin);
      expect(p.unclaimedRewards, isEmpty);
      expect(p.gems, 5);
      expect(p.freezeTokens, 1);
      expect(s.hall.materials[MaterialKind.ore], 2);
    });

    test('the same rewardId granted twice is credited once, even after claim', () {
      final s = projectGameState([
        granted('g1', when: at(0), rewardId: 'r', gems: 5),
        granted('g2', when: at(1), rewardId: 'r', gems: 5),
        claimed('c1', 'r', when: at(2)),
        granted('g3', when: at(3), rewardId: 'r', gems: 5),
        claimed('c2', 'r', when: at(4)),
      ]);
      expect(s.person(robin).gems, 5);
      expect(s.person(robin).unclaimedRewards, isEmpty);
      expect(codes(s), [GameWarningCode.unknownReward]);
    });

    test('claiming a reward that was never granted credits nothing', () {
      final s = projectGameState([claimed('c1', 'nope', when: at(0))]);
      expect(s.person(robin).gems, 0);
      expect(codes(s), [GameWarningCode.unknownReward]);
    });
  });

  group('hall', () {
    test('unlocking a plot charges the actor; a duplicate unlock is free', () {
      final s = projectGameState([
        granted('g', when: at(0), gems: 50),
        claimed('c', 'reward-g', when: at(1)),
        unlocked('u1', 5, when: at(2), gemCost: 30),
        unlocked('u2', 5, when: at(3), gemCost: 30),
      ]);
      expect(s.hall.plots.containsKey(5), isTrue);
      expect(s.person(robin).gems, 20);
      expect(codes(s), [GameWarningCode.duplicateUnlock]);
    });

    test('a debit larger than the wallet clamps to zero and warns', () {
      final s = projectGameState([unlocked('u1', 5, when: at(0), gemCost: 30)]);
      expect(s.person(robin).gems, 0);
      expect(s.hall.plots.containsKey(5), isTrue);
      expect(codes(s), [GameWarningCode.gemsClamped]);
      expect(s.warnings.single.eventId, 'u1');
    });

    test('starting a building records type, tier and completion and pays the '
        'cost from the actor and the shared pool', () {
      final s = projectGameState([
        granted('g', when: at(0), gems: 10, materials: mats({MaterialKind.stone: 8})),
        claimed('c', 'reward-g', when: at(1)),
        built('b1', 0, BuildingType.quarry,
            when: at(2),
            tier: 2,
            completesAt: at(62),
            cost: Loot(gems: 4, materials: mats({MaterialKind.stone: 5}))),
      ]);
      final b = s.hall.plots[0]!.building!;
      expect(b.type, BuildingType.quarry);
      expect(b.tier, 2);
      expect(b.startedAt, at(2));
      expect(b.completesAt, at(62));
      expect(s.person(robin).gems, 6);
      expect(s.hall.materials[MaterialKind.stone], 3);
      expect(s.warnings, isEmpty);
    });

    test('materials the pool lacks clamp per kind and warn', () {
      final s = projectGameState([
        built('b1', 0, BuildingType.quarry,
            when: at(0), cost: Loot(materials: mats({MaterialKind.stone: 5}))),
      ]);
      expect(s.hall.materials[MaterialKind.stone], 0);
      expect(codes(s), [GameWarningCode.materialsClamped]);
    });

    test('an upgrade replaces the tier; a stale or conflicting build is ignored '
        'without charging', () {
      final s = projectGameState([
        granted('g', when: at(0), gems: 100),
        claimed('c', 'reward-g', when: at(1)),
        built('b1', 0, BuildingType.forge, when: at(2), cost: const Loot(gems: 10)),
        built('b2', 0, BuildingType.forge, when: at(3), tier: 2, cost: const Loot(gems: 10)),
        built('b3', 0, BuildingType.forge, when: at(4), tier: 2, cost: const Loot(gems: 10)),
        built('b4', 0, BuildingType.mine, when: at(5), cost: const Loot(gems: 10)),
      ]);
      expect(s.hall.plots[0]!.building!.type, BuildingType.forge);
      expect(s.hall.plots[0]!.building!.tier, 2);
      expect(s.person(robin).gems, 80);
      expect(codes(s), [GameWarningCode.duplicateBuild, GameWarningCode.plotOccupied]);
    });

    test('building on a locked plot still applies (the event is the truth) '
        'but warns', () {
      final s = projectGameState([built('b1', 9, BuildingType.vault, when: at(0))]);
      expect(s.hall.plots[9]!.building!.type, BuildingType.vault);
      expect(codes(s), [GameWarningCode.plotLocked]);
    });

    test('collecting adds to the shared pool and stamps lastCollectedAt', () {
      final s = projectGameState([
        built('b1', 1, BuildingType.mine, when: at(0)),
        collected('m1', 'plot-1', mats({MaterialKind.ore: 4}), when: at(30)),
        collected('m2', 'plot-1', mats({MaterialKind.ore: 2}), when: at(90), actor: sam),
      ]);
      expect(s.hall.materials[MaterialKind.ore], 6);
      expect(s.hall.lastCollectedAt['plot-1'], at(90));
      expect(s.hall.plots[1]!.buildingId, 'plot-1');
      expect(s.warnings, isEmpty);
    });

    test('collecting from an unknown building still credits but warns', () {
      final s = projectGameState([
        collected('m1', 'plot-7', mats({MaterialKind.ore: 4}), when: at(0)),
      ]);
      expect(s.hall.materials[MaterialKind.ore], 4);
      expect(codes(s), [GameWarningCode.unknownBuilding]);
    });
  });

  group('hero', () {
    test('gear upgrades equip the slot and the payer pays', () {
      final s = projectGameState([
        granted('g', when: at(0), actor: sam, gems: 10),
        claimed('c', 'reward-g', when: at(1), actor: sam),
        gearUpgraded('x1',
            when: at(2), hero: robin, actor: sam, tier: 2, cost: const Loot(gems: 7)),
        gearUpgraded('x2',
            when: at(3), hero: robin, actor: sam, tier: 2, cost: const Loot(gems: 7)),
      ]);
      expect(s.person(robin).hero.gear['weapon'], const GearPiece('sword', 2));
      expect(s.person(sam).gems, 3);
      expect(codes(s), [GameWarningCode.duplicateGear]);
    });

    test('customization sets a cosmetic field, last write wins', () {
      final s = projectGameState([
        customized('h1', 'hair', 'red', when: at(0)),
        customized('h2', 'hair', 'blue', when: at(1)),
      ]);
      expect(s.person(robin).hero.cosmetics, {'hair': 'blue'});
    });
  });

  group('expeditions', () {
    test('start records the active expedition; resolve banks loot to the pool',
        () {
      final started = projectGameState([
        expeditionStarted('s1', ExpeditionRegion.theWilds, when: at(0), minutes: 90),
      ]);
      final active = started.person(robin).activeExpedition!;
      expect(active.region, ExpeditionRegion.theWilds);
      expect(active.endsAt, at(90));

      final s = projectGameState([
        expeditionStarted('s1', ExpeditionRegion.theWilds, when: at(0), minutes: 90),
        expeditionResolved('r1', ExpeditionRegion.theWilds,
            mats({MaterialKind.herbs: 5}), when: at(95)),
      ]);
      expect(s.person(robin).activeExpedition, isNull);
      expect(s.person(robin).lastExpedition!.loot[MaterialKind.herbs], 5);
      expect(s.hall.materials[MaterialKind.herbs], 5);
    });

    test('a second start while away is ignored; resolving with nothing active '
        'credits nothing', () {
      final s = projectGameState([
        expeditionStarted('s1', ExpeditionRegion.theWilds, when: at(0)),
        expeditionStarted('s2', ExpeditionRegion.oldRoads, when: at(1)),
        expeditionResolved('r1', ExpeditionRegion.theWilds,
            mats({MaterialKind.herbs: 5}), when: at(95)),
        expeditionResolved('r2', ExpeditionRegion.theWilds,
            mats({MaterialKind.herbs: 5}), when: at(96)),
      ]);
      expect(s.hall.materials[MaterialKind.herbs], 5);
      expect(codes(s), [
        GameWarningCode.expeditionAlreadyActive,
        GameWarningCode.noActiveExpedition,
      ]);
    });
  });

  group('chests', () {
    test('granted chests wait unopened; opening credits the contents once', () {
      final s = projectGameState([
        chestGranted('k1', 'chest-1', ChestType.gold, when: at(0)),
        chestGranted('k2', 'chest-2', ChestType.iron, when: at(1)),
        chestOpened('o1', 'chest-1',
            Loot(gems: 4, materials: mats({MaterialKind.crystal: 1}), tokens: 1),
            when: at(2)),
        chestOpened('o2', 'chest-1', const Loot(gems: 4), when: at(3)),
        chestGranted('k3', 'chest-1', ChestType.gold, when: at(4)),
      ]);
      final p = s.person(robin);
      expect(p.unopenedChests, {'chest-2': ChestType.iron});
      expect(p.gems, 4);
      expect(p.freezeTokens, 1);
      expect(s.hall.materials[MaterialKind.crystal], 1);
      expect(codes(s), [GameWarningCode.unknownChest]);
    });
  });

  group('streaks', () {
    test('streak-qualifying rewards and freezes form one run of days', () {
      final s = projectGameState([
        granted('t0', when: at(0), tokens: 1),
        claimed('t1', 'reward-t0', when: at(1)),
        granted('d0', when: onDay(0), reasonCode: GameReasonCodes.dailyLog),
        freezeUsed('f1', GameDay.fromInstant(onDay(1)), when: onDay(2)),
        granted('d2', when: onDay(2), reasonCode: GameReasonCodes.noSpendCheckIn),
        granted('x', when: onDay(3), reasonCode: 'weekly.reconcile'),
      ]);
      final p = s.person(robin);
      expect(p.streak.count, 3);
      expect(p.streak.lastDay, GameDay.fromInstant(onDay(2)));
      expect(p.freezeTokens, 0);
    });

    test('a gap breaks the run; the count is the run ending at the last day', () {
      final s = projectGameState([
        granted('d0', when: onDay(0), reasonCode: GameReasonCodes.dailyLog),
        granted('d1', when: onDay(1), reasonCode: GameReasonCodes.dailyLog),
        granted('d4', when: onDay(4), reasonCode: GameReasonCodes.dailyLog),
      ]);
      expect(s.person(robin).streak.count, 1);
    });

    test('a freeze with no tokens still covers the day but clamps and warns', () {
      final s = projectGameState([
        granted('d0', when: onDay(0), reasonCode: GameReasonCodes.dailyLog),
        freezeUsed('f1', GameDay.fromInstant(onDay(1)), when: onDay(2)),
      ]);
      expect(s.person(robin).streak.count, 2);
      expect(s.person(robin).freezeTokens, 0);
      expect(codes(s), [GameWarningCode.tokensClamped]);
    });
  });

  group('ritual', () {
    test('steps accumulate per month; the boss fight records and pays once', () {
      const sept = Month(2026, 9);
      final s = projectGameState([
        ritualStep('r1', sept, RitualStep.reconcile, when: at(0)),
        ritualStep('r2', sept, RitualStep.plan, when: at(1)),
        ritualStep('r3', sept, RitualStep.plan, when: at(2)),
        bossFight('b1', sept,
            when: at(3), rewards: Loot(gems: 6, materials: mats({MaterialKind.trophy: 1}))),
        bossFight('b2', sept, when: at(4), rewards: const Loot(gems: 6)),
      ]);
      final progress = s.person(robin).ritual[sept]!;
      expect(progress.steps, {RitualStep.reconcile, RitualStep.plan});
      expect(progress.boss!.won, isTrue);
      expect(progress.boss!.bossKey, 'boss.autumn.wyrm');
      expect(s.person(robin).gems, 6);
      expect(s.hall.materials[MaterialKind.trophy], 1);
      expect(codes(s), [GameWarningCode.duplicateBossFight]);
    });
  });

  group('party', () {
    test('join sets the party; leaving clears it', () {
      final joined = projectGameState([partyJoined('p1', 'party-1', when: at(0))]);
      expect(joined.person(robin).partyId, 'party-1');
      final left = projectGameState([
        partyJoined('p1', 'party-1', when: at(0)),
        partyLeft('p2', 'party-1', when: at(1)),
      ]);
      expect(left.person(robin).partyId, isNull);
    });

    test('leaving a party you are not in warns and changes nothing', () {
      final s = projectGameState([
        partyJoined('p1', 'party-1', when: at(0)),
        partyLeft('p2', 'party-2', when: at(1)),
      ]);
      expect(s.person(robin).partyId, 'party-1');
      expect(codes(s), [GameWarningCode.notInParty]);
    });
  });

  test('unknown events are carried but change nothing', () {
    final unknown = GameEvent.fromJson({
      'eventId': 'z',
      'deviceId': 'd',
      'actorId': robin,
      'occurredAt': '2026-10-01T19:00:00.000Z',
      'createdAt': '2026-10-01T19:00:00.000Z',
      'schemaVersion': 9,
      'type': 'FutureThing',
      'payload': <String, dynamic>{},
    });
    expect(projectGameState([unknown]), projectGameState(const []));
  });

  group('determinism', () {
    test('rebuilding from scratch equals incremental application', () {
      final events = richHistory();
      final rebuilt = projectGameState(events);

      final sorted = [...events]..sort(compareGameEvents);
      var incremental = GameState.initial();
      for (final e in sorted) {
        incremental = incremental.apply(e);
      }
      expect(incremental, rebuilt);
      expect(rebuilt.warnings, isNotEmpty, reason: 'the history exercises clamps');

      // Every prefix agrees too, not just the end state.
      var step = GameState.initial();
      for (var i = 0; i < sorted.length; i++) {
        step = step.apply(sorted[i]);
        expect(step, projectGameState(sorted.sublist(0, i + 1)), reason: 'prefix $i');
      }
    });

    test('shuffling the input gives the same state', () {
      final events = richHistory();
      final expected = projectGameState(events);
      for (var seed = 0; seed < 25; seed++) {
        final shuffled = [...events]..shuffle(Random(seed));
        expect(projectGameState(shuffled), expected, reason: 'seed $seed');
      }
    });

    test('duplicate events in the input are applied once', () {
      final events = richHistory();
      expect(projectGameState([...events, ...events.reversed]),
          projectGameState(events));
    });

    test('incremental apply is idempotent for the last event and rejects '
        'events older than the cursor', () {
      final a = partyJoined('a', 'party-1', when: at(0));
      final b = partyJoined('b', 'party-1', when: at(1), actor: sam);
      final s = GameState.initial().apply(a).apply(b);
      expect(s.apply(b), s);
      expect(() => s.apply(a), throwsStateError);
    });

    test('ties on occurredAt break by eventId', () {
      final first = customized('a', 'hair', 'red', when: at(0));
      final second = customized('b', 'hair', 'blue', when: at(0));
      expect(projectGameState([second, first]).person(robin).hero.cosmetics['hair'],
          'blue');
    });
  });
}
