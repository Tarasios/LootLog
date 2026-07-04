/// Calendar-time helpers for DuoBudget. Months are calendar months in the
/// household timezone (America/Vancouver), keyed by each event's `occurredAt`.
///
/// The household timezone offset is computed from the post-2007 US DST rules
/// (DST from the second Sunday of March to the first Sunday of November) so we
/// need no timezone package. Pure Dart, zero Flutter imports.
library;

/// The UTC offset of America/Vancouver at the given [instant].
///
/// PST is UTC-8; PDT is UTC-7. DST begins at 02:00 local standard time on the
/// second Sunday of March (10:00 UTC) and ends at 02:00 local daylight time on
/// the first Sunday of November (09:00 UTC).
Duration vancouverUtcOffset(DateTime instant) {
  final u = instant.toUtc();
  final dstStart = _dstStartUtc(u.year);
  final dstEnd = _dstEndUtc(u.year);
  final inDst = !u.isBefore(dstStart) && u.isBefore(dstEnd);
  return Duration(hours: inDst ? -7 : -8);
}

DateTime _dstStartUtc(int year) {
  final day = _nthWeekday(year, 3, DateTime.sunday, 2);
  return DateTime.utc(year, 3, day, 10);
}

DateTime _dstEndUtc(int year) {
  final day = _nthWeekday(year, 11, DateTime.sunday, 1);
  return DateTime.utc(year, 11, day, 9);
}

/// Returns the day-of-month of the [n]th [weekday] in the given [year]/[month].
int _nthWeekday(int year, int month, int weekday, int n) {
  var count = 0;
  var day = 1;
  while (true) {
    final d = DateTime.utc(year, month, day);
    if (d.weekday == weekday) {
      count++;
      if (count == n) {
        return day;
      }
    }
    day++;
  }
}

/// A calendar month in the household timezone.
class Month implements Comparable<Month> {
  const Month(this.year, this.month)
      : assert(month >= 1 && month <= 12, 'month must be 1..12');

  /// Parses a `"yyyy-MM"` key such as `"2026-03"`.
  factory Month.parse(String key) {
    final parts = key.split('-');
    if (parts.length != 2) {
      throw FormatException('Not a month key: $key');
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    if (month < 1 || month > 12) {
      throw FormatException('Month out of range: $key');
    }
    return Month(year, month);
  }

  /// Derives the household-timezone month for an [instant].
  factory Month.fromInstant(DateTime instant) {
    final u = instant.toUtc();
    final local = u.add(vancouverUtcOffset(u));
    return Month(local.year, local.month);
  }

  final int year;
  final int month;

  /// The `"yyyy-MM"` key.
  String toKey() => '$year-${month.toString().padLeft(2, '0')}';

  /// The month that follows this one.
  Month next() =>
      month == 12 ? Month(year + 1, 1) : Month(year, month + 1);

  /// The month that precedes this one.
  Month prev() =>
      month == 1 ? Month(year - 1, 12) : Month(year, month - 1);

  /// The first instant (UTC) of this month in the household timezone. Used to
  /// order month-start effects (like emergency contributions) on a timeline.
  DateTime startInstantUtc() {
    // Wall-clock midnight local; convert to UTC by subtracting the offset.
    final approxLocalAsUtc = DateTime.utc(year, month, 1);
    final offset = vancouverUtcOffset(approxLocalAsUtc.subtract(_slack));
    return approxLocalAsUtc.subtract(offset);
  }

  /// The last instant (UTC) of this month in the household timezone (exclusive
  /// upper bound = the start of the next month).
  DateTime endInstantUtc() => next().startInstantUtc();

  static const Duration _slack = Duration(hours: 12);

  @override
  int compareTo(Month other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    return month.compareTo(other.month);
  }

  bool isBefore(Month other) => compareTo(other) < 0;

  bool isAfter(Month other) => compareTo(other) > 0;

  bool operator <(Month other) => compareTo(other) < 0;

  bool operator <=(Month other) => compareTo(other) <= 0;

  bool operator >(Month other) => compareTo(other) > 0;

  bool operator >=(Month other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Month && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'Month(${toKey()})';
}
