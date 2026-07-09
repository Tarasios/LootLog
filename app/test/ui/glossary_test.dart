import 'package:duobudget/ui/glossary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Glossary', () {
    test('Classic labels never use a banned flavor word', () {
      for (final term in Glossary.all) {
        final classic = term.classic.toLowerCase();
        for (final banned in Glossary.bannedInClassic) {
          expect(
            classic.contains(banned),
            isFalse,
            reason: 'Classic label "${term.classic}" (${term.internal}) '
                'contains the banned word "$banned"',
          );
        }
      }
    });

    test('every term carries a non-empty plain helper sentence', () {
      for (final term in Glossary.all) {
        expect(term.classic, isNotEmpty);
        expect(term.adventure, isNotEmpty);
        expect(term.internal, isNotEmpty);
        expect(term.helper.trim(), isNotEmpty);
        // The helper is the plain-meaning tooltip, so it must itself stay plain.
        final helper = term.helper.toLowerCase();
        for (final banned in Glossary.bannedInClassic) {
          expect(helper.contains(banned), isFalse,
              reason: 'Helper for ${term.internal} leaks "$banned"');
        }
      }
    });

    test('label() picks the register for the active skin', () {
      expect(Glossary.poolTithe.label(isAdventure: false), 'shared-savings cut');
      expect(Glossary.poolTithe.label(isAdventure: true), 'tithe');
      expect(
        Glossary.leftoverAllocated.label(isAdventure: false),
        'Divide monthly leftovers',
      );
      expect(
        Glossary.leftoverAllocated.label(isAdventure: true),
        'Dividing the spoils',
      );
    });

    test('the task-mandated mappings are present verbatim', () {
      expect(Glossary.leftoverAllocated.classic, 'Divide monthly leftovers');
      expect(Glossary.leftoverAllocated.adventure, 'Dividing the spoils');
      expect(Glossary.poolTithe.classic, 'shared-savings cut');
      expect(Glossary.dissolutionTithe.classic, 'cancellation fee');
      expect(Glossary.gracePeriodLabel(7, isAdventure: false),
          'Auto-divide leftovers after 7 days');
      expect(Glossary.gracePeriodLabel(1, isAdventure: false),
          'Auto-divide leftovers after 1 day');
    });

    test('gracePeriodLabel keeps flavor out of Classic', () {
      final classic = Glossary.gracePeriodLabel(3, isAdventure: false);
      expect(classic.toLowerCase(), isNot(contains('grace period')));
      expect(Glossary.gracePeriodLabel(3, isAdventure: true),
          contains('Grace period'));
    });

    test('sharedSavingsCut stays plain in Classic, flavored in Adventure', () {
      final classic = Glossary.sharedSavingsCut(r'$5.00', 50, isAdventure: false);
      expect(classic.toLowerCase(), isNot(contains('tithe')));
      expect(classic.toLowerCase(), isNot(contains('war chest')));
      expect(Glossary.sharedSavingsCut(r'$5.00', 50, isAdventure: true),
          contains('war chest'));
    });

    test('internal names are unique', () {
      final names = Glossary.all.map((t) => t.internal).toList();
      expect(names.toSet().length, names.length);
    });
  });
}
