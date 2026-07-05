/// Small input helpers shared by the settings / setup / governance forms.
library;

import '../domain/money.dart';

/// Parses a user-entered money string into cents, or null if it is not a valid
/// non-negative amount. Empty input returns null.
int? tryParseMoneyCents(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  try {
    final cents = Money.parse(s).cents;
    return cents < 0 ? null : cents;
  } on FormatException {
    return null;
  }
}

/// Parses an integer percentage in 0..100, or null if out of range / invalid.
int? tryParsePercent(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  final n = int.tryParse(s);
  if (n == null || n < 0 || n > 100) return null;
  return n;
}
