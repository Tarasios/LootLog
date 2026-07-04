import 'package:duobudget/data/ocr/receipt_parse.dart';
import 'package:flutter_test/flutter_test.dart';

/// Splits a triple-quoted fixture into trimmed, non-empty-aware lines exactly as
/// a recognizer would hand them over (blank lines preserved for realism).
List<String> _lines(String text) => text.trim().split('\n');

void main() {
  group('candidateTotals — 8 fixture receipts', () {
    test('grocery with subtotal + tax + total picks the total', () {
      final scan = parseReceiptLines(_lines('''
SAVEMORE GROCERY
123 Main St
2026-03-15
Bread          3.99
Milk           4.50
Eggs           5.25
SUBTOTAL      13.74
TAX            0.96
TOTAL         14.70
VISA          14.70
'''));

      expect(scan.bestTotalCents, 1470);
      // Subtotal and tax are never offered.
      expect(scan.candidateTotals.map((c) => c.amountCents), isNot(contains(1374)));
      expect(scan.candidateTotals.map((c) => c.amountCents), isNot(contains(96)));
      expect(scan.candidateDate, DateTime(2026, 3, 15));
      expect(scan.merchantGuess, 'SAVEMORE GROCERY');
    });

    test('restaurant with tip picks the grand total, not the tip', () {
      final scan = parseReceiptLines(_lines('''
Trattoria Roma
Server: Mia
Pasta          18.00
Wine           12.00
Subtotal       30.00
Tax             2.40
Tip             6.48
Total          38.88
'''));

      expect(scan.bestTotalCents, 3888);
      expect(scan.candidateTotals.map((c) => c.amountCents), isNot(contains(648)));
      expect(scan.candidateTotals.map((c) => c.amountCents), isNot(contains(3000)));
      expect(scan.merchantGuess, 'Trattoria Roma');
    });

    test('gas station with no total keyword falls back to the sale amount', () {
      final scan = parseReceiptLines(_lines('''
PETRO GO #45
PUMP 3
UNLEADED
12.500 GAL @ 3.499
FUEL SALE     43.74
DEBIT         43.74
03/15/2026
'''));

      // Per-unit price and gallon count (3-decimal) are not mistaken for money.
      expect(scan.candidateTotals.map((c) => c.amountCents), isNot(contains(1250)));
      expect(scan.bestTotalCents, 4374);
      expect(scan.candidateDate, DateTime(2026, 3, 15));
      expect(scan.merchantGuess, 'PETRO GO #45');
    });

    test('pharmacy with "TOTAL DUE" outranks the subtotal', () {
      final scan = parseReceiptLines(_lines('''
HEALTHPLUS PHARMACY
Rx# 4482910
Ibuprofen 200mg     8.49
Vitamin D           11.29
Bandages            4.15
SUBTOTAL           23.93
HST                 3.11
TOTAL DUE          27.04
'''));

      expect(scan.bestTotalCents, 2704);
      // "amount due"/"total due" scores strictly higher than a bare "total".
      expect(scan.candidateTotals.first.score, greaterThan(200));
      expect(scan.merchantGuess, 'HEALTHPLUS PHARMACY');
    });

    test('faded/partial scan with garbled labels still ranks by magnitude', () {
      final scan = parseReceiptLines(_lines('''
CORNER  ARKET
Item          2.50
Item          6.99
????          9.49
'''));

      // No keyword survived; the largest plausible amount is the fallback.
      expect(scan.bestTotalCents, 949);
      expect(
        scan.candidateTotals.map((c) => c.amountCents).toList(),
        [949, 699, 250],
      );
      expect(scan.candidateDate, isNull);
      expect(scan.merchantGuess, contains('CORNER'));
    });

    test('cash tender exceeding total ignores cash and change', () {
      final scan = parseReceiptLines(_lines('''
QUICK STOP
Chips          2.49
Soda           1.99
TOTAL          4.48
CASH          20.00
CHANGE        15.52
'''));

      expect(scan.bestTotalCents, 448);
      final amounts = scan.candidateTotals.map((c) => c.amountCents);
      expect(amounts, isNot(contains(2000))); // cash
      expect(amounts, isNot(contains(1552))); // change
    });

    test('long multi-item receipt still finds the total', () {
      final scan = parseReceiptLines(_lines('''
MEGA MART SUPERSTORE
2026-07-04
Apples             3.20
Cereal             4.99
Chicken           12.49
Detergent          9.75
Coffee            11.20
Cheese             6.80
Yogurt             3.15
Bagels             2.99
Juice              4.49
Chocolate          2.25
SUBTOTAL          61.31
TAX                7.36
TOTAL             68.67
'''));

      expect(scan.bestTotalCents, 6867);
      expect(scan.candidateTotals.first.score, 200);
      expect(scan.candidateDate, DateTime(2026, 7, 4));
    });

    test('European 1.234,56 grouping is normalized, not misread', () {
      final scan = parseReceiptLines(_lines('''
BISTRO EUROPA
Menu du Jour
Plat            18,50
Dessert          6,00
TOTAL        1.234,56
'''));

      // 1.234,56 -> 123456 cents (dot groups thousands, comma is the decimal).
      expect(scan.bestTotalCents, 123456);
      final amounts = scan.candidateTotals.map((c) => c.amountCents);
      expect(amounts, contains(1850));
      expect(amounts, contains(600));
      // The misreads €1.23, €234, €1234 must never appear.
      expect(amounts, isNot(contains(123)));
      expect(amounts, isNot(contains(234)));
    });
  });

  group('candidateDate parsing', () {
    test('ISO yyyy-MM-dd', () {
      expect(parseReceiptLines(['Date 2026-03-15']).candidateDate,
          DateTime(2026, 3, 15));
    });

    test('North American MM/DD/YYYY is the default', () {
      expect(parseReceiptLines(['03/07/2026']).candidateDate,
          DateTime(2026, 3, 7));
    });

    test('unambiguous DD/MM/YYYY (day > 12) flips correctly', () {
      expect(parseReceiptLines(['15/03/2026']).candidateDate,
          DateTime(2026, 3, 15));
    });

    test('two-digit year is expanded to 2000s', () {
      expect(parseReceiptLines(['03/15/26']).candidateDate,
          DateTime(2026, 3, 15));
    });

    test('spelled-out month name', () {
      expect(parseReceiptLines(['Mar 15, 2026']).candidateDate,
          DateTime(2026, 3, 15));
      expect(parseReceiptLines(['15 March 2026']).candidateDate,
          DateTime(2026, 3, 15));
    });

    test('invalid date is rejected', () {
      expect(parseReceiptLines(['Feb 30, 2026']).candidateDate, isNull);
    });
  });

  group('merchantGuess', () {
    test('skips phone/address/amount lines for the store name', () {
      final scan = parseReceiptLines(_lines('''
604-555-0199
THE GOOD SHOP
1200 Broadway
Widget   5.00
'''));
      expect(scan.merchantGuess, 'THE GOOD SHOP');
    });

    test('null when there is no alphabetic line', () {
      expect(parseReceiptLines(['12.00', '3.50']).merchantGuess, isNull);
    });
  });

  group('empty / degenerate input', () {
    test('no lines yields an empty scan', () {
      final scan = parseReceiptLines(const []);
      expect(scan.candidateTotals, isEmpty);
      expect(scan.bestTotalCents, isNull);
      expect(scan.candidateDate, isNull);
      expect(scan.merchantGuess, isNull);
    });

    test('parseReceiptText splits on newlines', () {
      final scan = parseReceiptText('SHOP\nTOTAL 9.99');
      expect(scan.bestTotalCents, 999);
      expect(scan.merchantGuess, 'SHOP');
    });
  });
}
