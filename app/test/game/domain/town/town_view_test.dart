import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
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

  group('value equality', () {
    test('two views built from the same inputs are equal', () {
      final first = TownView.from(GameState.initial(), adults, startedAt);
      final second = TownView.from(GameState.initial(), adults, startedAt);
      expect(identical(first, second), isFalse);
      expect(second, first);
      expect(second.hashCode, first.hashCode);
    });

    test('a building going up makes the view differ', () {
      final empty = TownView.from(GameState.initial(), adults, startedAt);
      final game = projectGameState([lumberyardOnPlotZero(completesAt: startedAt)]);
      expect(TownView.from(game, adults, startedAt), isNot(empty));
    });

    test('a construction finishing differs from the same view before it ends', () {
      final endsAt = startedAt.add(const Duration(hours: 1));
      final game = projectGameState([lumberyardOnPlotZero(completesAt: endsAt)]);
      final during = TownView.from(game, adults, startedAt.add(const Duration(minutes: 10)));
      final after = TownView.from(game, adults, endsAt.add(const Duration(minutes: 1)));
      expect(after, isNot(during));
    });

    test('a renamed or re-moded resident makes the view differ', () {
      final base = TownView.from(GameState.initial(), adults, startedAt);
      final renamed = TownView.from(GameState.initial(), [
        const TownAdult(memberId: 'alex', name: 'Alexa', inAdventure: true),
        adults.last,
      ], startedAt);
      final switched = TownView.from(GameState.initial(), [
        adults.first,
        const TownAdult(memberId: 'sam', name: 'Sam', inAdventure: true),
      ], startedAt);
      expect(renamed, isNot(base));
      expect(switched, isNot(base));
    });

    test('the dungeon gate opening makes the view differ', () {
      final closed = TownView.from(GameState.initial(), adults, startedAt);
      final open = TownView.from(GameState.initial(), adults, startedAt, dungeonOpen: true);
      expect(closed.dungeonOpen, isFalse);
      expect(open.dungeonOpen, isTrue);
      expect(open, isNot(closed));
      expect(open, TownView.from(GameState.initial(), adults, startedAt, dungeonOpen: true));
    });
    GameState gameWithBenchAt(int column) => projectGameState([
          ItemAcquired(
            eventId: 'b1',
            deviceId: 'device',
            actorId: 'alex',
            occurredAt: startedAt,
            createdAt: startedAt,
            acquisitionId: 'shop:bench',
            itemId: 'town_bench',
            source: DecorSource.shop,
            toTown: true,
          ),
          ItemPlaced(
            eventId: 'b2',
            deviceId: 'device',
            actorId: 'alex',
            occurredAt: startedAt,
            createdAt: startedAt,
            placementId: 'bench-spot',
            itemId: 'town_bench',
            space: DecorSpace.town,
            column: column,
            row: 6,
          ),
        ]);

    test('placed town decorations are listed and make the view differ', () {
      final empty = TownView.from(GameState.initial(), adults, startedAt);
      final withBench = TownView.from(gameWithBenchAt(4), adults, startedAt);
      expect(withBench.townPlacements.single.itemId, 'town_bench');
      expect(empty.townPlacements, isEmpty);
      expect(withBench, isNot(empty));
      expect(TownView.from(gameWithBenchAt(5), adults, startedAt), isNot(withBench));
      expect(TownView.from(gameWithBenchAt(4), adults, startedAt), withBench);
    });

    test('a goal picture arriving makes the view differ', () {
      final base = TownView.from(gameWithBenchAt(4), adults, startedAt);
      final pictured = TownView.from(gameWithBenchAt(4), adults, startedAt, goalPictures: const {'canoe': 'sha'});
      expect(pictured.goalPictures, {'canoe': 'sha'});
      expect(pictured, isNot(base));
    });
  });
}
