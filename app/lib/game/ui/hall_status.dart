/// Small pure read helpers the hall screens share: the live streak, the open
/// ritual months, whether today and this week are already covered. Pure Dart.
library;

import '../../domain/time.dart';
import '../config/balance.dart';
import '../domain/commands/game_commands.dart' show spoilsChestId;
import '../domain/game_state.dart';
import '../domain/game_values.dart';
import '../domain/reason_codes.dart';

/// A person's streak as it reads today.
class LiveStreak {
  const LiveStreak({
    required this.days,
    required this.frozenDays,
    this.coveredByTokens = false,
  });

  /// Consecutive covered days in the current run.
  final int days;

  /// How many of those a freeze token covered.
  final int frozenDays;

  /// The run has a gap since the last covered day, but the person holds
  /// enough freeze tokens to cover it the next time they log.
  final bool coveredByTokens;

  bool get isEmpty => days == 0;
}

/// [streak] as of [today], for someone holding [tokens] freeze tokens. A run
/// whose last day is today or yesterday is alive. An older run still reads as
/// alive when the tokens cover every missed day (they are spent on the next
/// log); otherwise it reads as a fresh start, never as a loss.
LiveStreak liveStreak(StreakState streak, GameDay today, {int tokens = 0}) {
  final last = streak.lastDay;
  if (last == null) return const LiveStreak(days: 0, frozenDays: 0);
  var days = 0;
  var frozen = 0;
  for (GameDay? d = last; d != null && streak.coveredDays.contains(d);
      d = d.previous()) {
    days++;
    if (streak.frozenDays.contains(d)) frozen++;
  }
  final gap = last.daysUntil(today) - 1; // missed days before today
  if (gap <= 0) return LiveStreak(days: days, frozenDays: frozen);
  if (gap <= tokens) {
    return LiveStreak(days: days, frozenDays: frozen, coveredByTokens: true);
  }
  return const LiveStreak(days: 0, frozenDays: 0);
}

/// The months whose spoils ritual can still be done at [now], most recent
/// first.
List<Month> openRitualMonths(DateTime now) {
  final months = <Month>[];
  var m = Month.fromInstant(now);
  for (var i = 0; i < Balance.ritualOpenMonths; i++) {
    m = m.prev();
    months.add(m);
  }
  return months;
}

/// The open months whose month-end dungeon is not finished yet, oldest first.
///
/// A month is finished once its spoils chest has been granted (the dungeon's
/// return to town) or, in older logs, once its seasonal boss was fought.
/// Months before [firstBudgetMonth] (when given) are never pending: the
/// household did not budget then.
List<Month> pendingRitualMonths(PersonState person, DateTime now,
        {Month? firstBudgetMonth}) =>
    [
      for (final m in openRitualMonths(now).reversed)
        if ((firstBudgetMonth == null || !m.isBefore(firstBudgetMonth)) &&
            person.ritual[m]?.boss == null &&
            !person.seenChestIds.contains(spoilsChestId(person.personId, m)))
          m,
    ];

/// Whether [person]'s [today] already counts toward their streak.
bool todayCovered(PersonState person, GameDay today) =>
    person.streak.coveredDays.contains(today);

/// Whether [person] has reconciled the week containing [today].
bool weekReconciled(PersonState person, GameDay today) =>
    person.seenChestIds.contains(
        '${GameReasonCodes.weeklyReconcile}:${person.personId}:'
        '${today.weekStart.toKey()}') ||
    person.seenRewardIds.contains(
        '${GameReasonCodes.weeklyReconcile}:${person.personId}:'
        '${today.weekStart.toKey()}');

/// Supply-caravan deliveries a Standard adult has sent the party.
int caravanDeliveries(PersonState person) => person.seenRewardIds
    .where((id) => id.startsWith('caravan:'))
    .length;

/// The materials the pool tracks against the Storehouse cap, in order.
List<MaterialKind> get cappedMaterials => [
      for (final m in MaterialKind.values)
        if (!Balance.uncappedMaterials.contains(m)) m,
    ];
