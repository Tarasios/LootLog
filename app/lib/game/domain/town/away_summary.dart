/// The "while you were away" read model: every producer that has made
/// something since its last collection (and how much of it fits in the
/// Storehouse), plus how many quiet days the stretch held — days nobody
/// logged, when the crews work the short shift. Derived on every read; never
/// stored. Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../game_state.dart';
import '../game_values.dart';
import '../hall_rules.dart';

/// One producer's row in the summary.
class AwayProducer {
  const AwayProducer({
    required this.plotIndex,
    required this.type,
    required this.made,
    required this.fits,
  });

  final int plotIndex;
  final BuildingType type;

  /// Everything made since the last collection.
  final MaterialBundle made;

  /// The part of [made] the Storehouse has room for right now.
  final MaterialBundle fits;

  /// Nothing more fits: collecting would be refused until there is room.
  bool get storehouseFull => fits.isEmpty;
}

/// What the town made while the player was away.
class AwaySummary {
  const AwaySummary({
    required this.producers,
    required this.quietDays,
    required this.todayLogged,
  });

  static const AwaySummary empty = AwaySummary(producers: [], quietDays: 0, todayLogged: false);

  /// Producers with something made, in plot order.
  final List<AwayProducer> producers;

  /// Days in the longest listed stretch that nobody logged (today included
  /// until someone logs it).
  final int quietDays;

  /// Whether someone has logged today, so today is a full shift.
  final bool todayLogged;

  bool get isEmpty => producers.isEmpty;
}

/// How many household days that [from]..[now] touches are not in
/// [activeDays]: the days the crews worked a short shift.
int quietDaysSince(DateTime from, DateTime now, Set<GameDay> activeDays) {
  if (!now.isAfter(from)) return 0;
  final last = GameDay.fromInstant(now);
  var quiet = 0;
  for (var day = GameDay.fromInstant(from); day <= last; day = day.addDays(1)) {
    if (!activeDays.contains(day)) quiet++;
  }
  return quiet;
}

/// The summary of [game]'s producers as of [now].
AwaySummary awaySummary(GameState game, DateTime now) {
  final hall = game.hall;
  final activeDays = game.townActiveDays;
  final producers = <AwayProducer>[];
  DateTime? earliest;
  final indices = hall.plots.keys.toList()..sort();
  for (final index in indices) {
    final building = hall.plots[index]?.building;
    if (building == null || !Balance.buildings[building.type]!.isProducer) continue;
    final made = uncollectedProduction(hall, index, now, activeDays: activeDays);
    if (made.isEmpty) continue;
    producers.add(
      AwayProducer(
        plotIndex: index,
        type: building.type,
        made: made,
        fits: collectableNow(hall, index, now, activeDays: activeDays),
      ),
    );
    final start = producerStretchStart(hall, index);
    if (start != null && (earliest == null || start.isBefore(earliest))) earliest = start;
  }
  return AwaySummary(
    producers: List.unmodifiable(producers),
    quietDays: earliest == null ? 0 : quietDaysSince(earliest, now, activeDays),
    todayLogged: activeDays.contains(GameDay.fromInstant(now)),
  );
}
