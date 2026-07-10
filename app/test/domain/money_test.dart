import 'package:lootlog/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money.parse', () {
    test('parses whole dollars', () {
      expect(Money.parse('12').cents, 1200);
    });

    test('parses dollars and cents', () {
      expect(Money.parse('12.34').cents, 1234);
    });

    test('parses a single fractional digit as tenths', () {
      expect(Money.parse('5.5').cents, 550);
    });

    test('tolerates currency symbol, grouping and whitespace', () {
      expect(Money.parse(r'  $1,234.50 ').cents, 123450);
    });

    test('parses negative amounts', () {
      expect(Money.parse('-5.5').cents, -550);
    });

    test('parses accounting-style parentheses as negative', () {
      expect(Money.parse('(2.00)').cents, -200);
    });

    test('parses a bare decimal', () {
      expect(Money.parse('.75').cents, 75);
    });

    test('rejects three fractional digits', () {
      expect(() => Money.parse('1.234'), throwsFormatException);
    });

    test('rejects garbage', () {
      expect(() => Money.parse('abc'), throwsFormatException);
      expect(() => Money.parse(''), throwsFormatException);
      expect(() => Money.parse('1.2.3'), throwsFormatException);
    });
  });

  group('Money.format', () {
    test('formats cents with two decimals', () {
      expect(const Money(1234).format(), '12.34');
      expect(const Money(5).format(), '0.05');
      expect(const Money(100).format(), '1.00');
    });

    test('formats negatives', () {
      expect(const Money(-550).format(), '-5.50');
      expect(const Money(-5).format(), '-0.05');
    });

    test('round-trips through parse', () {
      for (final c in [0, 1, 99, 100, 123450, -550, -1]) {
        expect(Money.parse(Money(c).format()).cents, c);
      }
    });
  });

  group('arithmetic', () {
    test('adds and subtracts', () {
      expect((const Money(1200) + const Money(34)).cents, 1234);
      expect((const Money(1234) - const Money(34)).cents, 1200);
      expect((-const Money(50)).cents, -50);
    });

    test('compares', () {
      expect(const Money(100) < const Money(200), isTrue);
      expect(const Money(200) >= const Money(200), isTrue);
      expect(const Money(-1).isNegative, isTrue);
      expect(const Money(0).isZero, isTrue);
    });
  });

  group('split (50/50, odd cent to designated)', () {
    test('even amount splits evenly', () {
      final s = const Money(100).split();
      expect(s.designatedCents, 50);
      expect(s.otherCents, 50);
    });

    test('odd amount gives the extra cent to the designated party', () {
      final s = const Money(101).split();
      expect(s.designatedCents, 51);
      expect(s.otherCents, 50);
      expect(s.designatedCents + s.otherCents, 101);
    });

    test('one cent goes entirely to the designated party', () {
      final s = Money.splitCents(1);
      expect(s.designatedCents, 1);
      expect(s.otherCents, 0);
    });
  });

  group('tithe (percentage, floor rounding, exact remainder)', () {
    test('floors the tithe and gives the remainder to the user', () {
      // 10% of 1005 = 100.5 -> floor 100 to chest, 905 to user.
      final t = Money.titheCents(1005, 10);
      expect(t.titheCents, 100);
      expect(t.remainderCents, 905);
      expect(t.titheCents + t.remainderCents, 1005);
    });

    test('0% and 100% edge cases', () {
      expect(Money.titheCents(999, 0), const Tithe(titheCents: 0, remainderCents: 999));
      expect(Money.titheCents(999, 100), const Tithe(titheCents: 999, remainderCents: 0));
    });

    test('sum is always exact for many values', () {
      for (var amount = 0; amount < 1000; amount++) {
        for (final pct in [1, 7, 10, 33, 50, 99]) {
          final t = Money.titheCents(amount, pct);
          expect(t.titheCents + t.remainderCents, amount);
          expect(t.titheCents, lessThanOrEqualTo(amount));
        }
      }
    });

    test('rejects out-of-range percentages', () {
      expect(() => Money.titheCents(100, -1), throwsArgumentError);
      expect(() => Money.titheCents(100, 101), throwsArgumentError);
    });
  });
}
