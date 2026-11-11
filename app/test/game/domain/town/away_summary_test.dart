/// The "while you were away" read model: which producers have made
/// something since their last collection, how much fits in the Storehouse,
/// and how many quiet days (short shifts) the stretch held.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/hall_rules.dart';
import 'package:lootlog/game/domain/town/away_summary.dart';
import 'package:lootlog/game/domain/town/town_ownership.dart';

/// Vancouver midnight of an October 2026 day (PDT, UTC-7).
DateTime octoberMidnight(int day) => DateTime.utc(2026, 10, day, 7);

DateTime octoberLocal(int day, int hours) =>
    octoberMidnight(day).add(Duration(hours: hours));

BuildingState producer(BuildingType type, DateTime from) => BuildingState(
  type: type,
  tier: 1,
  startedAt: from,
  completesAt: from,
);

GameState gameWith({
  required Map<int, BuildingState?> plots,
  required Map<int, DateTime> lastCollected,
  MaterialBundle materials = const MaterialBundle.empty(),
}) => GameState(
  ownership: TownOwnership(sharedHall: HallState(
    plots: {
      for (final entry in plots.entries) entry.key: PlotState(entry.key, entry.value),
    },
    materials: materials,
    lastCollectedAt: {
      for (final entry in lastCollected.entries) buildingIdForPlot(entry.key): entry.value,
    },
  )),
);

void main() {
  group('quietDaysSince', () {
    test('counts every day the stretch touches that nobody logged', () {
      final from = octoberLocal(5, 9);
      final now = octoberLocal(7, 10);
      expect(quietDaysSince(from, now, {}), 3);
      expect(quietDaysSince(from, now, {const GameDay(2026, 10, 6)}), 2);
      expect(
        quietDaysSince(from, now, {
          const GameDay(2026, 10, 5),
          const GameDay(2026, 10, 6),
          const GameDay(2026, 10, 7),
        }),
        0,
      );
    });

    test('an empty or backwards stretch has no quiet days', () {
      final instant = octoberLocal(5, 9);
      expect(quietDaysSince(instant, instant, {}), 0);
      expect(quietDaysSince(instant, instant.subtract(const Duration(hours: 1)), {}), 0);
    });
  });

  test('producerStretchStart is the last collection, null for a non-producer', () {
    final from = octoberLocal(5, 9);
    final game = gameWith(
      plots: {0: producer(BuildingType.lumberyard, from), 1: producer(BuildingType.storehouse, from), 2: null},
      lastCollected: {0: from},
    );
    expect(producerStretchStart(game.townOf('robin'), 0), from);
    expect(producerStretchStart(game.townOf('robin'), 1), isNull);
    expect(producerStretchStart(game.townOf('robin'), 2), isNull);
    expect(producerStretchStart(game.townOf('robin'), 9), isNull);
  });

  group('awaySummary', () {
    // Nobody logged Oct 6, so the crews work its first eight hours.
    test('lists each producer with something made, in plot order', () {
      final from = octoberLocal(6, 2);
      final game = gameWith(
        plots: {
          0: producer(BuildingType.quarry, from),
          1: producer(BuildingType.lumberyard, from),
          2: producer(BuildingType.forge, from),
        },
        lastCollected: {0: from, 1: from},
      );
      final summary = awaySummary(game, 'robin', octoberLocal(6, 6));
      expect([for (final row in summary.producers) row.plotIndex], [0, 1]);
      expect(summary.producers.first.type, BuildingType.quarry);
      expect(summary.producers.first.made.isEmpty, isFalse);
      expect(summary.producers.first.fits, summary.producers.first.made);
      expect(summary.isEmpty, isFalse);
    });

    test('nothing made yet is an empty summary', () {
      final from = octoberLocal(6, 9);
      final game = gameWith(
        plots: {0: producer(BuildingType.quarry, from)},
        lastCollected: {0: from},
      );
      expect(awaySummary(game, 'robin', from).isEmpty, isTrue);
    });

    test('a full Storehouse keeps the row, with nothing that fits', () {
      final from = octoberLocal(6, 2);
      final game = gameWith(
        plots: {0: producer(BuildingType.lumberyard, from)},
        lastCollected: {0: from},
        materials: MaterialBundle({MaterialKind.lumber: 100000}),
      );
      final row = awaySummary(game, 'robin', octoberLocal(6, 6)).producers.single;
      expect(row.made.isEmpty, isFalse);
      expect(row.fits.isEmpty, isTrue);
      expect(row.storehouseFull, isTrue);
    });

    test('quiet days cover the longest stretch; today counts until logged', () {
      final game = gameWith(
        plots: {
          0: producer(BuildingType.quarry, octoberLocal(4, 9)),
          1: producer(BuildingType.lumberyard, octoberLocal(6, 9)),
        },
        lastCollected: {0: octoberLocal(4, 9), 1: octoberLocal(6, 9)},
      );
      final summary = awaySummary(game, 'robin', octoberLocal(6, 12));
      // Oct 4, 5 and 6 (today) were quiet.
      expect(summary.quietDays, 3);
      expect(summary.todayLogged, isFalse);
    });

    test('no quiet day in the stretch when every day was logged', () {
      final from = octoberLocal(6, 9);
      final base = gameWith(plots: {0: producer(BuildingType.quarry, from)}, lastCollected: {0: from});
      final logged = base.copyWith(
        people: {
          'robin': PersonState(
            personId: 'robin',
            streak: StreakState({const GameDay(2026, 10, 6)}),
          ),
        },
      );
      final summary = awaySummary(logged, 'robin', octoberLocal(6, 20));
      expect(summary.quietDays, 0);
      expect(summary.todayLogged, isTrue);
    });

    test("a neighbour's logged day is not this town's", () {
      final from = octoberLocal(6, 2);
      final base = gameWith(plots: {0: producer(BuildingType.quarry, from)}, lastCollected: {0: from});
      final neighbourLogged = base.copyWith(
        people: {
          'sam': PersonState(
            personId: 'sam',
            streak: StreakState({const GameDay(2026, 10, 6)}),
          ),
        },
      );
      final summary = awaySummary(neighbourLogged, 'robin', octoberLocal(6, 20));
      expect(summary.quietDays, 1);
      expect(summary.todayLogged, isFalse);
    });
  });
}
