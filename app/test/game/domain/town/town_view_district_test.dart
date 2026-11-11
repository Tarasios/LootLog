import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/reason_codes.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';
import 'package:lootlog/game/domain/town/town_view.dart';

import '../game_fixtures.dart';
import 'growth_fixtures.dart';

const _adults = [TownAdult(memberId: robin, name: 'Robin', inAdventure: true)];

TownCell _inside(TownCell origin) => TownCell(origin.column + 1, origin.row + 1);

void main() {
  test('the farmland view draws its own map, with no houses, gate or decorations', () {
    final game = projectGameState([...hamletWith(), districtPurchased('buy', kFarmlandDistrictId, when: at(0))]);
    final view = TownView.from(game, robin, _adults, at(5), districtId: kFarmlandDistrictId, dungeonOpen: true);
    expect(view.layout, TownLayout.farmland);
    expect(view.districtId, kFarmlandDistrictId);
    expect(view.plots, hasLength(6));
    expect(view.plots.every((plot) => plot.unlocked && plot.districtId == kFarmlandDistrictId), isTrue);
    expect(view.residents, isEmpty);
    expect(view.townPlacements, isEmpty);
    expect(view.dungeonOpen, isFalse);
  });

  test('farmland the town does not own shows its plots locked', () {
    final view = TownView.from(GameState.initial(), robin, _adults, at(5), districtId: kFarmlandDistrictId);
    expect(view.plots.every((plot) => !plot.unlocked), isTrue);
  });

  test('a farm building shows its type, tier and build timer', () {
    final game = projectGameState([
      ...hamletWith(),
      districtPurchased('buy', kFarmlandDistrictId, when: at(0)),
      farmBuilt('farm', 2, FarmBuildingType.orchard, when: at(1), completesAt: at(61)),
    ]);
    final plot = TownView.from(game, robin, _adults, at(10), districtId: kFarmlandDistrictId).plots[2];
    expect(plot.farmType, FarmBuildingType.orchard);
    expect(plot.buildingType, isNull);
    expect(plot.tier, 1);
    expect(plot.underConstruction, isTrue);
    expect(plot.readyToCollect, isFalse);
  });

  test('a farm with food grown is ready to harvest', () {
    final game = projectGameState([
      ...hamletWith(),
      // A logged day, so the crews work the whole of it.
      granted('a-log', when: at(-5), rewardId: 'a-log', reasonCode: GameReasonCodes.dailyLog),
      districtPurchased('buy', kFarmlandDistrictId, when: at(0)),
      farmBuilt('farm', 0, FarmBuildingType.farm, when: at(1)),
    ]);
    final plot = TownView.from(game, robin, _adults, at(3 * 60), districtId: kFarmlandDistrictId).plots[0];
    expect(plot.readyToCollect, isTrue);
  });

  test('a granary grows nothing, so it is never ready to harvest', () {
    final game = projectGameState([
      ...hamletWith(),
      districtPurchased('buy', kFarmlandDistrictId, when: at(0)),
      farmBuilt('granary', 1, FarmBuildingType.granary, when: at(1)),
    ]);
    final plot = TownView.from(game, robin, _adults, at(6 * 60), districtId: kFarmlandDistrictId).plots[1];
    expect(plot.farmType, FarmBuildingType.granary);
    expect(plot.readyToCollect, isFalse);
  });

  test('a tap on a field names its district and plot', () {
    final view = TownView.from(GameState.initial(), robin, _adults, at(5), districtId: kFarmlandDistrictId);
    final origin = TownLayout.farmland.plotOrigins[3];
    expect(view.targetAt(_inside(origin)), const PlotTarget(3, districtId: kFarmlandDistrictId));
    expect(view.targetAt(_inside(origin)), isNot(const PlotTarget(3)));
  });

  test('the outpost is still the default, its targets in the outpost', () {
    final view = TownView.from(GameState.initial(), robin, _adults, at(5));
    expect(view.districtId, kOutpostDistrictId);
    expect(view.targetAt(_inside(TownLayout.standard.plotOrigins[0])), const PlotTarget(0));
    expect(const PlotTarget(0).districtId, kOutpostDistrictId);
  });
}
