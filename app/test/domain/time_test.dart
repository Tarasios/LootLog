import 'package:duobudget/domain/time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Month', () {
    test('parses and formats keys', () {
      expect(Month.parse('2026-03').toKey(), '2026-03');
      expect(const Month(2026, 3).toKey(), '2026-03');
    });

    test('next / prev roll over years', () {
      expect(const Month(2026, 12).next(), const Month(2027, 1));
      expect(const Month(2026, 1).prev(), const Month(2025, 12));
    });

    test('orders correctly', () {
      expect(const Month(2026, 1) < const Month(2026, 2), isTrue);
      expect(const Month(2025, 12) < const Month(2026, 1), isTrue);
      expect(const Month(2026, 5) >= const Month(2026, 5), isTrue);
    });
  });

  group('Vancouver timezone month derivation', () {
    test('winter (PST, UTC-8): late-evening local stays in the same month', () {
      // 2026-03-01 07:30 UTC == 2026-02-28 23:30 PST -> February.
      final m = Month.fromInstant(DateTime.utc(2026, 3, 1, 7, 30));
      expect(m, const Month(2026, 2));
    });

    test('winter: just past local midnight rolls into the new month', () {
      // 2026-03-01 08:30 UTC == 2026-03-01 00:30 PST -> March.
      final m = Month.fromInstant(DateTime.utc(2026, 3, 1, 8, 30));
      expect(m, const Month(2026, 3));
    });

    test('summer (PDT, UTC-7): month boundary shifts by one hour', () {
      // 2026-07-01 06:30 UTC == 2026-06-30 23:30 PDT -> June.
      expect(Month.fromInstant(DateTime.utc(2026, 7, 1, 6, 30)),
          const Month(2026, 6));
      // 2026-07-01 07:30 UTC == 2026-07-01 00:30 PDT -> July.
      expect(Month.fromInstant(DateTime.utc(2026, 7, 1, 7, 30)),
          const Month(2026, 7));
    });
  });

  group('vancouverUtcOffset DST rules', () {
    test('PST in January', () {
      expect(vancouverUtcOffset(DateTime.utc(2026, 1, 15)),
          const Duration(hours: -8));
    });

    test('PDT in July', () {
      expect(vancouverUtcOffset(DateTime.utc(2026, 7, 15)),
          const Duration(hours: -7));
    });

    test('DST starts second Sunday of March 2026 (March 8)', () {
      // 09:59 UTC is still PST; 10:00 UTC is PDT.
      expect(vancouverUtcOffset(DateTime.utc(2026, 3, 8, 9, 59)),
          const Duration(hours: -8));
      expect(vancouverUtcOffset(DateTime.utc(2026, 3, 8, 10, 0)),
          const Duration(hours: -7));
    });

    test('DST ends first Sunday of November 2026 (November 1)', () {
      expect(vancouverUtcOffset(DateTime.utc(2026, 11, 1, 8, 59)),
          const Duration(hours: -7));
      expect(vancouverUtcOffset(DateTime.utc(2026, 11, 1, 9, 0)),
          const Duration(hours: -8));
    });
  });
}
