import 'package:lootlog/domain/time.dart';
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

  group('CalendarDay', () {
    test('parses and formats keys', () {
      expect(CalendarDay.parse('2026-03-07').toKey(), '2026-03-07');
      expect(const CalendarDay(2026, 3, 7).toKey(), '2026-03-07');
      expect(() => CalendarDay.parse('2026-03'), throwsFormatException);
    });

    test('derives the household-timezone date of an instant', () {
      // 06:59 UTC on the 8th is still 23:59 PDT on the 7th in Vancouver.
      expect(CalendarDay.fromInstant(DateTime.utc(2026, 7, 8, 6, 59)),
          const CalendarDay(2026, 7, 7));
      expect(CalendarDay.fromInstant(DateTime.utc(2026, 7, 8, 7)),
          const CalendarDay(2026, 7, 8));
    });

    test('day arithmetic crosses months, years and DST', () {
      expect(const CalendarDay(2026, 2, 28).addDays(1),
          const CalendarDay(2026, 3, 1));
      expect(const CalendarDay(2026, 12, 31).addDays(1),
          const CalendarDay(2027, 1, 1));
      expect(const CalendarDay(2026, 3, 9).addDays(-2),
          const CalendarDay(2026, 3, 7));
      expect(const CalendarDay(2026, 3, 1).daysUntil(
              const CalendarDay(2026, 3, 15)),
          14);
    });

    test('weeks start on Monday', () {
      // 2026-10-03 is a Saturday; its week began Monday 2026-09-28.
      expect(const CalendarDay(2026, 10, 3).weekStart,
          const CalendarDay(2026, 9, 28));
      expect(const CalendarDay(2026, 9, 28).weekStart,
          const CalendarDay(2026, 9, 28));
      // Sunday belongs to the week that started six days earlier.
      expect(const CalendarDay(2026, 10, 4).weekStart,
          const CalendarDay(2026, 9, 28));
    });

    test('orders correctly', () {
      expect(const CalendarDay(2026, 1, 31) < const CalendarDay(2026, 2, 1),
          isTrue);
      expect(const CalendarDay(2026, 2, 1) <= const CalendarDay(2026, 2, 1),
          isTrue);
      expect(const CalendarDay(2026, 2, 2) > const CalendarDay(2026, 2, 1),
          isTrue);
    });
  });
}
