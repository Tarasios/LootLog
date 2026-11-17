/// The long road's pace, held so balance edits can't silently break it: a
/// simulated adult on 500 days of the real engine and commands
/// (`long_road_sim.dart`), logging every day, and another logging four days
/// a week.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_values.dart';

import 'long_road_sim.dart';

int _firstDay(List<SimDay> days, bool Function(SimDay day) test) =>
    days.firstWhere(test, orElse: () => const SimDay(999, TownTier.outpost, 0, 0, 0)).day;

String _summary(List<SimDay> days) {
  final tiers = [
    for (final tier in TownTier.values.skip(1)) '${tier.name} ${_firstDay(days, (d) => d.tier.index >= tier.index)}',
  ];
  final stages = [for (var stage = 1; stage <= 5; stage++) _firstDay(days, (d) => d.castleStages >= stage)];
  return '${tiers.join(', ')}; castle stages begun on days $stages, '
      'finished on day ${_firstDay(days, (d) => d.castleComplete)}; '
      'prosperity every 25 days: ${[for (var i = 24; i < days.length; i += 25) days[i].prosperity]}';
}

void main() {
  test('a daily player walks the long road to the castle', () {
    final days = simulateLongRoad(500);
    final summary = _summary(days);
    // ignore: avoid_print
    print('daily: $summary');
    final village = _firstDay(days, (d) => d.tier.index >= TownTier.village.index);
    final town = _firstDay(days, (d) => d.tier.index >= TownTier.town.index);
    final city = _firstDay(days, (d) => d.tier == TownTier.city);
    final firstStage = _firstDay(days, (d) => d.castleStages >= 1);
    final castle = _firstDay(days, (d) => d.castleComplete);
    expect(village, inInclusiveRange(21, 45), reason: summary);
    expect(town, inInclusiveRange(90, 150), reason: summary);
    expect(city, inInclusiveRange(220, 290), reason: summary);
    expect(firstStage, inInclusiveRange(city, city + 30), reason: 'soon after the city. $summary');
    // The Castle takes at least four months after the City, and stands
    // finished before day 500.
    expect(castle, inInclusiveRange(city + 120, 500), reason: summary);

    final quiet = <int>[];
    // Every window from the Village to the finished Castle, the road's end.
    for (var start = village; start + 10 <= castle; start += 10) {
      if (days.skip(start).take(10).every((d) => d.steps == 0)) quiet.add(start + 1);
    }
    expect(quiet, isEmpty, reason: 'every 10 days from the village to the castle brings a step. quiet from $quiet. $summary');
  });

  test('a player who logs four days a week still reaches the town', () {
    final days = simulateLongRoad(240, logsOn: (day) => (day - 1) % 7 < 4);
    final summary = _summary(days);
    // ignore: avoid_print
    print('four days a week: $summary');
    final town = _firstDay(days, (d) => d.tier.index >= TownTier.town.index);
    expect(town, lessThan(220), reason: summary);
  });
}
