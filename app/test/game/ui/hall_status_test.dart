import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart'
    show spoilsChestId;
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/ui/hall_ledger_view.dart';
import 'package:lootlog/game/ui/hall_status.dart';

import '../../features/spoils/spoils_fixtures.dart';

void main() {
  final today = CalendarDay(2026, 10, 3);
  Set<GameDay> days(List<int> ds) => {for (final d in ds) CalendarDay(2026, 10, d)};

  group('liveStreak', () {
    test('a run ending today or yesterday is alive, frozen days counted', () {
      final s = StreakState(days([1, 2, 3]), days([2]));
      final live = liveStreak(s, today);
      expect(live.days, 3);
      expect(live.frozenDays, 1);
      expect(liveStreak(StreakState(days([1, 2])), today).days, 2);
    });

    test('a gap the tokens can cover still reads as alive', () {
      final s = StreakState(days([1]));
      final live = liveStreak(s, today, tokens: 1);
      expect(live.days, 1);
      expect(live.coveredByTokens, isTrue);
    });

    test('an uncovered gap reads as a fresh start, never a loss', () {
      expect(liveStreak(StreakState(days([1])), today).isEmpty, isTrue);
      expect(liveStreak(const StreakState(), today).isEmpty, isTrue);
    });
  });

  test('the two months before now are open for the ritual', () {
    final now = DateTime.utc(2026, 10, 3, 18);
    expect(openRitualMonths(now), [Month(2026, 9), Month(2026, 8)]);
    const p = PersonState(personId: 'u1');
    expect(pendingRitualMonths(p, now), [Month(2026, 8), Month(2026, 9)]);
  });

  test('a month whose spoils chest was granted is no longer pending', () {
    final now = DateTime.utc(2026, 10, 3, 18);
    final finished = PersonState(
      personId: 'u1',
      seenChestIds: {spoilsChestId('u1', Month(2026, 9))},
    );
    expect(pendingRitualMonths(finished, now), [Month(2026, 8)]);
    final bothFinished = PersonState(
      personId: 'u1',
      seenChestIds: {
        spoilsChestId('u1', Month(2026, 8)),
        spoilsChestId('u1', Month(2026, 9)),
      },
    );
    expect(pendingRitualMonths(bothFinished, now), isEmpty);
    expect(
        pendingRitualMonths(
            PersonState(
                personId: 'u2',
                seenChestIds: {spoilsChestId('u1', Month(2026, 9))}),
            now),
        [Month(2026, 8), Month(2026, 9)],
        reason: "only the person's own chest finishes their month");
  });

  test('months before the household first budgeted are never pending', () {
    final now = DateTime.utc(2026, 10, 3, 18);
    const p = PersonState(personId: 'u1');
    expect(pendingRitualMonths(p, now, firstBudgetMonth: Month(2026, 9)),
        [Month(2026, 9)]);
    expect(pendingRitualMonths(p, now, firstBudgetMonth: Month(2026, 10)),
        isEmpty);
  });

  test('firstBudgetMonth is the earliest category, or this month without one',
      () {
    final now = DateTime.utc(2026, 10, 3, 18);
    expect(firstBudgetMonth(allOverspentHousehold(), now), Month(2026, 9));
    expect(firstBudgetMonth(reduce(const [], asOf: now), now), Month(2026, 10));
  });

  test('savingsRunMonths counts a live run of saving months only', () {
    LeftoverAllocated alloc(Month m) => LeftoverAllocated(
          eventId: 'e${m.toKey()}',
          deviceId: 'd',
          userId: 'u1',
          occurredAt: DateTime.utc(m.year, m.month, 28),
          createdAt: DateTime.utc(m.year, m.month, 28),
          forUserId: 'u1',
          month: m,
          sliceId: 's1',
          allocations: const [
            Allocation(destination: CarryInSlice(), amountCents: 100),
          ],
        );
    final log = [alloc(Month(2026, 7)), alloc(Month(2026, 8)), alloc(Month(2026, 9))];
    expect(savingsRunMonths(log, 'u1', Month(2026, 10)), 3);
    expect(savingsRunMonths(log, 'u1', Month(2027, 1)), 0,
        reason: 'the run ended months ago');
    expect(savingsRunMonths(const [], 'u1', Month(2026, 10)), 0);
  });
}
