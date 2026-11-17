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

import '../game_fixtures.dart';
import 'growth_fixtures.dart';

final MaterialBundle _plenty = MaterialBundle({
  for (final kind in MaterialKind.values) kind: 2500,
});

int _minutes(String recipeId) => Balance.refiningRecipes[recipeId]!.minutesPerBatch;

void main() {
  var ids = 0;
  GameCommands commandsFor(GameState state, DateTime now, {String device = 'dev-1'}) => GameCommands(
        state: state,
        clock: FixedClock(now),
        actorId: robin,
        stamp: GameEventStamp(deviceId: device, newEventId: () => '$device-cmd-${(ids++).toString().padLeft(4, '0')}'),
      );

  /// A town with Market Row and [workshops] tier-1 workshops (plots 0..),
  /// all finished at [kBase].
  List<GameEvent> market({int workshops = 1, MaterialBundle? materials}) => [
        ...tierWith(TownTier.town, gems: 2000, materials: materials ?? _plenty),
        districtPurchased('market', kMarketRowDistrictId, when: at(0)),
        for (var plot = 0; plot < workshops; plot++)
          civicBuilt('workshop-$plot', kMarketRowDistrictId, plot, CivicBuildingType.workshop, when: at(0)),
      ];

  RefiningStarted start(GameState state, DateTime now, String recipe, int batches, {String device = 'dev-1'}) {
    final result = commandsFor(state, now, device: device).startRefining(recipe, batches);
    expect(result.accepted, isTrue, reason: '$result');
    return result.events.single as RefiningStarted;
  }

  group('recipes', () {
    test('planks, cut stone, tools and cloth', () {
      expect({for (final recipe in Balance.refiningRecipes.values) recipe.output}, GoodsKind.values.toSet());
      for (final recipe in Balance.refiningRecipes.values) {
        expect(recipe.input.isEmpty, isFalse);
        expect(recipe.outputPerBatch, greaterThan(0));
        expect(recipe.minutesPerBatch, greaterThan(0));
      }
    });
  });

  group('startRefining', () {
    test('stores the batches, what goes in, what comes out and when it is done', () {
      final state = projectGameState(market());
      final started = start(state, at(10), 'planks', 3);
      final recipe = Balance.refiningRecipes['planks']!;
      expect(started.districtId, kMarketRowDistrictId);
      expect(started.plotIndex, 0);
      expect(started.batches, 3);
      expect(started.input, recipe.input.scaled(3));
      expect(started.output, GoodsBundle({GoodsKind.planks: recipe.outputPerBatch * 3}));
      expect(started.completesAt, at(10 + 3 * _minutes('planks')));

      final after = state.apply(started);
      final town = after.townOf(robin);
      expect(town.materials[MaterialKind.lumber], 2500 - recipe.input[MaterialKind.lumber] * 3);
      expect(town.goods.stored.isEmpty, isTrue);
      expect(town.goods.jobs[const PlotAddress(kMarketRowDistrictId, 0)]!.jobId, started.eventId);
    });

    test('refuses without a workshop, an unknown recipe, or a batch count the workshop cannot take', () {
      final noMarket = projectGameState(tierWith(TownTier.town, materials: _plenty));
      expect(commandsFor(noMarket, at(10)).startRefining('planks', 1).rejection, GameRejection.noWorkshop);
      final state = projectGameState(market());
      final commands = commandsFor(state, at(10));
      expect(commands.startRefining('gold', 1).rejection, GameRejection.unknownRecipe);
      expect(commands.startRefining('planks', 0).rejection, GameRejection.invalidBatches);
      expect(commands.startRefining('planks', Balance.workshopMaxBatchesByTier[1] + 1).rejection,
          GameRejection.invalidBatches);
      expect(commands.startRefining('planks', Balance.workshopMaxBatchesByTier[1]).accepted, isTrue);
    });

    test('refuses when the stores are short', () {
      final poor = projectGameState(market(materials: MaterialBundle({MaterialKind.lumber: 5})));
      expect(commandsFor(poor, at(10)).startRefining('planks', 1).rejection, GameRejection.notEnoughMaterials);
    });

    test('a busy workshop takes no second job; a second workshop does', () {
      final one = projectGameState(market());
      final busy = one.apply(start(one, at(10), 'planks', 1));
      expect(commandsFor(busy, at(11)).startRefining('cutStone', 1).rejection, GameRejection.workshopBusy);
      final two = projectGameState(market(workshops: 2));
      final first = two.apply(start(two, at(10), 'planks', 1));
      expect(start(first, at(11), 'cutStone', 1).plotIndex, 1);
    });
  });

  group('collecting', () {
    test('nothing until the job is done, then exactly what the job stored, once', () {
      final state = projectGameState(market());
      final started = start(state, at(10), 'tools', 2);
      final working = state.apply(started);
      expect(commandsFor(working, at(11)).collectGoods().rejection, GameRejection.nothingToCollect);

      final done = started.completesAt;
      final result = commandsFor(working, done).collectGoods();
      final collected = result.events.single as GoodsCollected;
      expect(collected.jobId, started.eventId);
      expect(collected.goods, started.output);
      final after = working.apply(collected);
      expect(after.townOf(robin).goods.stored, started.output);
      expect(after.townOf(robin).goods.jobs, isEmpty);
      expect(commandsFor(after, done).collectGoods().rejection, GameRejection.nothingToCollect);
    });

    test('the stored output is credited, never recomputed from today\'s recipe', () {
      final state = projectGameState([
        ...market(),
        refiningStarted('job', 0, 'planks',
            when: at(10), completesAt: at(20), output: GoodsBundle({GoodsKind.planks: 7})),
        goodsCollected('c', 0, 'job', GoodsBundle({GoodsKind.planks: 99}), when: at(30)),
      ]);
      expect(state.townOf(robin).goods.stored, GoodsBundle({GoodsKind.planks: 7}));
    });

    test('two devices collecting the same job credit it once, in any order', () {
      final events = [
        ...market(),
        refiningStarted('job', 0, 'planks',
            when: at(10), completesAt: at(20), output: GoodsBundle({GoodsKind.planks: 6})),
        goodsCollected('c-a', 0, 'job', GoodsBundle({GoodsKind.planks: 6}), when: at(30), device: 'a'),
        goodsCollected('c-b', 0, 'job', GoodsBundle({GoodsKind.planks: 6}), when: at(31), device: 'b'),
      ];
      final forward = projectGameState(events);
      final backward = projectGameState(events.reversed);
      expect(forward.townOf(robin).goods.stored, GoodsBundle({GoodsKind.planks: 6}));
      expect(backward, forward);
      expect(forward.warnings.single.code, GameWarningCode.unknownJob);
    });

    test('a collect before the job is done credits nothing', () {
      final state = projectGameState([
        ...market(),
        refiningStarted('job', 0, 'planks',
            when: at(10), completesAt: at(20), output: GoodsBundle({GoodsKind.planks: 6})),
        goodsCollected('early', 0, 'job', GoodsBundle({GoodsKind.planks: 6}), when: at(15)),
      ]);
      expect(state.townOf(robin).goods.stored.isEmpty, isTrue);
      expect(state.townOf(robin).goods.jobs, hasLength(1));
    });
  });

  group('two devices starting the same workshop', () {
    test('the earlier start stands; the later is ignored and charges nothing, in any order', () {
      final base = projectGameState(market());
      final onA = start(base, at(10), 'planks', 2, device: 'a');
      final onB = start(base, at(12), 'cutStone', 2, device: 'b');
      final events = [...market(), onA, onB];
      final state = projectGameState(events);
      expect(projectGameState(events.reversed), state);
      final town = state.townOf(robin);
      expect(town.goods.jobs.values.single.jobId, onA.eventId);
      expect(town.materials[MaterialKind.stone], 2500, reason: 'the stone job was never charged');
      expect(state.warnings.single.code, GameWarningCode.workshopBusy);
    });

    test('a start naming a recipe or a workshop this build lacks is set aside', () {
      final state = projectGameState([
        ...market(),
        refiningStarted('x1', 0, 'glass',
            when: at(10), completesAt: at(20), input: MaterialBundle({MaterialKind.stone: 10})),
        refiningStarted('x2', 3, 'planks',
            when: at(11), completesAt: at(20), input: MaterialBundle({MaterialKind.lumber: 10})),
      ]);
      expect(state.townOf(robin).goods.jobs, isEmpty);
      expect(state.townOf(robin).materials, _plenty);
      expect(state.warnings.map((w) => w.code), [GameWarningCode.unknownRecipe, GameWarningCode.unknownBuilding]);
    });

    test('a start the stores cannot pay is not applied, even before the split', () {
      final state = projectGameState([
        ...market(materials: MaterialBundle({MaterialKind.lumber: 5})),
        refiningStarted('x', 0, 'planks',
            when: at(10), completesAt: at(20), input: MaterialBundle({MaterialKind.lumber: 10})),
      ]);
      expect(state.townOf(robin).goods.jobs, isEmpty);
      expect(state.townOf(robin).materials[MaterialKind.lumber], 5);
    });
  });

  group('goods pay for the top civic tiers', () {
    GameState cottageAt(int tier, {GoodsBundle goods = const GoodsBundle.empty()}) => projectGameState([
          ...market(),
          districtPurchased('homes', kResidentialDistrictId, when: at(0)),
          for (var level = 1; level <= tier; level++)
            civicBuilt('c$level', kResidentialDistrictId, 0, CivicBuildingType.cottage, when: at(level), tier: level),
          if (!goods.isEmpty) ...[
            refiningStarted('job', 0, 'planks', when: at(10), completesAt: at(11), output: goods),
            goodsCollected('got', 0, 'job', goods, when: at(12)),
          ],
        ]);

    test('a tier from the goods tier on wants goods, and the event carries them', () {
      final wants = Balance.civicBuildingCost(CivicBuildingType.cottage, Balance.civicGoodsFromTier).goods;
      expect(wants.isEmpty, isFalse);
      expect(Balance.civicBuildingCost(CivicBuildingType.cottage, Balance.civicGoodsFromTier - 1).goods.isEmpty,
          isTrue);
      final short = cottageAt(Balance.civicGoodsFromTier - 1);
      expect(commandsFor(short, at(20)).startCivicBuilding(kResidentialDistrictId, 0, CivicBuildingType.cottage).rejection,
          GameRejection.notEnoughGoods);
      final ready = cottageAt(Balance.civicGoodsFromTier - 1, goods: wants);
      final result = commandsFor(ready, at(20)).startCivicBuilding(kResidentialDistrictId, 0, CivicBuildingType.cottage);
      final started = result.events.single as CivicBuildingStarted;
      expect(started.goods, wants);
      expect(ready.apply(started).townOf(robin).goods.stored.isEmpty, isTrue);
    });

    test('a civic event the goods cannot pay for is not applied', () {
      final state = cottageAt(2).apply(civicBuilt('c3', kResidentialDistrictId, 0, CivicBuildingType.cottage,
          when: at(30), tier: 3, goods: GoodsBundle({GoodsKind.planks: 10})));
      expect(state.townOf(robin).districts.buildingAt(const PlotAddress(kResidentialDistrictId, 0))!.tier, 2);
      expect(state.warnings.last.code, GameWarningCode.goodsShort);
    });
  });
}
