/// Small input helpers shared by the settings / setup / governance forms.
library;

import '../domain/money.dart';

/// Parses a user-entered money string into cents, or null if it is not a valid
/// non-negative amount. Empty input returns null.
int? tryParseMoneyCents(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  try {
    final cents = Money.parse(trimmed).cents;
    return cents < 0 ? null : cents;
  } on FormatException {
    return null;
  }
}

/// Parses an integer percentage in 0..100, or null if out of range / invalid.
int? tryParsePercent(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final parsed = int.tryParse(trimmed);
  if (parsed == null || parsed < 0 || parsed > 100) return null;
  return parsed;
}
