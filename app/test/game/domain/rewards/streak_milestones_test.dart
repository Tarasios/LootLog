import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';
import 'package:lootlog/game/domain/rewards/streak_milestones.dart';

final catalog = DecorCatalog.fromJson(
    jsonDecode(File('assets/game/catalog.json').readAsStringSync()) as Map<String, dynamic>);
const party = Party([PartyAdult('alex', inAdventure: true), PartyAdult('sam', inAdventure: false)]);

/// Daily-log rewards for [personId] on [days] consecutive days ending 2026-10-23.
List<GameEvent> streakEvents(int days, {String personId = 'alex', int firstDayOffset = 0}) => [
      for (var day = firstDayOffset; day < firstDayOffset + days; day++)
        RewardGranted(
          eventId: '01900000-0000-7000-8000-$personId-${day.toString().padLeft(4, '0')}',
          deviceId: 'd',
          actorId: personId,
          occurredAt: DateTime.utc(2026, 10, 23, 18).subtract(Duration(days: day)),
          createdAt: DateTime.utc(2026, 10, 23, 18),
          rewardId: 'log.daily:$personId:$day',
          kind: 'gems',
          gems: 5,
          materials: const MaterialBundle.empty(),
          tokens: 0,
          reasonCode: 'log.daily',
          sourceLedgerEventIds: const [],
        ),
    ];

GameState streakOf(int days, {String personId = 'alex'}) =>
    projectGameState(streakEvents(days, personId: personId));

var _stampCounter = 0;
GameEventStamp newStamp() => GameEventStamp(
      deviceId: 'd',
      newEventId: () => '01900000-0000-7000-b000-${(++_stampCounter).toString().padLeft(12, '0')}',
    );

List<GameEvent> evaluate(GameState state) =>
    const StreakMilestones().evaluate(state, party, catalog, FixedClock(DateTime.utc(2026, 10, 23, 20)), newStamp());

void main() {
  test('six days earns nothing; seven earns the title and the candle', () {
    expect(evaluate(streakOf(6)), isEmpty);
    final grants = evaluate(streakOf(7)).cast<ItemAcquired>();
    expect(grants.map((grant) => grant.itemId), unorderedEquals(['streak_7_title', 'streak_7_item']));
  });

  test('granted milestones are not granted again', () {
    var state = streakOf(7);
    final grants = evaluate(state);
    expect(grants, isNotEmpty);
    state = projectGameState([...streakEvents(7), ...grants]);
    expect(evaluate(state), isEmpty);
  });

  test('a milestone stays earned when the streak later breaks', () {
    final earned = evaluate(streakOf(7));
    // The seven days are followed by a gap, then a fresh one-day run.
    final laterRun = streakEvents(1, firstDayOffset: -5);
    final state = projectGameState([...streakEvents(7), ...earned, ...laterRun]);
    expect(state.person('alex').streak.count, 1);
    expect(state.decor.ownedCount('alex', 'streak_7_item'), 1);
    expect(evaluate(state), isEmpty);
  });

  test('only Adventure adults earn milestones', () {
    final samState = streakOf(30, personId: 'sam');
    expect(evaluate(samState), isEmpty);
    final grants = evaluate(streakOf(30)).cast<ItemAcquired>();
    expect(grants, isNotEmpty);
    expect(grants.every((grant) => grant.actorId == 'alex'), isTrue);
  });

  test('earlier milestones are granted too when a longer streak is first seen', () {
    final grants = evaluate(streakOf(30)).cast<ItemAcquired>();
    expect(grants.map((grant) => grant.itemId),
        containsAll(['streak_7_title', 'streak_7_item', 'streak_30_title', 'streak_30_item']));
  });

  test('the town milestone item goes to the town pool', () {
    final grants = evaluate(streakOf(100)).cast<ItemAcquired>();
    final fountain = grants.firstWhere((grant) => grant.itemId == 'streak_100_item');
    expect(fountain.toTown, isTrue);
  });

  test('grants use deterministic acquisition ids', () {
    final grants = evaluate(streakOf(7)).cast<ItemAcquired>();
    expect(grants.map((grant) => grant.acquisitionId),
        contains(streakMilestoneAcquisitionId('alex', 7, 'streak_7_item')));
    expect(grants.every((grant) => grant.source.name == 'milestone'), isTrue);
  });
}
