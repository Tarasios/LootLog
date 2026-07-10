import 'dart:io';
import 'dart:math';

import 'package:lootlog/game/narrative.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the shipped asset files off disk (tests run with the package root as
/// cwd) so we validate the real content writers will edit, not a fixture.
Narrative _loadFromDisk() {
  String read(String path) => File(path).readAsStringSync();
  return parseNarrative(
    purchaseLoggedJson: read(NarrativeAssets.purchaseLogged),
    streakCelebrationsJson: read(NarrativeAssets.streakCelebrations),
    ritualCelebrationsJson: read(NarrativeAssets.ritualCelebrations),
    overspendSupportJson: read(NarrativeAssets.overspendSupport),
  );
}

void main() {
  group('narrative assets', () {
    late Narrative n;
    setUpAll(() => n = _loadFromDisk());

    test('every bucket has lines and none are blank', () {
      expect(n.purchaseLogged, isNotEmpty);
      expect(n.ritualCelebrations, isNotEmpty);
      expect(n.overspendSupport, isNotEmpty);
      expect(n.streakTiers, isNotEmpty);
      final all = [
        ...n.purchaseLogged,
        ...n.ritualCelebrations,
        ...n.overspendSupport,
        for (final t in n.streakTiers) ...t.lines,
      ];
      for (final line in all) {
        expect(line.trim(), isNotEmpty);
      }
    });

    test('streak tiers are sorted ascending and each carries lines', () {
      for (var i = 1; i < n.streakTiers.length; i++) {
        expect(n.streakTiers[i].minDays,
            greaterThan(n.streakTiers[i - 1].minDays));
      }
      for (final t in n.streakTiers) {
        expect(t.lines, isNotEmpty);
      }
    });

    test('overspend lines never shame', () {
      const shaming = [
        'failed',
        'failure',
        'bad',
        'shame',
        'guilt',
        'irresponsible',
        'wasted',
        'should have',
        'stupid',
        'lazy',
        'never',
      ];
      for (final line in n.overspendSupport) {
        final lower = line.toLowerCase();
        for (final word in shaming) {
          expect(lower.contains(word), isFalse,
              reason: 'Overspend line "$line" uses shaming word "$word"');
        }
      }
    });

    test('purchaseAck fills or drops placeholders cleanly', () {
      final rng = Random(1);
      final withData =
          n.purchaseAck(amount: r'$12.34', merchant: 'Cafe', rng: rng);
      expect(withData, isNot(contains('{amount}')));
      expect(withData, isNot(contains('{merchant}')));

      final withNothing = n.purchaseAck(rng: Random(2));
      expect(withNothing, isNot(contains('{')));
      expect(withNothing.trim(), isNotEmpty);
    });

    test('streakLine picks the highest applicable tier and fills {n}', () {
      final min = n.streakTiers.first.minDays;
      expect(n.streakLine(min - 1), isNull,
          reason: 'below the first tier there is nothing to celebrate');

      final line = n.streakLine(min, rng: Random(3));
      expect(line, isNotNull);
      expect(line, isNot(contains('{n}')));

      // A very long streak lands on the top tier.
      final top = n.streakTiers.last;
      final topLine = n.streakLine(top.minDays + 500, rng: Random(4))!;
      expect(top.lines.map((l) => l.replaceAll('{n}', '${top.minDays + 500}')),
          contains(topLine));
    });
  });
}
