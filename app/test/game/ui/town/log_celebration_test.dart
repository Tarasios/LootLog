import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/reason_codes.dart';
import 'package:lootlog/game/ui/town/log_celebration.dart';

import '../hall_harness.dart';

void main() {
  final when = before(const Duration(hours: 1));

  test('sums the gems of logging rewards that are new for the person', () {
    final previous = projectGameState(const []);
    final next = projectGameState([
      granted('a1', when: when, rewardId: 'log.daily:$robin:d0', gems: 5, reasonCode: GameReasonCodes.dailyLog),
      granted('a2', when: when, rewardId: 'log.extra:$robin:d0:1', gems: 1, reasonCode: GameReasonCodes.extraLog),
      granted('a3', when: when, rewardId: 'log.timely:$robin:d0:1', gems: 1, reasonCode: GameReasonCodes.timely),
    ]);
    expect(newLoggingGems(previous, next, robin), 7);
  });

  test('a no-spend check-in counts; other rewards and other people do not', () {
    final previous = projectGameState(const []);
    final next = projectGameState([
      granted('a1', when: when, rewardId: 'checkin:$robin:d0', gems: 5, reasonCode: GameReasonCodes.noSpendCheckIn),
      granted('a2', when: when, rewardId: 'vault:$robin:q1', gems: 9, reasonCode: GameReasonCodes.vaultQuest),
      granted('a3', when: when, actor: sam, rewardId: 'log.daily:$sam:d0', gems: 5, reasonCode: GameReasonCodes.dailyLog),
    ]);
    expect(newLoggingGems(previous, next, robin), 5);
  });

  test('rewards already there, or claimed since, are not new', () {
    final events = [
      granted('a1', when: when, rewardId: 'log.daily:$robin:d0', gems: 5, reasonCode: GameReasonCodes.dailyLog),
    ];
    final previous = projectGameState(events);
    final claimedAfter = projectGameState([...events, claimed('a2', 'log.daily:$robin:d0', when: when)]);
    expect(newLoggingGems(previous, previous, robin), 0);
    expect(newLoggingGems(previous, claimedAfter, robin), 0);
  });
}
