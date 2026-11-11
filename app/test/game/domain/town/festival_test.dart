import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
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
          today: _monday.addDays(4),
          oldest: _monday,
        ),
        isEmpty,
      );
    });

    test('from Saturday on', () {
      expect(
        festivalWeeksDue(
          loggedDays: {_monday},
          today: saturday,
          oldest: _monday,
        ),
        [_monday],
      );
    });

    test('a quiet week waits until a returning person shows up', () {
      final lastFriday = _monday.addDays(-3);
      expect(
        festivalWeeksDue(
          loggedDays: {lastFriday},
          today: saturday,
          oldest: _monday,
        ),
        isEmpty,
      );
      // Showing up the next Tuesday still holds the quiet week's market day.
      final tuesday = _monday.addDays(8);
      expect(
        festivalWeeksDue(
          loggedDays: {lastFriday, tuesday},
          today: tuesday,
          oldest: _monday,
        ),
        [_monday],
      );
    });

    test("a first show-up on the weekend holds that weekend's market day", () {
      final sunday = saturday.next();
      expect(
        festivalWeeksDue(loggedDays: {sunday}, today: sunday, oldest: _monday),
        [_monday],
      );
    });

    test('a brand-new person has no festival for a week before they came', () {
      final tuesday = _monday.addDays(8);
      expect(
        festivalWeeksDue(
          loggedDays: {tuesday},
          today: tuesday,
          oldest: _monday,
        ),
        isEmpty,
      );
    });

    test('days backing the party as a caravan count as having been there', () {
      final tuesday = _monday.addDays(8);
      expect(
        festivalWeeksDue(
          loggedDays: {tuesday},
          caravanDays: {_monday.addDays(2)},
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
          today: later,
          oldest: later.addDays(-7),
        ),
        // The weekend of the 10th is out of the window; last week's
        // market day is still due, since the person showed up after it.
        [_monday.addDays(7)],
      );
    });
  });

  test('each tier pays only what it adds over the tier below', () {
    final market = festivalTierReward(FestivalTier.marketDay);
    final fair = festivalTierReward(FestivalTier.fair);
    final grand = festivalTierReward(FestivalTier.grandFestival);
    expect(market, Balance.festivalRewards[FestivalTier.marketDay]);
    expect(
      market.gems + fair.gems,
      Balance.festivalRewards[FestivalTier.fair]!.gems,
    );
    expect(
      market.materials + fair.materials,
      Balance.festivalRewards[FestivalTier.fair]!.materials,
    );
    expect(
      market.gems + fair.gems + grand.gems,
      Balance.festivalRewards[FestivalTier.grandFestival]!.gems,
    );
    expect(
      market.materials + fair.materials + grand.materials,
      Balance.festivalRewards[FestivalTier.grandFestival]!.materials,
    );
  });

  test('reward ids name the person, the week and the tier', () {
    expect(
      festivalRewardId('ada', _monday, FestivalTier.fair),
      'festival:ada:2026-10-05:fair',
    );
  });
}
