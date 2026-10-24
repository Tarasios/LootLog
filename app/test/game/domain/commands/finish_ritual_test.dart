import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/reason_codes.dart';

import '../game_fixtures.dart';

final DateTime ritualDay = DateTime.utc(2026, 10, 3);
const Month september = Month(2026, 9);

GameEventStamp testStamp() {
  var eventNumber = 0;
  return GameEventStamp(
    deviceId: 'dev-test',
    newEventId: () => 'z${(eventNumber++).toString().padLeft(5, '0')}',
  );
}

GameCommands commandsFor(GameState state, {String actor = 'alex'}) =>
    GameCommands(state: state, clock: FixedClock(ritualDay), actorId: actor, stamp: testStamp());

void main() {
  test('finishing the ritual grants the spoils chest once, with a streak bonus', () {
    final result = commandsFor(GameState.initial()).finishMonthRitual(september, onTimeRitualMonths: 2);
    final chest = result.events.whereType<ChestGranted>().single;
    expect(chest.chestId, spoilsChestId('alex', september));
    expect(chest.chestType, ChestType.spoils);
    expect(chest.reasonCode, GameReasonCodes.ritualSpoils);
    final bonus = result.events.whereType<RewardGranted>().single;
    expect(bonus.gems, 2 * Balance.ritualBonusGemsPerOnTimeMonth);
    expect(bonus.rewardId, 'ritual.bonus:alex:2026-09');
    expect(bonus.kind, 'gems');
    expect(bonus.reasonCode, GameReasonCodes.ritualBonus);

    var state = GameState.initial();
    for (final event in result.events) {
      state = state.apply(event);
    }
    final again = commandsFor(state).finishMonthRitual(september, onTimeRitualMonths: 2);
    expect(again.rejection, GameRejection.ritualAlreadyFinished);
  });

  test('no on-time history and no gear: the chest alone', () {
    final result = commandsFor(GameState.initial()).finishMonthRitual(september, onTimeRitualMonths: 0);
    expect(result.events.single, isA<ChestGranted>());
  });

  test('the on-time months are capped and hero gear adds its power', () {
    final geared = projectGameState([
      gearUpgraded('g1', when: at(0), hero: 'alex', actor: 'alex', tier: 1),
      gearUpgraded('g2', when: at(1), hero: 'alex', actor: 'alex', tier: 2),
    ]);
    final power = geared.person('alex').hero.power;
    expect(power, greaterThan(0));
    final result = commandsFor(geared).finishMonthRitual(september, onTimeRitualMonths: 40);
    final bonus = result.events.whereType<RewardGranted>().single;
    expect(
      bonus.gems,
      Balance.ritualBonusMaxOnTimeMonths * Balance.ritualBonusGemsPerOnTimeMonth +
          power * Balance.ritualBonusGemsPerHeroPower,
    );
  });

  test('a chest already granted by the old boss fight counts as finished', () {
    final state = projectGameState([
      chestGranted('c1', spoilsChestId('alex', september), ChestType.spoils, when: at(0), actor: 'alex'),
    ]);
    expect(
      commandsFor(state).finishMonthRitual(september, onTimeRitualMonths: 3).rejection,
      GameRejection.ritualAlreadyFinished,
    );
  });
}
