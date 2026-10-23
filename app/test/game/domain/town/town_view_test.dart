import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';
import 'package:lootlog/game/domain/town/town_view.dart';

final startedAt = DateTime.utc(2026, 10, 1, 9);

BuildingStarted lumberyardOnPlotZero({required DateTime completesAt}) => BuildingStarted(
      eventId: '01900000-0000-7000-8000-000000000001',
      deviceId: 'device',
      actorId: 'alex',
      occurredAt: startedAt,
      createdAt: startedAt,
      plotIndex: 0,
      buildingType: BuildingType.lumberyard,
      tier: 1,
      cost: Loot.none,
      completesAt: completesAt,
    );

const adults = [
  TownAdult(memberId: 'alex', name: 'Alex', inAdventure: true),
  TownAdult(memberId: 'sam', name: 'Sam', inAdventure: false),
];

void main() {
  test('starting plots are unlocked and empty; the rest are locked', () {
    final view = TownView.from(GameState.initial(), adults, startedAt);
    expect(view.plots, hasLength(11));
    expect(view.plots.where((plot) => plot.unlocked), hasLength(3));
    expect(view.plots.first.buildingType, isNull);
  });

  test('a building under construction is marked and not collectable', () {
    final game = projectGameState([lumberyardOnPlotZero(completesAt: startedAt.add(const Duration(hours: 1)))]);
    final plot = TownView.from(game, adults, startedAt.add(const Duration(minutes: 10))).plots.first;
    expect(plot.buildingType, BuildingType.lumberyard);
    expect(plot.underConstruction, isTrue);
    expect(plot.readyToCollect, isFalse);
  });

  test('a finished producer with output waiting is ready to collect', () {
    final game = projectGameState([lumberyardOnPlotZero(completesAt: startedAt)]);
    final plot = TownView.from(game, adults, startedAt.add(const Duration(hours: 6))).plots.first;
    expect(plot.underConstruction, isFalse);
    expect(plot.readyToCollect, isTrue);
  });

  test('every adult gets a house in roster order', () {
    final view = TownView.from(GameState.initial(), adults, startedAt);
    expect(view.residents.map((resident) => resident.personId), ['alex', 'sam']);
    expect(view.residents.first.houseOrigin, TownLayout.standard.houseOrigins.first);
    expect(view.residents.last.inAdventure, isFalse);
  });

  test('targetAt maps any cell of a footprint, the gate, and nothing on scenery', () {
    final view = TownView.from(GameState.initial(), adults, startedAt);
    final plotOrigin = TownLayout.standard.plotOrigins[1];
    expect(view.targetAt(TownCell(plotOrigin.column + 1, plotOrigin.row + 1)), const PlotTarget(1));
    expect(view.targetAt(TownLayout.standard.houseOrigins.first), const HouseTarget('alex'));
    expect(view.targetAt(TownLayout.standard.gate), const GateTarget());
    expect(view.targetAt(const TownCell(1, 1)), isNull);
  });

  test('an empty house slot is not a target', () {
    final view = TownView.from(GameState.initial(), adults, startedAt);
    expect(view.targetAt(TownLayout.standard.houseOrigins[4]), isNull);
  });
}
