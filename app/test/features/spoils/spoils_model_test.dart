import 'package:lootlog/features/spoils/spoils_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('previewDiscretionary', () {
    test('floors the tithe to the chest and sums exactly', () {
      final p = previewDiscretionary(1005, 10);
      expect(p.titheCents, 100);
      expect(p.vaultCents, 905);
      expect(p.titheCents + p.vaultCents, 1005);
    });
  });

  // Mirrors the reducer's category-match tithing so the sheet's live preview
  // always agrees with what gets appended.
  group('previewQuestAttack', () {
    test('matching main category is untithed full damage', () {
      final p = previewQuestAttack(
        10000,
        20,
        sliceMainCategoryId: 'entertainment',
        questMainCategoryId: 'entertainment',
      );
      expect(p.matched, isTrue);
      expect(p.damageCents, 10000);
      expect(p.titheCents, 0);
    });

    test('non-matching main category pays the source pool tithe', () {
      // Canonical: \$100 hygiene @50% attacking an entertainment quest.
      final p = previewQuestAttack(
        10000,
        50,
        sliceMainCategoryId: 'health',
        questMainCategoryId: 'entertainment',
      );
      expect(p.matched, isFalse);
      expect(p.titheCents, 5000);
      expect(p.damageCents, 5000);
    });

    test('a quest with no main category never matches', () {
      final p = previewQuestAttack(
        10000,
        30,
        sliceMainCategoryId: 'entertainment',
        questMainCategoryId: null,
      );
      expect(p.matched, isFalse);
      expect(p.titheCents, 3000);
      expect(p.damageCents, 7000);
    });

    test('the mismatch tithe floors to the chest and sums exactly', () {
      final p = previewQuestAttack(
        1005,
        10,
        sliceMainCategoryId: 'health',
        questMainCategoryId: 'entertainment',
      );
      expect(p.titheCents, 100);
      expect(p.damageCents, 905);
      expect(p.titheCents + p.damageCents, 1005);
    });
  });
}
