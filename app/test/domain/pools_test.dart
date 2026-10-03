import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/pools.dart';

void main() {
  group('moveTaxed', () {
    test('fresh money pays the full destination rate', () {
      final r = moveTaxed(const TaxedBalance(5000), 5000, 10);
      expect(r.topUpCents, 500);
      expect(r.delivered, const TaxedBalance(4500, 500));
      expect(r.remaining, TaxedBalance.zero);
    });

    test('already-taxed money only pays the difference', () {
      // $45 of Clothing savings that paid $5 (10%) moves to general at 20%.
      final r = moveTaxed(const TaxedBalance(4500, 500), 4500, 20);
      expect(r.topUpCents, 500);
      expect(r.delivered.balanceCents, 4000);
      expect(r.delivered.taxPaidCents, 1000);
    });

    test('moving to a lower rate costs nothing and refunds nothing', () {
      final r = moveTaxed(const TaxedBalance(4500, 500), 4500, 0);
      expect(r.topUpCents, 0);
      expect(r.delivered, const TaxedBalance(4500, 500));
    });

    test('a partial move takes a proportional share of tax paid', () {
      final r = moveTaxed(const TaxedBalance(9000, 1000), 4500, 20);
      expect(r.remaining, const TaxedBalance(4500, 500));
      expect(r.delivered.balanceCents + r.topUpCents, 4500);
    });

    test('every move sums exactly under floor rounding', () {
      for (final amount in [1, 3, 7, 99, 101, 12345]) {
        for (final rate in [0, 5, 10, 20, 33, 100]) {
          final r = moveTaxed(
            TaxedBalance(amount * 2, amount ~/ 3),
            amount,
            rate,
          );
          expect(
            r.delivered.balanceCents + r.topUpCents,
            amount,
            reason: 'amount $amount rate $rate',
          );
          expect(r.remaining.balanceCents, amount * 2 - amount);
        }
      }
    });

    test('zero amount is a no-op', () {
      final r = moveTaxed(const TaxedBalance(100, 10), 0, 20);
      expect(r.delivered, TaxedBalance.zero);
      expect(r.remaining, const TaxedBalance(100, 10));
      expect(r.topUpCents, 0);
    });
  });

  group('spendFrom', () {
    test('spending removes a proportional share of tax paid', () {
      expect(
        spendFrom(const TaxedBalance(9000, 1000), 4500),
        const TaxedBalance(4500, 500),
      );
    });
    test('spending everything empties the balance', () {
      expect(
        spendFrom(const TaxedBalance(9000, 1000), 9000),
        TaxedBalance.zero,
      );
    });
  });

  group('grossToDeliver', () {
    test('finds the smallest amount whose delivery covers the target', () {
      // Fresh money at 10%: delivering 4000 needs 4445 (4445 − 444 = 4001).
      final x = grossToDeliver(const TaxedBalance(10000), 4000, 10);
      expect(
        moveTaxed(const TaxedBalance(10000), x, 10).delivered.balanceCents,
        greaterThanOrEqualTo(4000),
      );
      expect(
        moveTaxed(const TaxedBalance(10000), x - 1, 10).delivered.balanceCents,
        lessThan(4000),
      );
    });
    test('caps at the whole balance when the target is unreachable', () {
      expect(grossToDeliver(const TaxedBalance(1000), 5000, 10), 1000);
    });
  });

  group('advanceTrimSchedule', () {
    test('splits evenly with remainder cents in the first month', () {
      expect(advanceTrimSchedule(1000, 3), [334, 333, 333]);
      expect(advanceTrimSchedule(5000, 1), [5000]);
    });
  });
}
