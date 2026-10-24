import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/ui/logged_voice.dart';

void main() {
  final shipped = LoggedVoice.parse(File(kPurchaseLoggedAsset).readAsStringSync());

  test('the shipped file has lines, none of them left with a placeholder', () {
    expect(shipped.lines, isNotEmpty);
    for (var seed = 0; seed < 40; seed++) {
      final line = shipped.line(seed: seed);
      expect(line, isNot(contains('{')));
      expect(line, isNot(contains('  ')));
      expect(line, isNotEmpty);
    }
  });

  test('unfilled placeholders drop cleanly; filled ones are kept', () {
    const voice = LoggedVoice(lines: ['Recorded {amount} in a blink.']);
    expect(voice.line(), 'Recorded in a blink.');
    expect(voice.line(fill: const {'amount': r'$4.50'}), r'Recorded $4.50 in a blink.');
  });

  test('picks are stable for a seed; an empty file falls back', () {
    expect(shipped.line(seed: 'day-1'), shipped.line(seed: 'day-1'));
    expect(LoggedVoice.empty.line(seed: 3), LoggedVoice.fallback);
  });
}
