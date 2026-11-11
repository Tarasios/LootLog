/// Town spirit and the weekend festival. A person's town spirit for a week
/// is how many weekdays (Monday to Friday) they logged a purchase or checked
/// in; freeze-covered days do not count. Every weekend the town holds a
/// festival sized to that week: a market day, a fair, or a grand festival.
/// There is always a festival — a quiet week still gets its market day once
/// the person next shows up — so the spirit only ever adds.
///
/// The reward engine grants each festival once (see [festivalWeeksDue]);
/// these helpers are the pure rules it and the screens share.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../game_state.dart';
import '../game_values.dart';

export '../game_values.dart' show FestivalTier;

/// The `town_events.json` key of the line announcing a [tier] festival.
String festivalFlavourKey(FestivalTier tier) => 'festival.${tier.name}';

/// The `town_events.json` key of the line for the joint festival bonus.
const String kJointFestivalFlavourKey = 'festival.joint';

/// The festival reward's id: one per person per week.
String festivalRewardId(String personId, GameDay week) =>
    'festival:$personId:${week.toKey()}';

/// The joint festival bonus's id: one per person per week.
String jointFestivalRewardId(String personId, GameDay week) =>
    'festival.joint:$personId:${week.toKey()}';

/// How many weekdays of [anyDayInWeek]'s week are in [loggedDays] (0–5).
int weekdaysLogged(Set<GameDay> loggedDays, GameDay anyDayInWeek) {
  final monday = anyDayInWeek.weekStart;
  var count = 0;
  for (var offset = 0; offset < 5; offset++) {
    if (loggedDays.contains(monday.addDays(offset))) count++;
  }
  return count;
}

/// [person]'s town spirit for the week holding [anyDayInWeek]: the
/// weekdays they actually showed up (0–5).
int townSpirit(PersonState person, GameDay anyDayInWeek) =>
    weekdaysLogged(person.streak.loggedDays, anyDayInWeek);

/// The festival a week with [weekdaysLogged] earns.
FestivalTier festivalTierFor(int weekdaysLogged) {
  if (weekdaysLogged >= Balance.festivalGrandWeekdays) {
    return FestivalTier.grandFestival;
  }
  if (weekdaysLogged >= Balance.festivalFairWeekdays) return FestivalTier.fair;
  return FestivalTier.marketDay;
}

/// Whether [today] is a festival day (Saturday or Sunday).
bool isFestivalWeekend(GameDay today) => today.weekday >= DateTime.saturday;

/// The festival [person]'s town is holding [today], or null on a weekday or
/// before this weekend's festival has been granted.
FestivalTier? festivalToday(PersonState person, GameDay today) =>
    isFestivalWeekend(today) ? person.festivals[today.weekStart] : null;

/// The Mondays of the weeks whose weekend has begun by [today] and has not
/// wholly passed before [oldest], latest last.
List<GameDay> festivalWeeksInWindow({
  required GameDay today,
  required GameDay oldest,
}) {
  final weeks = <GameDay>[];
  for (
    var monday = oldest.weekStart;
    monday <= today.weekStart;
    monday = monday.addDays(7)
  ) {
    final saturday = monday.addDays(5);
    final sunday = monday.addDays(6);
    if (saturday <= today && sunday >= oldest) weeks.add(monday);
  }
  return weeks;
}

/// The Mondays of the weeks whose festival is due for a person as of
/// [today]: the weekend has begun, it is not wholly before [oldest] (the
/// reward lookback), it was not held already ([heldWeeks]), and the person
/// either logged a weekday that week or has shown up since its Saturday.
List<GameDay> festivalWeeksDue({
  required Set<GameDay> loggedDays,
  required Set<GameDay> heldWeeks,
  required GameDay today,
  required GameDay oldest,
}) => [
  for (final monday in festivalWeeksInWindow(today: today, oldest: oldest))
    if (!heldWeeks.contains(monday) &&
        (weekdaysLogged(loggedDays, monday) > 0 ||
            loggedDays.any((day) => day >= monday.addDays(5) && day <= today)))
      monday,
];
