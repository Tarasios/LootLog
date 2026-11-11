import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/festival.dart';

/// Monday 2026-10-05; its Saturday is the 10th.
const GameDay _monday = GameDay(2026, 10, 5);

PersonState _loggedOn(
  Iterable<int> offsetsFromMonday, {
  Map<GameDay, FestivalTier> festivals = const {},
}) => PersonState(
  personId: 'ada',
  streak: StreakState({for (final o in offsetsFromMonday) _monday.addDays(o)}),
  festivals: festivals,
);

void main() {
  test('tiers: 0–2 weekdays a market day, 3–4 a fair, 5 a grand festival', () {
    expect(festivalTierFor(0), FestivalTier.marketDay);
    expect(festivalTierFor(2), FestivalTier.marketDay);
    expect(festivalTierFor(3), FestivalTier.fair);
    expect(festivalTierFor(4), FestivalTier.fair);
    expect(festivalTierFor(5), FestivalTier.grandFestival);
  });

  test('town spirit counts logged weekdays only, from any day of the week', () {
    final person = _loggedOn([0, 2, 4, 5, 6]); // Mon, Wed, Fri, Sat, Sun
    for (var offset = 0; offset < 7; offset++) {
      expect(townSpirit(person, _monday.addDays(offset)), 3);
    }
    expect(townSpirit(person, _monday.addDays(7)), 0);
  });

  test('freeze-covered days are not town spirit', () {
    final person = PersonState(
      personId: 'ada',
      streak: StreakState({_monday, _monday.next()}, {_monday.next()}),
    );
    expect(townSpirit(person, _monday), 1);
  });

  test('the festival weekend is Saturday and Sunday', () {
    expect(isFestivalWeekend(_monday.addDays(4)), isFalse); // Friday
    expect(isFestivalWeekend(_monday.addDays(5)), isTrue);
    expect(isFestivalWeekend(_monday.addDays(6)), isTrue);
    expect(isFestivalWeekend(_monday.addDays(7)), isFalse);
  });

  test("festivalToday is the tier held for this weekend's week", () {
    final person = _loggedOn(const [], festivals: {_monday: FestivalTier.fair});
    expect(festivalToday(person, _monday.addDays(4)), isNull);
    expect(festivalToday(person, _monday.addDays(5)), FestivalTier.fair);
    expect(festivalToday(person, _monday.addDays(6)), FestivalTier.fair);
    expect(festivalToday(person, _monday.addDays(12)), isNull);
  });

  // [oldest] starts on the Monday so the weekend before (the 3rd and 4th),
  // whose market day would also be due once the person shows up, stays out.
  group('which festivals are due', () {
    final saturday = _monday.addDays(5);

    test('not before Saturday', () {
      expect(
        festivalWeeksDue(
          loggedDays: {_monday},
          heldWeeks: const {},
          today: _monday.addDays(4),
          oldest: _monday,
        ),
        isEmpty,
      );
    });

    test('from Saturday on, once', () {
      expect(
        festivalWeeksDue(
          loggedDays: {_monday},
          heldWeeks: const {},
          today: saturday,
          oldest: _monday,
        ),
        [_monday],
      );
      expect(
        festivalWeeksDue(
          loggedDays: {_monday},
          heldWeeks: {_monday},
          today: saturday,
          oldest: _monday,
        ),
        isEmpty,
      );
    });

    test('a week with no weekday waits until the person shows up', () {
      expect(
        festivalWeeksDue(
          loggedDays: const {},
          heldWeeks: const {},
          today: saturday,
          oldest: _monday,
        ),
        isEmpty,
      );
      final sunday = saturday.next();
      expect(
        festivalWeeksDue(
          loggedDays: {sunday},
          heldWeeks: const {},
          today: sunday,
          oldest: _monday,
        ),
        [_monday],
      );
      // Showing up the next Tuesday still holds last week's market day.
      final tuesday = _monday.addDays(8);
      expect(
        festivalWeeksDue(
          loggedDays: {tuesday},
          heldWeeks: const {},
          today: tuesday,
          oldest: _monday,
        ),
        [_monday],
      );
    });

    test('never for a weekend before the lookback window', () {
      final later = _monday.addDays(14);
      expect(
        festivalWeeksDue(
          loggedDays: {_monday, later},
          heldWeeks: const {},
          today: later,
          oldest: later.addDays(-7),
        ),
        // The weekend of the 10th is out of the window; last week's
        // market day is still due, since the person showed up after it.
        [_monday.addDays(7)],
      );
    });
  });
}
