import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/reason_codes.dart';
import 'package:lootlog/game/ui/hall_voice.dart';

import 'hall_harness.dart';

void main() {
  final voice = diskVoice();

  test('every set the hall uses is present with 8+ non-blank lines', () {
    for (final name in HallVoice.setNames) {
      final lines = voice.sets[name];
      expect(lines, isNotNull, reason: name);
      expect(lines!.length, greaterThanOrEqualTo(8), reason: name);
      for (final l in lines) {
        expect(l.trim(), isNotEmpty, reason: name);
      }
    }
  });

  test('every rejection has friendly copy', () {
    for (final r in GameRejection.values) {
      expect(voice.rejections[r.name], isNotNull, reason: r.name);
    }
  });

  test('every reward reason code has a name', () {
    for (final code in [
      GameReasonCodes.dailyLog,
      GameReasonCodes.noSpendCheckIn,
      GameReasonCodes.extraLog,
      GameReasonCodes.timely,
      GameReasonCodes.weeklyCheckIn,
      GameReasonCodes.weeklyReconcile,
      GameReasonCodes.partyWeek,
      GameReasonCodes.streakToken,
      GameReasonCodes.caravan,
      GameReasonCodes.ritualSpoils,
      GameReasonCodes.ritualBonus,
      GameReasonCodes.monthGold,
      GameReasonCodes.vaultQuest,
      GameReasonCodes.vaultSavingsStreak,
    ]) {
      expect(voice.reasons[code], isNotNull, reason: code);
    }
  });

  test('the dungeon entrance sets are in the file, and built in when not', () {
    for (final name in HallVoice.fallbacks.keys) {
      expect(voice.sets[name], isNotEmpty, reason: name);
      expect(HallVoice.empty.line(name), HallVoice.fallbacks[name], reason: name);
    }
    expect(HallVoice.empty.line('dungeonCalloutButton'), isNotEmpty);
  });

  test('nothing shames, blames or punishes', () {
    const banned = [
      'fail',
      'shame',
      'guilt',
      'lazy',
      'bad ',
      'punish',
      'lost your',
      'you lose',
      'penalty',
      'inactive',
      'slacker',
      'irresponsible',
      'overspen',
    ];
    final all = [
      for (final s in voice.sets.values) ...s,
      ...voice.rejections.values,
      ...voice.reasons.values,
    ];
    for (final line in all) {
      for (final word in banned) {
        expect(line.toLowerCase(), isNot(contains(word)),
            reason: '"$line" contains "$word"');
      }
    }
  });

  test('picks are stable for a seed and fill placeholders', () {
    final a = voice.line('chestOpened', seed: 'evt-1', fill: {'chest': 'Wood chest'});
    final b = voice.line('chestOpened', seed: 'evt-1', fill: {'chest': 'Wood chest'});
    expect(a, b);
    expect(a, isNot(contains('{chest}')));
    expect(voice.line('no-such-set'), '');
    expect(HallVoice.empty.rejection(GameRejection.notEnoughGems), isNotEmpty);
  });
}
