/// Money is integer cents everywhere in LootLog. Never use `double` for
/// money — this value type is the only carrier of monetary amounts. "Gold" is
/// merely a display unit in the adventure skin; the ledger is always cents.
///
/// This file is pure Dart with zero Flutter imports.
library;

/// The result of splitting an amount 50/50, with any odd cent going to a
/// designated party (the purchaser, by convention).
class MoneySplit {
  const MoneySplit({required this.designatedCents, required this.otherCents});

  /// The designated party's share. Receives the odd cent when the total is odd.
  final int designatedCents;

  /// The other party's share (the floored half).
  final int otherCents;

  @override
  bool operator ==(Object other) =>
      other is MoneySplit &&
      other.designatedCents == designatedCents &&
      other.otherCents == otherCents;

  @override
  int get hashCode => Object.hash(designatedCents, otherCents);

  @override
  String toString() =>
      'MoneySplit(designated: $designatedCents, other: $otherCents)';
}

/// The result of applying a percentage with floor rounding. The [titheCents]
/// (floored) plus the [remainderCents] always sum exactly to the input amount,
/// so no cents are ever created or destroyed.
class Tithe {
  const Tithe({required this.titheCents, required this.remainderCents});

  /// The floored percentage portion (goes to the war chest for pool tithes).
  final int titheCents;

  /// Everything the tithe did not take (goes to the user).
  final int remainderCents;

  int get totalCents => titheCents + remainderCents;

  @override
  bool operator ==(Object other) =>
      other is Tithe &&
      other.titheCents == titheCents &&
      other.remainderCents == remainderCents;

  @override
  int get hashCode => Object.hash(titheCents, remainderCents);

  @override
  String toString() => 'Tithe(tithe: $titheCents, remainder: $remainderCents)';
}

/// An immutable amount of money, stored as integer cents.
class Money implements Comparable<Money> {
  const Money(this.cents);

  /// Zero cents.
  static const Money zero = Money(0);

  /// The amount in whole cents. This is the canonical representation.
  final int cents;

  /// Parses a human-entered string such as `"12.34"`, `"12"`, `"-5.5"`,
  /// `"$1,234.50"` into integer cents. Whitespace, a leading currency symbol,
  /// and thousands separators are tolerated. At most two fractional digits are
  /// allowed. Throws [FormatException] on anything else.
  static Money parse(String input) {
    var text = input.trim();
    if (text.isEmpty) {
      throw const FormatException('Empty money string');
    }
    var negative = false;
    // Accounting-style parentheses denote a negative amount.
    if (text.startsWith('(') && text.endsWith(')')) {
      negative = true;
      text = text.substring(1, text.length - 1);
    }
    text = text.replaceAll(RegExp(r'[\$,\s]'), '');
    if (text.startsWith('-')) {
      negative = true;
      text = text.substring(1);
    } else if (text.startsWith('+')) {
      text = text.substring(1);
    }
    if (text.isEmpty) {
      throw FormatException('Not a valid money string: $input');
    }
    final parts = text.split('.');
    if (parts.length > 2) {
      throw FormatException('Too many decimal points: $input');
    }
    final wholePart = parts[0];
    if (wholePart.isNotEmpty && !RegExp(r'^\d+$').hasMatch(wholePart)) {
      throw FormatException('Not a valid money string: $input');
    }
    final whole = wholePart.isEmpty ? 0 : int.parse(wholePart);
    var fractionCents = 0;
    if (parts.length == 2) {
      var fractionDigits = parts[1];
      if (fractionDigits.isEmpty ||
          fractionDigits.length > 2 ||
          !RegExp(r'^\d+$').hasMatch(fractionDigits)) {
        throw FormatException('Not a valid money string: $input');
      }
      fractionDigits = fractionDigits.padRight(2, '0');
      fractionCents = int.parse(fractionDigits);
    }
    final total = whole * 100 + fractionCents;
    return Money(negative ? -total : total);
  }

  /// Formats as a plain decimal string with exactly two fractional digits,
  /// e.g. `1234 -> "12.34"`, `-5 -> "-0.05"`. No currency symbol or grouping.
  String format() {
    final negative = cents < 0;
    final magnitude = cents.abs();
    final dollars = magnitude ~/ 100;
    final remainder = magnitude % 100;
    final sign = negative ? '-' : '';
    return '$sign$dollars.${remainder.toString().padLeft(2, '0')}';
  }

  Money operator +(Money other) => Money(cents + other.cents);

  Money operator -(Money other) => Money(cents - other.cents);

  Money operator -() => Money(-cents);

  bool operator <(Money other) => cents < other.cents;

  bool operator <=(Money other) => cents <= other.cents;

  bool operator >(Money other) => cents > other.cents;

  bool operator >=(Money other) => cents >= other.cents;

  bool get isNegative => cents < 0;

  bool get isZero => cents == 0;

  Money abs() => Money(cents.abs());

  /// Splits this amount 50/50, giving the odd cent (if any) to the designated
  /// party. For `101`: designated `51`, other `50`.
  MoneySplit split() {
    final half = cents ~/ 2;
    return MoneySplit(designatedCents: cents - half, otherCents: half);
  }

  /// Splits a raw cent [total] 50/50 with the odd cent to the designated party.
  static MoneySplit splitCents(int total) => Money(total).split();

  /// Applies [pct] percent (0..100) to this amount with floor rounding,
  /// tracking the remainder so the two parts sum back exactly to [cents].
  Tithe applyTithe(int pct) => titheCents(cents, pct);

  /// Applies [pct] percent (0..100) to a raw cent [amount] with floor rounding.
  /// The returned tithe plus remainder always sum exactly to [amount].
  static Tithe titheCents(int amount, int pct) {
    if (pct < 0 || pct > 100) {
      throw ArgumentError.value(pct, 'pct', 'must be between 0 and 100');
    }
    final tithe = (amount * pct) ~/ 100;
    return Tithe(titheCents: tithe, remainderCents: amount - tithe);
  }

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => 'Money(${format()})';
}
