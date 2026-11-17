import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/rewards/castle_title.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';
import 'package:lootlog/game/domain/town/castle.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/prosperity.dart';

import '../game_fixtures.dart';
import 'growth_fixtures.dart';

final MaterialBundle _plenty = MaterialBundle({
  for (final kind in MaterialKind.values) kind: 3000,
});

final GoodsBundle _crates = GoodsBundle({for (final kind in GoodsKind.values) kind: 5000});

/// A city with a full purse, full stores and a pile of goods.
List<GameEvent> _city({TownTier tier = TownTier.city}) => [
      ...tierWith(tier, gems: 5000, materials: _plenty),
      districtPurchased('market', kMarketRowDistrictId, when: at(0)),
      civicBuilt('workshop', kMarketRowDistrictId, 0, CivicBuildingType.workshop, when: at(0)),
      refiningStarted('crates', 0, 'planks', when: at(1), completesAt: at(1), output: _crates),
      goodsCollected('got-crates', 0, 'crates', _crates, when: at(2)),
    ];

Duration _days(int stage) => Duration(days: Balance.castleStages[stage - 1].buildDays);

/// All five stages, each begun the moment the last one finished, from
/// [start]; and the instant the last one finishes.
({List<CastleStageStarted> stages, DateTime done}) _wholeCastle(DateTime start) {
  final stages = <CastleStageStarted>[];
  var at = start;
  for (var stage = 1; stage <= 5; stage++) {
    stages.add(castleStageStarted('stage-$stage', stage, when: at));
    at = at.add(_days(stage));
  }
  return (stages: stages, done: at);
}

void main() {
  var ids = 0;
  GameCommands commandsFor(GameState state, DateTime now) => GameCommands(
        state: state,
        clock: FixedClock(now),
        actorId: robin,
        stamp: GameEventStamp(deviceId: 'dev-1', newEventId: () => 'cmd-${(ids++).toString().padLeft(4, '0')}'),
      );

  group('the stages', () {
    test('five, from the foundation to the banners, each a long build', () {
      expect(Balance.castleStages.map((stage) => stage.key),
          ['foundation', 'keep', 'walls', 'towers', 'banners']);
      for (final stage in Balance.castleStages) {
        expect(stage.buildDays, greaterThanOrEqualTo(1), reason: stage.key);
        expect(stage.goods.isEmpty, isFalse, reason: stage.key);
        expect(stage.cost.materials.isEmpty, isFalse, reason: stage.key);
        expect(stage.prosperity, greaterThan(0), reason: stage.key);
      }
    });
  });

  group('startCastleStage', () {
    test('waits for the city', () {
      final town = projectGameState(_city(tier: TownTier.town));
      expect(commandsFor(town, at(10)).startCastleStage().rejection, GameRejection.townTierTooLow);
    });

    test('a city lays the foundation, with its cost, goods and build time stored', () {
      final state = projectGameState(_city());
      final result = commandsFor(state, at(10)).startCastleStage();
      expect(result.accepted, isTrue, reason: '$result');
      final started = result.events.single as CastleStageStarted;
      final spec = Balance.castleStages.first;
      expect(started.stage, 1);
      expect(started.stageKey, 'foundation');
      expect(started.cost, spec.cost);
      expect(started.goods, spec.goods);
      expect(started.completesAt, at(10).add(_days(1)));
      final after = state.apply(started);
      final castle = after.townOf(robin).castle;
      expect(castle.stagesStarted, 1);
      expect(castle.stagesCompleteAt(at(11)), 0);
      expect(castle.stagesCompleteAt(started.completesAt), 1);
      expect(after.townOf(robin).goods.stored, _crates.less(spec.goods));
      expect(after.person(robin).gems, 5000 - spec.cost.gems);
    });

    test('one stage at a time, in order, until the banners fly', () {
      var state = projectGameState(_city());
      var now = at(10);
      for (var stage = 1; stage <= Balance.castleStages.length; stage++) {
        // Refill the stores to the Storehouse's brim for each stage.
        final refill = 'refill-$stage';
        state = state
            .apply(granted(refill, when: now.subtract(const Duration(minutes: 2)), rewardId: refill, materials: _plenty))
            .apply(claimed('$refill-claim', refill, when: now.subtract(const Duration(minutes: 1))));
        final started = commandsFor(state, now).startCastleStage().events.single as CastleStageStarted;
        expect(started.stage, stage);
        state = state.apply(started);
        expect(commandsFor(state, now.add(const Duration(hours: 1))).startCastleStage().rejection,
            GameRejection.castleUnderConstruction);
        now = started.completesAt;
      }
      expect(commandsFor(state, now).startCastleStage().rejection, GameRejection.castleComplete);
      expect(state.townOf(robin).castle.isCompleteAt(now), isTrue);
    });

    test('is refused when the goods are short', () {
      final state = projectGameState(tierWith(TownTier.city, gems: 5000, materials: _plenty));
      expect(commandsFor(state, at(10)).startCastleStage().rejection, GameRejection.notEnoughGoods);
    });
  });

  group('the projection', () {
    test('a stage out of order, or started before the last one finished, is ignored and not charged', () {
      final state = projectGameState([
        ..._city(),
        castleStageStarted('skip', 2, when: at(10), cost: const Loot(gems: 10)),
        castleStageStarted('one', 1, when: at(11), cost: const Loot(gems: 10)),
        castleStageStarted('early', 2, when: at(50), cost: const Loot(gems: 10)),
      ]);
      expect(state.townOf(robin).castle.stagesStarted, 1);
      expect(state.person(robin).gems, 4990);
      expect(state.warnings.map((w) => w.code),
          [GameWarningCode.castleOutOfOrder, GameWarningCode.castleOutOfOrder]);
    });

    test('two devices starting the same stage: the earlier stands, once, in any order', () {
      final events = [
        ..._city(),
        castleStageStarted('on-a', 1, when: at(10), cost: const Loot(gems: 10), device: 'a'),
        castleStageStarted('on-b', 1, when: at(12), cost: const Loot(gems: 10), device: 'b'),
      ];
      final state = projectGameState(events);
      expect(projectGameState(events.reversed), state);
      expect(state.townOf(robin).castle.stages.single.completesAt, at(10).add(_days(1)));
      expect(state.person(robin).gems, 4990);
      expect(state.warnings.single.code, GameWarningCode.duplicateCastleStage);
    });

    test('a stage the goods cannot pay for is not applied', () {
      final state = projectGameState([
        ...tierWith(TownTier.city, gems: 5000),
        castleStageStarted('one', 1, when: at(10), goods: GoodsBundle({GoodsKind.planks: 1})),
      ]);
      expect(state.townOf(robin).castle.stagesStarted, 0);
      expect(state.warnings.single.code, GameWarningCode.goodsShort);
    });

    test('a stage key this build does not know is set aside', () {
      final state = projectGameState([
        ..._city(),
        castleStageStarted('moat', 1, stageKey: 'moat', when: at(10)),
      ]);
      expect(state.townOf(robin).castle.stagesStarted, 0);
      expect(state.warnings.single.code, GameWarningCode.castleOutOfOrder);
    });

    test('a stage begun before the town was a city is ignored and not charged', () {
      final state = projectGameState([
        ..._city(tier: TownTier.town),
        castleStageStarted('one', 1, when: at(10), cost: const Loot(gems: 10)),
      ]);
      expect(state.townOf(robin).castle.stagesStarted, 0);
      expect(state.person(robin).gems, 5000);
      expect(state.warnings.single.code, GameWarningCode.castleStageInvalid);
    });

    test('a stage that would finish before its build days are up is ignored and not charged', () {
      final state = projectGameState([
        ..._city(),
        castleStageStarted('rushed', 1,
            when: at(10), completesAt: at(10).add(_days(1)).subtract(const Duration(minutes: 1)),
            cost: const Loot(gems: 10)),
      ]);
      expect(state.townOf(robin).castle.stagesStarted, 0);
      expect(state.person(robin).gems, 5000);
      expect(state.warnings.single.code, GameWarningCode.castleStageInvalid);
    });
  });

  group('prosperity and rewards', () {
    test('each finished stage adds its prosperity', () {
      final state = projectGameState([
        ..._city(),
        castleStageStarted('one', 1, when: at(10)),
      ]);
      final done = at(10).add(_days(1));
      final before = prosperityOf(state, robin, done.subtract(const Duration(minutes: 1)));
      expect(prosperityOf(state, robin, done) - before, Balance.castleStages.first.prosperity);
      expect(castleProsperityAt(state.townOf(robin).castle, done), Balance.castleStages.first.prosperity);
    });

    test('the engine rewards each finished stage once, and the banners bring a trophy', () {
      final castle = _wholeCastle(at(10));
      final log = <GameEvent>[..._city(), ...castle.stages];
      const party = Party([PartyAdult(robin, inAdventure: true)]);
      List<GameEvent> run() {
        final out = const RewardEngine(monthEnd: NoMonthEndRewards()).evaluate(
          const [],
          projectGameState(log),
          FixedClock(castle.done),
          party: party,
          stamp: GameEventStamp(deviceId: 'e', newEventId: () => 'e-${(ids++).toString().padLeft(4, '0')}'),
        );
        log.addAll(out);
        return out;
      }

      final rewards = run().whereType<RewardGranted>().where((r) => r.kind == 'castleStage').toList();
      expect(rewards.map((r) => r.rewardId),
          [for (final stage in Balance.castleStages) castleStageRewardId(robin, stage.key)]);
      expect(rewards.last.materials[MaterialKind.trophy], 1);
      expect(run().whereType<RewardGranted>().where((r) => r.kind == 'castleStage'), isEmpty);
    });

    test('a finished castle brings its title once, when the catalogue has it', () {
      final catalog = DecorCatalog.fromJson({
        'items': [
          {'id': kCastleTitleItemId, 'name': 'Castle keeper', 'kind': 'title', 'rarity': 'rare',
           'asset': 'title.castle.default.idle', 'exclusive': true},
        ],
      });
      const party = Party([PartyAdult(robin, inAdventure: true)]);
      final castle = _wholeCastle(at(10));
      GameEventStamp stamp() => GameEventStamp(deviceId: 't', newEventId: () => 't-${ids++}');
      final finished = projectGameState([..._city(), ...castle.stages]);
      final almost = castle.done.subtract(const Duration(minutes: 1));
      expect(const CastleTitle().evaluate(finished, party, catalog, FixedClock(almost), stamp()), isEmpty);
      final grants = const CastleTitle().evaluate(finished, party, catalog, FixedClock(castle.done), stamp());
      final title = grants.single as ItemAcquired;
      expect(title.itemId, kCastleTitleItemId);
      expect(
          const CastleTitle().evaluate(
              finished.apply(title), party, catalog, FixedClock(castle.done.add(const Duration(minutes: 1))), stamp()),
          isEmpty);
    });
  });
}
