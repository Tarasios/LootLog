import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/content.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/reason_codes.dart';

import '../game_fixtures.dart';

MaterialBundle mats(Map<MaterialKind, int> m) => MaterialBundle(m);

/// A hall under test: a game log, a clock the test moves, and commands run
/// the way the app runs them (validate against the projection, then append).
class _Hall {
  _Hall([List<GameEvent> seed = const []]) : log = [...seed];

  final List<GameEvent> log;
  DateTime now = at(0);
  int _ids = 0;

  GameState get state => projectGameState(log);
  PersonState person([String who = robin]) => state.person(who);

  GameCommands commands({String actor = robin}) => GameCommands(
        state: state,
        clock: FixedClock(now),
        actorId: actor,
        stamp: GameEventStamp(
          deviceId: 'dev-test',
          newEventId: () => 'z${(_ids++).toString().padLeft(5, '0')}',
        ),
      );

  GameCommandResult run(GameCommandResult Function(GameCommands c) command,
      {String actor = robin}) {
    final r = command(commands(actor: actor));
    if (r.accepted) log.addAll(r.events);
    return r;
  }

  void advance(Duration d) => now = now.add(d);

  /// Gives [who] [gems] in their wallet (a granted and claimed reward).
  void fund(int gems, {String who = robin}) {
    final id = 'fund-${_ids++}';
    log
      ..add(granted('$id-a', when: now, actor: who, gems: gems, rewardId: id))
      ..add(claimed('$id-b', id, when: now, actor: who));
  }

  /// Drops [m] into the shared pool.
  void stock(MaterialBundle m) {
    final id = 'stock-${_ids++}';
    log
      ..add(granted('$id-a', when: now, materials: m, rewardId: id))
      ..add(claimed('$id-b', id, when: now));
  }
}

void expectRejected(GameCommandResult r, GameRejection reason) {
  expect(r.accepted, isFalse, reason: 'expected $reason');
  expect(r.rejection, reason);
  expect(r.events, isEmpty);
}

void main() {
  group('unlockPlot', () {
    test('charges the gem price and opens the plot', () {
      final h = _Hall()..fund(100);
      final r = h.run((c) => c.unlockPlot(3));
      expect(r.accepted, isTrue);
      final e = r.events.single as PlotUnlocked;
      expect(e.gemCost, Balance.plotUnlockCost(3));
      expect(e.actorId, robin);
      expect(e.occurredAt, h.now);
      expect(h.state.hall.plots, contains(3));
      expect(h.person().gems, 100 - Balance.plotUnlockCost(3)!);
      expect(h.state.warnings, isEmpty);
    });

    test('rejects an unlocked plot, a plot past the end, and short wallets', () {
      final h = _Hall()..fund(5);
      expectRejected(h.run((c) => c.unlockPlot(0)),
          GameRejection.plotAlreadyUnlocked);
      expectRejected(
          h.run((c) => c.unlockPlot(Balance.maxPlots)), GameRejection.invalidPlot);
      expectRejected(h.run((c) => c.unlockPlot(-1)), GameRejection.invalidPlot);
      expectRejected(h.run((c) => c.unlockPlot(3)), GameRejection.notEnoughGems);
    });
  });

  group('startBuilding', () {
    test('a free tier-1 building is instant and costs nothing', () {
      final h = _Hall();
      final r = h.run((c) => c.startBuilding(0, BuildingType.lumberyard));
      final e = r.events.single as BuildingStarted;
      expect(e.tier, 1);
      expect(e.cost, Loot.none);
      expect(e.completesAt, h.now);
      expect(h.state.hall.plots[0]!.building!.type, BuildingType.lumberyard);
    });

    test('pays materials from the pool; rejects when the pool is short', () {
      final h = _Hall();
      expectRejected(h.run((c) => c.startBuilding(0, BuildingType.mine)),
          GameRejection.notEnoughMaterials);
      h.stock(Balance.buildingCost(BuildingType.mine, 1).materials);
      expect(h.run((c) => c.startBuilding(0, BuildingType.mine)).accepted,
          isTrue);
      expect(h.state.hall.materials.isEmpty, isTrue);
    });

    test('rejects a locked plot, an occupied plot and a second of a kind', () {
      final h = _Hall();
      h.run((c) => c.startBuilding(0, BuildingType.lumberyard));
      expectRejected(h.run((c) => c.startBuilding(5, BuildingType.quarry)),
          GameRejection.plotLocked);
      expectRejected(h.run((c) => c.startBuilding(0, BuildingType.quarry)),
          GameRejection.plotOccupied);
      expectRejected(h.run((c) => c.startBuilding(1, BuildingType.lumberyard)),
          GameRejection.buildingAlreadyInHall);
    });

    test('upgrades wait for the Central Hall, then take the build timer', () {
      final h = _Hall();
      h.run((c) => c.startBuilding(0, BuildingType.quarry));
      h.stock(Balance.buildingCost(BuildingType.quarry, 2).materials);
      expectRejected(h.run((c) => c.startBuilding(0, BuildingType.quarry)),
          GameRejection.needsCentralHall);

      h.run((c) => c.startBuilding(1, BuildingType.centralHall));
      h.stock(Balance.buildingCost(BuildingType.centralHall, 2).materials);
      final hall2 = h.run((c) => c.startBuilding(1, BuildingType.centralHall));
      expect((hall2.events.last as BuildingStarted).completesAt,
          h.now.add(Balance.buildTimeByTier[1]));
      // Still under construction: the gate holds tier 1.
      expectRejected(h.run((c) => c.startBuilding(0, BuildingType.quarry)),
          GameRejection.needsCentralHall);
      expectRejected(h.run((c) => c.startBuilding(1, BuildingType.centralHall)),
          GameRejection.underConstruction);

      h.advance(const Duration(hours: 1));
      final up = h.run((c) => c.startBuilding(0, BuildingType.quarry));
      expect(up.accepted, isTrue);
      final started = up.events.whereType<BuildingStarted>().single;
      expect(started.tier, 2);
      expect(started.cost, Balance.buildingCost(BuildingType.quarry, 2));
    });

    test('a producer upgrade banks its production first', () {
      final h = _Hall();
      h.run((c) => c.startBuilding(0, BuildingType.centralHall));
      h.stock(Balance.buildingCost(BuildingType.centralHall, 2).materials);
      h.run((c) => c.startBuilding(0, BuildingType.centralHall));
      h.run((c) => c.startBuilding(1, BuildingType.lumberyard));
      h.advance(const Duration(hours: 2));
      h.stock(Balance.buildingCost(BuildingType.lumberyard, 2).materials);
      final before = h.state.hall.materials[MaterialKind.lumber];
      final r = h.run((c) => c.startBuilding(1, BuildingType.lumberyard));
      final bank = r.events.first as MaterialsCollected;
      final rate = Balance.buildings[BuildingType.lumberyard]!
          .productionPerHour[MaterialKind.lumber]![0];
      expect(bank.amounts[MaterialKind.lumber], 2 * rate);
      expect(r.events.last, isA<BuildingStarted>());
      final cost = Balance.buildingCost(BuildingType.lumberyard, 2);
      expect(h.state.hall.materials[MaterialKind.lumber],
          before + 2 * rate - cost.materials[MaterialKind.lumber]);
      expect(h.state.hall.lastCollectedAt['plot-1'], h.now);
    });

    test('higher tiers also cost gems, paid by whoever builds', () {
      final h = _Hall();
      final log = [
        for (final t in [1, 2])
          built('ch$t', 0, BuildingType.centralHall, when: at(-100), tier: t),
        built('ch3', 0, BuildingType.centralHall, when: at(-100), tier: 3),
        built('q1', 1, BuildingType.quarry, when: at(-100), tier: 2),
      ];
      h.log.addAll(log);
      h.stock(Balance.buildingCost(BuildingType.quarry, 3).materials);
      expectRejected(h.run((c) => c.startBuilding(1, BuildingType.quarry),
          actor: sam), GameRejection.notEnoughGems);
      h.fund(100, who: sam);
      expect(h.run((c) => c.startBuilding(1, BuildingType.quarry), actor: sam)
          .accepted, isTrue);
      expect(h.person(sam).gems,
          100 - Balance.buildingCost(BuildingType.quarry, 3).gems);
    });

    test('stops at the max tier', () {
      final h = _Hall()
        ..log.addAll([
          built('ch', 0, BuildingType.centralHall,
              when: at(-100), tier: Balance.maxBuildingTier),
        ]);
      expectRejected(h.run((c) => c.startBuilding(0, BuildingType.centralHall)),
          GameRejection.maxTierReached);
    });
  });

  group('collectMaterials', () {
    test('banks production since the build, then since the last collection',
        () {
      final h = _Hall();
      h.run((c) => c.startBuilding(0, BuildingType.quarry));
      expectRejected(
          h.run((c) => c.collectMaterials(0)), GameRejection.nothingToCollect);
      final rate = Balance.buildings[BuildingType.quarry]!
          .productionPerHour[MaterialKind.stone]![0];
      h.advance(const Duration(minutes: 90));
      final r = h.run((c) => c.collectMaterials(0));
      final e = r.events.single as MaterialsCollected;
      expect(e.buildingId, 'plot-0');
      expect(e.amounts[MaterialKind.stone], rate * 90 ~/ 60);
      h.advance(const Duration(hours: 1));
      h.run((c) => c.collectMaterials(0));
      expect(h.state.hall.materials[MaterialKind.stone],
          rate * 90 ~/ 60 + rate);
    });

    test('never asks whether anyone logged today (rule 10)', () {
      // No ledger input exists for collecting at all: the command takes only
      // the hall and the clock.
      final h = _Hall();
      h.run((c) => c.startBuilding(0, BuildingType.lumberyard));
      h.advance(const Duration(days: 3));
      expect(h.run((c) => c.collectMaterials(0)).accepted, isTrue);
    });

    test('is capped by the room left in the storehouse', () {
      final h = _Hall();
      h.run((c) => c.startBuilding(0, BuildingType.lumberyard));
      final cap = Balance.storehouseCapacityByTier[0];
      h.stock(mats({MaterialKind.lumber: cap - 7}));
      h.advance(const Duration(days: 2));
      final e = h.run((c) => c.collectMaterials(0)).events.single
          as MaterialsCollected;
      expect(e.amounts[MaterialKind.lumber], 7);
      expect(h.state.hall.materials[MaterialKind.lumber], cap);
      expect(h.state.warnings, isEmpty);
      h.advance(const Duration(hours: 5));
      expectRejected(
          h.run((c) => c.collectMaterials(0)), GameRejection.storehouseFull);
    });

    test('produces at the old tier until an upgrade completes', () {
      final h = _Hall()
        ..log.addAll([
          built('ch', 2, BuildingType.centralHall, when: at(-200), tier: 2),
          built('m1', 0, BuildingType.mine, when: at(-200), tier: 1),
          collected('c0', 'plot-0', const MaterialBundle.empty(), when: at(0)),
          built('m2', 0, BuildingType.mine,
              when: at(0), tier: 2, completesAt: at(60)),
        ]);
      final rates = Balance.buildings[BuildingType.mine]!
          .productionPerHour[MaterialKind.ore]!;
      h.now = at(120);
      final e = h.run((c) => c.collectMaterials(0)).events.single
          as MaterialsCollected;
      expect(e.amounts[MaterialKind.ore], rates[0] + rates[1]);
    });

    test('rejects empty plots and buildings that produce nothing', () {
      final h = _Hall();
      expectRejected(h.run((c) => c.collectMaterials(0)), GameRejection.noBuilding);
      expectRejected(h.run((c) => c.collectMaterials(9)), GameRejection.plotLocked);
      h.run((c) => c.startBuilding(0, BuildingType.centralHall));
      expectRejected(
          h.run((c) => c.collectMaterials(0)), GameRejection.notAProducer);
    });
  });

  group('chests', () {
    _Hall withChest(ChestType type, {String chestId = 'chest-1'}) => _Hall()
      ..log.add(chestGranted('g1', chestId, type, when: at(-5)));

    test('opening rolls gems in range, seeded by the new event id', () {
      final h = withChest(ChestType.wood);
      final r = h.run((c) => c.openChest('chest-1'));
      final e = r.events.single as ChestOpened;
      final spec = Balance.chests[ChestType.wood]!;
      expect(e.contents.gems, inInclusiveRange(spec.minGems, spec.maxGems));
      expect(e.contents.materials.isEmpty, isTrue);
      expect(h.person().unopenedChests, isEmpty);
      expect(h.person().gems, e.contents.gems);

      // Same event id, same roll — on any device.
      final again = withChest(ChestType.wood).run((c) => c.openChest('chest-1'));
      expect((again.events.single as ChestOpened).contents, e.contents);
    });

    test('a token rolled at the token cap becomes gems', () {
      // Open many chests with a full token pouch: never more tokens.
      for (var i = 0; i < 40; i++) {
        final h = _Hall()
          ..log.addAll([
            granted('t', when: at(-9), tokens: Balance.maxFreezeTokens,
                rewardId: 'tok'),
            claimed('tc', 'tok', when: at(-9)),
            chestGranted('g$i', 'c$i', ChestType.spoils, when: at(-5)),
          ]);
        final e = h.run((c) => c.openChest('c$i')).events.single as ChestOpened;
        expect(e.contents.tokens, 0);
      }
    });

    test('spoils chests roll tokens some of the time', () {
      var tokens = 0;
      for (var i = 0; i < 40; i++) {
        final h = withChest(ChestType.spoils, chestId: 'c$i');
        h._ids = i * 7;
        final e = h.run((c) => c.openChest('c$i')).events.single as ChestOpened;
        tokens += e.contents.tokens;
      }
      expect(tokens, greaterThan(0));
    });

    test('rejects a chest that is not waiting, or belongs to someone else', () {
      final h = withChest(ChestType.wood);
      expectRejected(h.run((c) => c.openChest('nope')), GameRejection.unknownChest);
      expectRejected(h.run((c) => c.openChest('chest-1'), actor: sam),
          GameRejection.unknownChest);
      h.run((c) => c.openChest('chest-1'));
      expectRejected(
          h.run((c) => c.openChest('chest-1')), GameRejection.unknownChest);
    });
  });

  group('claimReward', () {
    test('claims a waiting reward once', () {
      final h = _Hall()
        ..log.add(granted('g1', when: at(-1), gems: 7, rewardId: 'r1'));
      final r = h.run((c) => c.claimReward('r1'));
      expect((r.events.single as RewardClaimed).rewardId, 'r1');
      expect(h.person().gems, 7);
      expectRejected(h.run((c) => c.claimReward('r1')), GameRejection.unknownReward);
    });
  });

  group('gear', () {
    _Hall forged(int tier) => _Hall()
      ..log.addAll([
        built('ch', 0, BuildingType.centralHall, when: at(-100), tier: 5),
        built('f', 1, BuildingType.forge, when: at(-100), tier: tier),
      ]);

    test('needs a forge of at least the gear tier', () {
      final h = _Hall()..stock(Balance.gearCost('weapon', 1).materials);
      expectRejected(
          h.run((c) => c.upgradeGear(heroId: robin, slot: 'weapon', gearType: 'sword')),
          GameRejection.needsForge);
    });

    test('upgrades one tier at a time; a partner may pay', () {
      final h = forged(2)
        ..stock(Balance.gearCost('armor', 1).materials +
            Balance.gearCost('armor', 2).materials);
      final r1 = h.run(
          (c) => c.upgradeGear(heroId: robin, slot: 'armor', gearType: 'leather'),
          actor: sam);
      expect((r1.events.single as GearUpgraded).tier, 1);
      final r2 = h.run(
          (c) => c.upgradeGear(heroId: robin, slot: 'armor', gearType: 'mail'));
      expect((r2.events.single as GearUpgraded).tier, 2);
      expect(h.person().hero.gear['armor'], const GearPiece('mail', 2));
      expect(h.person().hero.power, 2);
      expect(h.state.hall.materials.isEmpty, isTrue);
      expectRejected(
          h.run((c) => c.upgradeGear(heroId: robin, slot: 'armor', gearType: 'mail')),
          GameRejection.needsForge);
    });

    test('rejects unknown slots and gear types', () {
      final h = forged(1);
      expectRejected(
          h.run((c) => c.upgradeGear(heroId: robin, slot: 'hat', gearType: 'cap')),
          GameRejection.unknownGearSlot);
      expectRejected(
          h.run((c) => c.upgradeGear(heroId: robin, slot: 'weapon', gearType: 'mail')),
          GameRejection.unknownGearType);
      expectRejected(
          h.run((c) => c.upgradeGear(heroId: robin, slot: 'weapon', gearType: 'sword')),
          GameRejection.notEnoughMaterials);
    });
  });

  group('customizeHero', () {
    test('is free and sets a field on the actor\'s own hero', () {
      final h = _Hall();
      final r = h.run((c) => c.customizeHero(field: 'cloak', value: 'green'));
      final e = r.events.single as HeroCustomized;
      expect(e.heroId, robin);
      expect(h.person().hero.cosmetics['cloak'], 'green');
      expectRejected(h.run((c) => c.customizeHero(field: 'cloak', value: 'green')),
          GameRejection.noChange);
    });

    test('rejects blank or oversized fields', () {
      final h = _Hall();
      expectRejected(h.run((c) => c.customizeHero(field: ' ', value: 'x')),
          GameRejection.invalidCustomization);
      expectRejected(
          h.run((c) => c.customizeHero(
              field: 'cloak', value: 'x' * (Balance.maxCosmeticValueLength + 1))),
          GameRejection.invalidCustomization);
    });
  });

  group('expeditions', () {
    test('one at a time per hero; resolves only once back', () {
      final h = _Hall();
      final start = h.run((c) => c.startExpedition(ExpeditionRegion.marketCatacombs));
      final e = start.events.single as ExpeditionStarted;
      expect(e.heroId, robin);
      expect(e.durationMinutes,
          Balance.regions[ExpeditionRegion.marketCatacombs]!.durationMinutes);
      expectRejected(h.run((c) => c.startExpedition(ExpeditionRegion.tavernCellars)),
          GameRejection.expeditionActive);
      expectRejected(
          h.run((c) => c.resolveExpedition()), GameRejection.expeditionNotFinished);
      // Sam's hero is free to go.
      expect(h.run((c) => c.startExpedition(ExpeditionRegion.tavernCellars),
          actor: sam).accepted, isTrue);

      h.advance(Duration(minutes: e.durationMinutes));
      final back = h.run((c) => c.resolveExpedition());
      final resolved = back.events.single as ExpeditionResolved;
      expect(resolved.region, ExpeditionRegion.marketCatacombs);
      expect(resolved.loot[MaterialKind.herbs], inInclusiveRange(4, 8));
      expect(resolved.reportLines, isNotEmpty);
      expect(h.person().activeExpedition, isNull);
      expect(h.state.hall.materials[MaterialKind.herbs],
          resolved.loot[MaterialKind.herbs]);
      expectRejected(
          h.run((c) => c.resolveExpedition()), GameRejection.noActiveExpedition);
    });

    test('far regions open with the Central Hall', () {
      final h = _Hall();
      expectRejected(h.run((c) => c.startExpedition(ExpeditionRegion.theWilds)),
          GameRejection.regionLocked);
      h.log.add(built('ch', 0, BuildingType.centralHall,
          when: at(-10), tier: Balance.regions[ExpeditionRegion.theWilds]!.minHallTier));
      expect(h.run((c) => c.startExpedition(ExpeditionRegion.theWilds)).accepted,
          isTrue);
    });

    test('gear improves the haul', () {
      int haul(int gearTier) {
        var total = 0;
        for (var i = 0; i < 10; i++) {
          final h = _Hall().._ids = i * 10;
          if (gearTier > 0) {
            h.log.add(gearUpgraded('gw', when: at(-5), tier: gearTier));
          }
          h.run((c) => c.startExpedition(ExpeditionRegion.marketCatacombs));
          h.advance(const Duration(hours: 1));
          final r = h.run((c) => c.resolveExpedition()).events.single
              as ExpeditionResolved;
          total += r.loot[MaterialKind.herbs];
        }
        return total;
      }

      // Same ids, so the same rolls: only the gear differs.
      expect(haul(5), greaterThan(haul(0)));
    });

    test('loot that will not fit is left behind and the report says so', () {
      final h = _Hall()
        ..stock(mats({MaterialKind.herbs: Balance.storehouseCapacityByTier[0]}));
      h.run((c) => c.startExpedition(ExpeditionRegion.marketCatacombs));
      h.advance(const Duration(hours: 1));
      final r = h.run((c) => c.resolveExpedition()).events.single
          as ExpeditionResolved;
      expect(r.loot[MaterialKind.herbs], 0);
      expect(r.reportLines.join(' ').toLowerCase(), contains('storehouse'));
      expect(h.state.warnings, isEmpty);
    });
  });

  group('ritual and boss', () {
    const sept = Month(2026, 9); // kBase is 2026-10-01: September is closed.

    _Hall ritualDone(Month month) {
      final h = _Hall();
      for (final step in RitualStep.values) {
        h.run((c) => c.completeRitualStep(month, step));
      }
      return h;
    }

    test('steps go in order, once each, for a closed month', () {
      final h = _Hall();
      expectRejected(h.run((c) => c.completeRitualStep(sept, RitualStep.review)),
          GameRejection.ritualStepOutOfOrder);
      expect(h.run((c) => c.completeRitualStep(sept, RitualStep.reconcile))
          .accepted, isTrue);
      expectRejected(h.run((c) => c.completeRitualStep(sept, RitualStep.reconcile)),
          GameRejection.ritualStepDone);
      expectRejected(
          h.run((c) => c.completeRitualStep(const Month(2026, 10), RitualStep.reconcile)),
          GameRejection.ritualMonthNotClosed);
      expectRejected(
          h.run((c) => c.completeRitualStep(const Month(2026, 7), RitualStep.reconcile)),
          GameRejection.ritualMonthExpired);
      expect(h.run((c) => c.completeRitualStep(const Month(2026, 8),
          RitualStep.reconcile)).accepted, isTrue);
    });

    test('the boss waits for all four steps and is fought once', () {
      final h = _Hall();
      h.run((c) => c.completeRitualStep(sept, RitualStep.reconcile));
      expectRejected(h.run((c) => c.fightBoss(sept)), GameRejection.ritualIncomplete);
      final done = ritualDone(sept);
      final r = done.run((c) => c.fightBoss(sept, loggedDays: 20));
      expect(r.accepted, isTrue);
      final fight = r.events.whereType<BossFightResolved>().single;
      expect(fight.bossKey, Balance.bosses[Season.autumn]!.key);
      expect(fight.turns, inInclusiveRange(1, Balance.bossMaxTurns));
      expectRejected(done.run((c) => c.fightBoss(sept)),
          GameRejection.bossAlreadyFought);
    });

    test('win or lose, the spoils chest comes; only a win adds a trophy', () {
      var wins = 0;
      var losses = 0;
      for (var i = 0; i < 30; i++) {
        final h = ritualDone(sept).._ids = 100 + i * 13;
        final r = h.run((c) => c.fightBoss(sept, loggedDays: 30));
        final fight = r.events.whereType<BossFightResolved>().single;
        final chest = r.events.whereType<ChestGranted>().single;
        expect(chest.chestType, ChestType.spoils);
        expect(chest.reasonCode, GameReasonCodes.ritualSpoils);
        expect(chest.chestId, 'ritual.spoils:$robin:2026-09');
        if (fight.won) {
          wins++;
          expect(fight.rewards, Balance.bossWinRewards);
        } else {
          losses++;
          expect(fight.rewards, Loot.none);
        }
        expect(h.person().unopenedChests.values, [ChestType.spoils]);
      }
      expect(wins, greaterThan(0));
      expect(losses, greaterThan(0));
    });

    test('a geared hero who logged every day always wins', () {
      final h = ritualDone(sept)
        ..log.addAll([
          gearUpgraded('w', when: at(-1), slot: 'weapon', tier: 5),
          gearUpgraded('a', when: at(-1), slot: 'armor', gearType: 'mail', tier: 5),
          gearUpgraded('t', when: at(-1), slot: 'trinket', gearType: 'ring', tier: 5),
        ]);
      final fight = h.run((c) => c.fightBoss(sept, loggedDays: 30))
          .events.whereType<BossFightResolved>().single;
      expect(fight.won, isTrue);
    });

    test('the fight is the same from the same event id', () {
      BossFightResolved fight() => ritualDone(sept)
          .run((c) => c.fightBoss(sept, loggedDays: 12))
          .events
          .whereType<BossFightResolved>()
          .single;
      final a = fight();
      final b = fight();
      expect(a.won, b.won);
      expect(a.turns, b.turns);
    });
  });

  group('party', () {
    test('join and leave the household party', () {
      final h = _Hall();
      final j = h.run((c) => c.joinParty());
      expect((j.events.single as PartyJoined).partyId, kHouseholdPartyId);
      expectRejected(h.run((c) => c.joinParty()), GameRejection.alreadyInParty);
      final l = h.run((c) => c.leaveParty());
      expect((l.events.single as PartyLeft).partyId, kHouseholdPartyId);
      expectRejected(h.run((c) => c.leaveParty()), GameRejection.notInParty);
      expect(h.person().partyId, isNull);
    });
  });

  test('every accepted command projects without warnings', () {
    final h = _Hall()..fund(500);
    h.stock(mats({
      MaterialKind.lumber: 140,
      MaterialKind.stone: 140,
      MaterialKind.ore: 100,
      MaterialKind.herbs: 100,
      MaterialKind.hide: 100,
    }));
    h.run((c) => c.unlockPlot(3));
    h.run((c) => c.startBuilding(0, BuildingType.centralHall));
    h.run((c) => c.startBuilding(1, BuildingType.lumberyard));
    h.run((c) => c.startBuilding(2, BuildingType.forge));
    h.run((c) => c.startBuilding(3, BuildingType.storehouse));
    h.run((c) => c.upgradeGear(heroId: robin, slot: 'weapon', gearType: 'bow'));
    h.run((c) => c.startExpedition(ExpeditionRegion.tavernCellars));
    h.advance(const Duration(hours: 3));
    h.run((c) => c.collectMaterials(1));
    h.run((c) => c.resolveExpedition());
    h.run((c) => c.joinParty());
    expect(h.state.hall.plots.values.where((p) => p.building != null),
        hasLength(4));
    expect(h.state.warnings, isEmpty);
  });
}
