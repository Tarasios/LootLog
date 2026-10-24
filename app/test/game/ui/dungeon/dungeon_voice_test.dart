import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_voice.dart';

void main() {
  final voice = DungeonVoice.parse(File(kDungeonLinesAsset).readAsStringSync());

  test('the shipped file carries every set with non-blank lines', () {
    for (final name in DungeonVoice.fallbacks.keys) {
      final lines = voice.sets[name];
      expect(lines, isNotNull, reason: name);
      expect(lines, isNotEmpty, reason: name);
      for (final line in lines!) {
        expect(line.trim(), isNotEmpty, reason: name);
      }
    }
  });

  test('nothing shames, blames or punishes', () {
    const banned = ['fail', 'shame', 'guilt', 'lazy', 'bad ', 'punish', 'penalty', 'you lose', 'overspen'];
    for (final line in [
      for (final lines in voice.sets.values) ...lines,
      ...DungeonVoice.fallbacks.values,
    ]) {
      for (final word in banned) {
        expect(line.toLowerCase(), isNot(contains(word)), reason: '"$line" contains "$word"');
      }
    }
  });

  test('picks are stable for a seed and fill placeholders', () {
    final first = voice.line('hitGoal', seed: 'fun:2026-09', fill: const {'amount': r'$150.00', 'target': 'canoe'});
    expect(voice.line('hitGoal', seed: 'fun:2026-09', fill: const {'amount': r'$150.00', 'target': 'canoe'}), first);
    expect(first, contains(r'$150.00'));
    expect(first, contains('canoe'));
    expect(first, isNot(contains('{')));
  });

  test('a missing set falls back to the built-in line', () {
    expect(DungeonVoice.empty.line('victory'), DungeonVoice.fallbacks['victory']);
  });
}
