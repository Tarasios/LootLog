import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/pools.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/spoils/spoils_model.dart';

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

  group('savings rules previews', () {
    test('saving allowance pays the carry tax once', () {
      final p = previewMove(const TaxedBalance(5000), 5000, 10);
      expect(p.keepCents, 4500);
      expect(p.taxCents, 500);
    });

    test(
      'moving already-taxed savings to general pays only the difference',
      () {
        final p = previewMove(const TaxedBalance(4500, 500), 4500, 20);
        expect(p.keepCents, 4000);
        expect(p.taxCents, 500);
      },
    );

    test('destination rates follow the savings rules', () {
      int rate(
        LeftoverDestination d, {
        String? destCat,
        bool provisions = false,
      }) => savingsRateFor(
        d,
        carryPct: 10,
        generalPct: 20,
        sliceMainCategoryId: 'fun',
        destMainCategoryId: destCat,
        provisions: provisions,
      );
      expect(rate(const CarryInSlice()), 10);
      expect(rate(const Discretionary()), 20);
      expect(rate(const QuestDestination('q'), destCat: 'fun'), 0);
      expect(rate(const QuestDestination('q'), destCat: 'misc'), 20);
      expect(rate(const OverbudgetPayment('s'), destCat: 'misc'), 20);
      expect(rate(const OverbudgetPayment('s'), provisions: true), 0);
    });

    test('an overbudget payment never takes more than it needs', () {
      final p = previewSavingsOverbudget(
        const TaxedBalance(5000),
        5000,
        ratePct: 0,
        generalPct: 20,
        outstandingCents: 3000,
      );
      expect(p.payCents, 3000);
      expect(p.titheCents, 0);
      // The 2000 excess tops up to the general rate on its way.
      expect(p.toVaultCents, 1600);
      expect(p.excessTitheCents, 400);
    });
  });

  group('ritual under the savings rules', () {
    var n = 0;
    String id() => 'sr${(n++).toString().padLeft(4, '0')}';
    DateTime day(int m, int d) => DateTime.utc(2026, m, d, 18);

    test('leftovers carry the rates and the savings that can move', () {
      final events = <Event>[
        SettingChanged(
          eventId: id(),
          deviceId: 'd',
          userId: 'u1',
          occurredAt: day(6, 1),
          createdAt: day(6, 1),
          key: 'savingsRules',
          value: {'fromMonth': '2026-07', 'generalTithePct': 20},
        ),
        BudgetSliceSet(
          eventId: id(),
          deviceId: 'd',
          userId: 'u1',
          occurredAt: day(7, 1),
          createdAt: day(7, 1),
          sliceId: 'clothes',
          name: 'Clothing',
          ownership: const PersonalSlice('u1'),
          limitCents: 5000,
          poolTithePct: 10,
          defaultLeftoverPolicy: const CarryInSlice(),
          taxDeductibleByDefault: false,
        ),
        LeftoverAllocated(
          eventId: id(),
          deviceId: 'd',
          userId: 'u1',
          occurredAt: day(8, 1),
          createdAt: day(8, 1),
          forUserId: 'u1',
          month: const Month(2026, 7),
          sliceId: 'clothes',
          allocations: const [
            Allocation(destination: CarryInSlice(), amountCents: 5000),
          ],
        ),
      ];
      final asOf = day(9, 3); // inside August's month-end window
      final ritual = buildSpoilsRitual(
        reduce(events, asOf: asOf),
        meUserId: 'u1',
        userNames: const {'u1': 'Alex'},
        asOf: asOf,
      )!;
      final s = ritual.sliceLeftovers.single;
      expect(s.leftoverCents, 5000);
      expect(s.generalRatePct, 20);
      expect(s.savings, const TaxedBalance(4500, 500));
    });
  });
}
