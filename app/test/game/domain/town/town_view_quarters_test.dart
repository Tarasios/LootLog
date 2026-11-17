/// The town's read model in the stage-3 districts: civic buildings on their
/// plots, a farm resting for want of guards, and the Castle on Castle Hill
/// growing by stage.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';
import 'package:lootlog/game/domain/town/town_view.dart';

import '../game_fixtures.dart';
import 'growth_fixtures.dart';

const _adults = [TownAdult(memberId: robin, name: 'Robin', inAdventure: true)];

void main() {
  test('a civic building shows its type, tier and build timer on its plot', () {
    final game = projectGameState([
      ...tierWith(TownTier.village),
      districtPurchased('guards', kGuardPostDistrictId, when: at(0)),
      civicBuilt('tower', kGuardPostDistrictId, 1, CivicBuildingType.watchtower, when: at(1), completesAt: at(61)),
    ]);
    final view = TownView.from(game, robin, _adults, at(10), districtId: kGuardPostDistrictId);
    expect(view.layout, TownLayout.guardPost);
    expect(view.plots, hasLength(Balance.guardPostPlotCount));
    expect(view.plots.every((plot) => plot.unlocked), isTrue);
    final plot = view.plots[1];
    expect(plot.civicType, CivicBuildingType.watchtower);
    expect(plot.farmType, isNull);
    expect(plot.tier, 1);
    expect(plot.underConstruction, isTrue);
  });

  test('a quarter the town does not own shows its plots locked', () {
    final game = projectGameState(tierWith(TownTier.village));
    final view = TownView.from(game, robin, _adults, at(10), districtId: kMarketRowDistrictId);
    expect(view.plots, hasLength(Balance.marketRowPlotCount));
    expect(view.plots.every((plot) => !plot.unlocked), isTrue);
  });

  test('a finished workshop job is ready to collect', () {
    final game = projectGameState([
      ...tierWith(TownTier.town, materials: MaterialBundle({MaterialKind.lumber: 100})),
      districtPurchased('market', kMarketRowDistrictId, when: at(0)),
      civicBuilt('workshop', kMarketRowDistrictId, 2, CivicBuildingType.workshop, when: at(0)),
      refiningStarted('job', 2, 'planks',
          when: at(1), completesAt: at(31), output: GoodsBundle({GoodsKind.planks: 2})),
    ]);
    bool ready(DateTime now) =>
        TownView.from(game, robin, _adults, now, districtId: kMarketRowDistrictId).plots[2].readyToCollect;
    expect(ready(at(10)), isFalse);
    expect(ready(at(40)), isTrue);
  });

  test('a farm past what the guards cover rests; one they cover does not', () {
    final restingPlot = Balance.unguardedFarmPlots;
    List<GameEvent> events({bool guarded = false}) => [
          ...tierWith(TownTier.town),
          districtPurchased('farmland', kFarmlandDistrictId, when: at(0)),
          districtPurchased('guards', kGuardPostDistrictId, when: at(0)),
          farmBuilt('first', 0, FarmBuildingType.farm, when: at(1)),
          farmBuilt('edge', restingPlot, FarmBuildingType.farm, when: at(1)),
          if (guarded) civicBuilt('barracks', kGuardPostDistrictId, 0, CivicBuildingType.barracks, when: at(1)),
        ];
    TownView viewOf(List<GameEvent> list) => TownView.from(
        projectGameState(list), robin, _adults, at(10), districtId: kFarmlandDistrictId);
    final unguarded = viewOf(events());
    expect(unguarded.plots[0].resting, isFalse);
    expect(unguarded.plots[restingPlot].resting, isTrue);
    expect(viewOf(events(guarded: true)).plots[restingPlot].resting, isFalse);
  });

  group('Castle Hill', () {
    test('an empty hill before the first stage, with taps on the Castle', () {
      final game = projectGameState(tierWith(TownTier.city));
      final view = TownView.from(game, robin, _adults, at(10), districtId: kCastleHillDistrictId);
      expect(view.layout, TownLayout.castleHill);
      expect(view.plots, isEmpty);
      expect(view.castleStagesDone, 0);
      expect(view.castleUnderConstruction, isFalse);
      final origin = TownLayout.castleHill.castleOrigin!;
      expect(view.targetAt(TownCell(origin.column + 2, origin.row + 2)), const CastleTarget());
      expect(view.targetAt(const TownCell(0, 0)), isNull);
    });

    test('a stage under way shows scaffolding, then the stage when it finishes', () {
      final game = projectGameState([
        ...tierWith(TownTier.city),
        castleStageStarted('foundation', 1, when: at(0)),
      ]);
      final done = at(0).add(Duration(days: Balance.castleStages.first.buildDays));
      TownView viewAt(DateTime now) =>
          TownView.from(game, robin, _adults, now, districtId: kCastleHillDistrictId);
      expect(viewAt(onDay(1)).castleStagesDone, 0);
      expect(viewAt(onDay(1)).castleUnderConstruction, isTrue);
      expect(viewAt(done).castleStagesDone, 1);
      expect(viewAt(done).castleUnderConstruction, isFalse);
      expect(viewAt(onDay(1)), isNot(viewAt(done)));
    });

    test('other districts have no Castle target', () {
      final view = TownView.from(projectGameState(tierWith(TownTier.city)), robin, _adults, at(10),
          districtId: kParkDistrictId);
      expect(view.castleStagesDone, 0);
      for (final origin in view.layout.plotOrigins) {
        expect(view.targetAt(origin), isA<PlotTarget>());
      }
    });
  });
}
