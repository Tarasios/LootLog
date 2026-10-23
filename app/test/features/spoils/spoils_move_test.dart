import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/pools.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/spoils/spoils_model.dart';
import 'package:lootlog/features/spoils/spoils_move.dart';

const consoleQuest = QuestOption(
  questId: 'console',
  name: 'Console',
  balanceCents: 0,
  targetCents: 50000,
  totalContributedCents: 0,
  mainCategoryId: 'entertainment',
);

SliceLeftover legacyLeftover({
  required int leftoverCents,
  required int tithePct,
  required String mainCategoryId,
  List<OverbudgetOption> debts = const [],
  LeftoverDestination defaultPolicy = const Discretionary(),
  int? generalRatePct,
}) =>
    SliceLeftover(
      sliceId: 'slice-$mainCategoryId',
      name: mainCategoryId,
      leftoverCents: leftoverCents,
      poolTithePct: tithePct,
      defaultPolicy: defaultPolicy,
      questOptions: const [consoleQuest],
      overbudgetOptions: debts,
      priority: SlicePriority.important,
      mainCategoryId: mainCategoryId,
      generalRatePct: generalRatePct,
      savings: TaxedBalance.zero,
    );

void main() {
  group('legacy rules (canonical CLAUDE.md examples)', () {
    test(r'$100 hygiene @50% attacking an Entertainment quest: $50 lands, $50 tax', () {
      final leftover = legacyLeftover(leftoverCents: 10000, tithePct: 50, mainCategoryId: 'hygiene');
      final preview = previewSpoilsChoice(leftover, const SpoilsChoice(SpoilsMove.goal, questId: 'console'));
      expect(preview.landsCents, 5000);
      expect(preview.taxCents, 5000);
      expect(preview.matched, isFalse);
      expect(preview.targetRemainingAfterCents, 45000);
    });

    test(r'$100 entertainment @20% on the same quest: full $100, no tax', () {
      final leftover =
          legacyLeftover(leftoverCents: 10000, tithePct: 20, mainCategoryId: 'entertainment');
      final preview = previewSpoilsChoice(leftover, const SpoilsChoice(SpoilsMove.goal, questId: 'console'));
      expect(preview.landsCents, 10000);
      expect(preview.taxCents, 0);
      expect(preview.matched, isTrue);
    });

    test(r'$40 debt, $50 non-matching leftover @10%: $40 pays, $5 tax, $5 to personal', () {
      final leftover = legacyLeftover(
        leftoverCents: 5000,
        tithePct: 10,
        mainCategoryId: 'food',
        debts: const [
          OverbudgetOption(
              sliceId: 'fun', name: 'Fun', outstandingCents: 4000, provisions: false, mainCategoryId: 'entertainment'),
        ],
      );
      final preview =
          previewSpoilsChoice(leftover, const SpoilsChoice(SpoilsMove.debt, overbudgetSliceId: 'fun'));
      expect(preview.landsCents, 4000);
      expect(preview.taxCents, 500);
      expect(preview.toPersonalCents, 500);
      expect(preview.completesTarget, isTrue);
    });

    test('bank tithes at the category rate; carry is whole', () {
      final leftover = legacyLeftover(leftoverCents: 5000, tithePct: 10, mainCategoryId: 'food');
      final bank = previewSpoilsChoice(leftover, const SpoilsChoice(SpoilsMove.bank));
      expect(bank.landsCents, 4500);
      expect(bank.taxCents, 500);
      final carry = previewSpoilsChoice(leftover, const SpoilsChoice(SpoilsMove.carry));
      expect(carry.landsCents, 5000);
      expect(carry.taxCents, 0);
    });

    test('a goal with no matching quest previews as banking', () {
      final leftover = legacyLeftover(leftoverCents: 5000, tithePct: 10, mainCategoryId: 'food');
      final preview = previewSpoilsChoice(leftover, const SpoilsChoice(SpoilsMove.goal));
      expect(preview.landsCents, 4500);
      expect(preview.taxCents, 500);
      expect(preview.targetRemainingAfterCents, isNull);
    });
  });

  group('savings rules', () {
    // $50 leftover, 10% carry tax, 20% general rate.
    final leftover = legacyLeftover(
        leftoverCents: 5000, tithePct: 10, mainCategoryId: 'food', generalRatePct: 20);

    test('carry pays the category carry tax', () {
      final preview = previewSpoilsChoice(leftover, const SpoilsChoice(SpoilsMove.carry));
      expect(preview.landsCents, 4500);
      expect(preview.taxCents, 500);
    });

    test('bank pays the general rate', () {
      final preview = previewSpoilsChoice(leftover, const SpoilsChoice(SpoilsMove.bank));
      expect(preview.landsCents, 4000);
      expect(preview.taxCents, 1000);
    });

    test('a non-matching goal pays the general rate; a matching one is untaxed', () {
      final nonMatching = previewSpoilsChoice(
          leftover, const SpoilsChoice(SpoilsMove.goal, questId: 'console'));
      expect(nonMatching.landsCents, 4000);
      expect(nonMatching.taxCents, 1000);
      expect(nonMatching.matched, isFalse);
      expect(nonMatching.targetRemainingAfterCents, 46000);

      final matching = previewSpoilsChoice(
        legacyLeftover(
            leftoverCents: 5000, tithePct: 10, mainCategoryId: 'entertainment', generalRatePct: 20),
        const SpoilsChoice(SpoilsMove.goal, questId: 'console'),
      );
      expect(matching.landsCents, 5000);
      expect(matching.taxCents, 0);
      expect(matching.matched, isTrue);
    });

    test('a zero general rate leaves a non-matching goal untaxed but still not matched', () {
      final preview = previewSpoilsChoice(
        legacyLeftover(leftoverCents: 5000, tithePct: 10, mainCategoryId: 'food', generalRatePct: 0),
        const SpoilsChoice(SpoilsMove.goal, questId: 'console'),
      );
      expect(preview.taxCents, 0);
      expect(preview.matched, isFalse, reason: 'matching is about categories, not the rate');
    });

    test('a provisions debt is paid untaxed', () {
      final withProvisions = legacyLeftover(
        leftoverCents: 5000,
        tithePct: 10,
        mainCategoryId: 'food',
        generalRatePct: 20,
        debts: const [
          OverbudgetOption(
              sliceId: 'provisions:rent',
              name: 'Rent top-up',
              outstandingCents: 3000,
              provisions: true),
        ],
      );
      final preview = previewSpoilsChoice(
          withProvisions, const SpoilsChoice(SpoilsMove.debt, overbudgetSliceId: 'provisions:rent'));
      expect(preview.landsCents, 3000);
      expect(preview.completesTarget, isTrue);
      expect(preview.targetRemainingAfterCents, 0);
    });
  });

  group('allocationsForChoice', () {
    final leftover = legacyLeftover(leftoverCents: 10000, tithePct: 20, mainCategoryId: 'entertainment');

    test('goal sends the whole leftover to the quest', () {
      final allocations = allocationsForChoice(leftover, const SpoilsChoice(SpoilsMove.goal, questId: 'console'));
      expect(allocations.single.destination, const QuestDestination('console'));
      expect(allocations.single.amountCents, 10000);
    });

    test('a goal with no quest falls back to banking', () {
      final allocations = allocationsForChoice(leftover, const SpoilsChoice(SpoilsMove.goal));
      expect(allocations.single.destination, const Discretionary());
    });

    test('carry and bank', () {
      expect(allocationsForChoice(leftover, const SpoilsChoice(SpoilsMove.carry)).single.destination,
          const CarryInSlice());
      expect(allocationsForChoice(leftover, const SpoilsChoice(SpoilsMove.bank)).single.destination,
          const Discretionary());
    });

    test('debt sends the whole leftover as one payment; no debt banks', () {
      final indebted = legacyLeftover(
        leftoverCents: 5000,
        tithePct: 10,
        mainCategoryId: 'food',
        debts: const [
          OverbudgetOption(sliceId: 'fun', name: 'Fun', outstandingCents: 4000),
        ],
      );
      final allocations =
          allocationsForChoice(indebted, const SpoilsChoice(SpoilsMove.debt, overbudgetSliceId: 'fun'));
      expect(allocations.single.destination, const OverbudgetPayment('fun'));
      expect(allocations.single.amountCents, 5000);
      expect(allocationsForChoice(leftover, const SpoilsChoice(SpoilsMove.debt)).single.destination,
          const Discretionary());
    });

    test('allocations always sum to the leftover', () {
      for (final move in SpoilsMove.values) {
        final allocations = allocationsForChoice(leftover, SpoilsChoice(move, questId: 'console'));
        expect(allocations.fold<int>(0, (sum, allocation) => sum + allocation.amountCents), 10000);
      }
    });
  });

  group('defaultSpoilsChoice', () {
    test('pre-selects an outstanding debt', () {
      final withDebt = legacyLeftover(
        leftoverCents: 5000,
        tithePct: 10,
        mainCategoryId: 'food',
        debts: const [
          OverbudgetOption(sliceId: 'fun', name: 'Fun', outstandingCents: 4000, provisions: false, mainCategoryId: null),
        ],
      );
      final choice = defaultSpoilsChoice(withDebt);
      expect(choice.move, SpoilsMove.debt);
      expect(choice.overbudgetSliceId, 'fun');
    });

    test('otherwise follows the category default policy', () {
      SpoilsChoice choiceFor(LeftoverDestination policy) => defaultSpoilsChoice(
          legacyLeftover(leftoverCents: 100, tithePct: 10, mainCategoryId: 'food', defaultPolicy: policy));
      expect(choiceFor(const CarryInSlice()).move, SpoilsMove.carry);
      expect(choiceFor(const Discretionary()).move, SpoilsMove.bank);
      final goal = choiceFor(const QuestDestination('console'));
      expect(goal.move, SpoilsMove.goal);
      expect(goal.questId, 'console');
    });
  });
}
