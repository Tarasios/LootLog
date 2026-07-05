/// Shared money / date formatting helpers used across the classic UI. Kept tiny
/// and dependency-free so both pure view-models and widgets can reach for them.
library;

import '../domain/money.dart';

/// `1234 -> "$12.34"`. The canonical on-screen money string.
String money(int cents) => '\$${Money(cents).format()}';

/// A compact signed money string, e.g. `+$12.34` / `-$5.00`, for deltas.
String signedMoney(int cents) =>
    cents >= 0 ? '+${money(cents)}' : '-${money(-cents)}';

/// `2026-07-04`. A stable, locale-independent day label.
String isoDay(DateTime at) =>
    '${at.year.toString().padLeft(4, '0')}-'
    '${at.month.toString().padLeft(2, '0')}-'
    '${at.day.toString().padLeft(2, '0')}';

/// Month names for compact headers (`Month(2026,7)` -> "July 2026").
const _monthNames = <String>[
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// `"July 2026"` for a 1-based [month] and [year].
String monthLabel(int year, int month) => '${_monthNames[month]} $year';
