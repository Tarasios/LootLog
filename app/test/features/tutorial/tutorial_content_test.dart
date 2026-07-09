import 'package:duobudget/features/tutorial/tutorial_content.dart';
import 'package:duobudget/ui/glossary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tutorialSteps', () {
    test('covers the six core flows in order', () {
      final steps = tutorialSteps(isAdventure: false);
      expect(steps, hasLength(6));
      // Every step has a title and a body.
      for (final s in steps) {
        expect(s.title.trim(), isNotEmpty);
        expect(s.body.trim(), isNotEmpty);
      }
    });

    test('Classic wording uses no banned flavor words', () {
      final steps = tutorialSteps(isAdventure: false);
      for (final s in steps) {
        final text = '${s.title} ${s.body}'.toLowerCase();
        for (final banned in Glossary.bannedInClassic) {
          expect(text.contains(banned), isFalse,
              reason: 'Tutorial step "${s.title}" leaks banned word "$banned"');
        }
      }
    });

    test('Adventure wording keeps the flavor terms', () {
      final steps = tutorialSteps(isAdventure: true);
      final joined =
          steps.map((s) => '${s.title} ${s.body}').join(' ').toLowerCase();
      // The month-close step should carry the flavor title in Adventure.
      expect(joined, contains('dividing the spoils'));
      expect(joined, contains('war chest'));
    });

    test('touches each documented topic', () {
      final joined = tutorialSteps(isAdventure: false)
          .map((s) => '${s.title} ${s.body}')
          .join(' ')
          .toLowerCase();
      expect(joined, contains('purchase'));
      expect(joined, contains('budget'));
      expect(joined, contains('savings goal'));
      expect(joined, contains('withdrawal'));
      expect(joined, contains('sync'));
    });
  });
}
