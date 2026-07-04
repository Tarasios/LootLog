/// Pure receipt-text parsing for on-device OCR.
///
/// This is the confirm-only OCR heuristic layer. It takes the lines of text a
/// recognizer produced and extracts:
///
///  * [ReceiptScan.candidateTotals] — plausible purchase totals, ranked best
///    first. Lines labelled with a total keyword (`total`, `amount due`,
///    `balance due`, …) are preferred; lines labelled `subtotal`, `tax`,
///    `change`, `cash`, `tender`, `tip`, … are ignored; otherwise the largest
///    plausible amount is offered as a fallback.
///  * [ReceiptScan.candidateDate] — the first plausible date found.
///  * [ReceiptScan.merchantGuess] — the first strong non-numeric line, taken as
///    the store name.
///
/// It is a **pure function** with zero side effects and zero Flutter imports so
/// it can be exhaustively unit-tested. Nothing here creates or commits an event;
/// the caller must confirm at least the amount before anything is written.
library;

/// A single ranked total candidate.
class AmountCandidate {
  const AmountCandidate({
    required this.amountCents,
    required this.sourceLine,
    required this.score,
  });

  /// The parsed amount in integer cents.
  final int amountCents;

  /// The (trimmed) line the amount came from, for display/debugging.
  final String sourceLine;

  /// Confidence that this is the receipt's total. Higher ranks earlier.
  /// Keyword-labelled totals score high; bare fallback amounts score zero.
  final int score;

  @override
  bool operator ==(Object other) =>
      other is AmountCandidate &&
      other.amountCents == amountCents &&
      other.sourceLine == sourceLine &&
      other.score == score;

  @override
  int get hashCode => Object.hash(amountCents, sourceLine, score);

  @override
  String toString() =>
      'AmountCandidate($amountCents, "$sourceLine", score: $score)';
}

/// The structured result of parsing receipt text. Everything is a *suggestion*;
/// the user confirms before any event is created.
class ReceiptScan {
  const ReceiptScan({
    required this.candidateTotals,
    this.candidateDate,
    this.merchantGuess,
  });

  /// Plausible totals, ranked best-first. May be empty.
  final List<AmountCandidate> candidateTotals;

  /// The first plausible date found (date only), or null.
  final DateTime? candidateDate;

  /// The best guess at the merchant/store name, or null.
  final String? merchantGuess;

  /// The best total in cents, or null when nothing plausible was found.
  int? get bestTotalCents =>
      candidateTotals.isEmpty ? null : candidateTotals.first.amountCents;

  @override
  String toString() => 'ReceiptScan(totals: $candidateTotals, '
      'date: $candidateDate, merchant: $merchantGuess)';
}

/// Parses a single OCR text blob (splitting on newlines) into a [ReceiptScan].
ReceiptScan parseReceiptText(String text) =>
    parseReceiptLines(text.split(RegExp(r'\r?\n')));

/// Parses OCR text [lines] into a [ReceiptScan]. Pure; order of [lines] is
/// assumed to be top-to-bottom as printed.
ReceiptScan parseReceiptLines(List<String> lines) {
  final byAmount = <int, AmountCandidate>{};

  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final amounts = _extractAmounts(line);
    if (amounts.isEmpty) continue;

    final lower = line.toLowerCase();
    // Payment/adjustment lines are never the purchase total.
    if (_negativeKeywords.any(lower.contains)) continue;

    final score = _keywordScore(lower);
    for (final cents in amounts) {
      if (cents <= 0 || cents > _maxPlausibleCents) continue;
      final existing = byAmount[cents];
      if (existing == null || score > existing.score) {
        byAmount[cents] =
            AmountCandidate(amountCents: cents, sourceLine: line, score: score);
      }
    }
  }

  final candidateTotals = byAmount.values.toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.amountCents.compareTo(a.amountCents);
    });

  return ReceiptScan(
    candidateTotals: candidateTotals,
    candidateDate: _findDate(lines),
    merchantGuess: _findMerchant(lines),
  );
}

/// $1,000,000 — anything larger is almost certainly a misparse.
const int _maxPlausibleCents = 100000000;

/// Line labels that mean "this amount is not the purchase total".
const List<String> _negativeKeywords = [
  'subtotal',
  'sub total',
  'sub-total',
  'tax',
  'gst',
  'hst',
  'pst',
  'qst',
  'vat',
  'change',
  'cash',
  'tender',
  'tip',
  'gratuity',
];

/// Scores a (lower-cased) line by how strongly it reads as the grand total.
int _keywordScore(String lower) {
  if (lower.contains('amount due') ||
      lower.contains('balance due') ||
      lower.contains('total due') ||
      lower.contains('grand total') ||
      lower.contains('amount payable') ||
      lower.contains('total payable')) {
    return 300;
  }
  if (lower.contains('total')) return 200;
  if (lower.contains('balance') ||
      lower.contains('amount owed') ||
      lower.contains('to pay') ||
      lower.contains('pay this')) {
    return 150;
  }
  if (lower.contains('due')) return 120;
  return 0;
}

/// Matches a money amount that ends in a 1–2 digit fractional group, tolerating
/// `.`/`,` grouping and an optional leading currency symbol. Requires the
/// fractional group so bare integers (phone numbers, quantities, dates) are not
/// mistaken for prices. The surrounding look-arounds keep dates like
/// `03.15.2026` from being read as `$3.15`.
final RegExp _amountRe = RegExp(
  r'(?<![\d.,])[\$€£]?\d[\d.,]*[.,]\d{1,2}(?![\d.,])',
);

/// Extracts every plausible money amount on a line, in left-to-right order.
List<int> _extractAmounts(String line) {
  final out = <int>[];
  for (final m in _amountRe.allMatches(line)) {
    final cents = _parseMoneyToken(m.group(0)!);
    if (cents != null) out.add(cents);
  }
  return out;
}

/// Parses a single money token (already matched by [_amountRe]) into cents.
///
/// Handles both `1,234.56` (US: `,` groups, `.` decimal) and `1.234,56`
/// (European: `.` groups, `,` decimal), normalizing both to `123456` cents.
int? _parseMoneyToken(String token) {
  final t = token.replaceAll(RegExp(r'[^\d.,]'), '');
  if (t.isEmpty) return null;

  final hasDot = t.contains('.');
  final hasComma = t.contains(',');
  String normalized;

  if (hasDot && hasComma) {
    // The right-most separator is the decimal point; the other groups thousands.
    if (t.lastIndexOf(',') > t.lastIndexOf('.')) {
      normalized = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      normalized = t.replaceAll(',', '');
    }
  } else if (hasComma) {
    final parts = t.split(',');
    if (parts.length == 2 && parts[1].length == 2) {
      normalized = '${parts[0]}.${parts[1]}'; // European decimal comma
    } else {
      normalized = t.replaceAll(',', ''); // thousands grouping
    }
  } else if (hasDot) {
    final parts = t.split('.');
    if (parts.length > 2) {
      normalized = t.replaceAll('.', ''); // dotted thousands grouping
    } else if (parts.length == 2 &&
        parts[1].length == 3 &&
        parts[0].length <= 3) {
      normalized = t.replaceAll('.', ''); // e.g. 1.234 -> 1234
    } else {
      normalized = t;
    }
  } else {
    normalized = t;
  }

  final value = double.tryParse(normalized);
  if (value == null) return null;
  return (value * 100).round();
}

const List<String> _monthNames = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

final RegExp _isoDateRe = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
final RegExp _numericDateRe = RegExp(r'(\d{1,2})[/.](\d{1,2})[/.](\d{2,4})');
final RegExp _monthFirstRe = RegExp(
  r'([a-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})',
  caseSensitive: false,
);
final RegExp _dayFirstRe = RegExp(
  r'(\d{1,2})(?:st|nd|rd|th)?\s+([a-z]{3,9})\.?,?\s+(\d{4})',
  caseSensitive: false,
);

/// Finds the first plausible date across [lines], scanning top-to-bottom.
DateTime? _findDate(List<String> lines) {
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final d = _parseDateFromLine(line);
    if (d != null) return d;
  }
  return null;
}

DateTime? _parseDateFromLine(String line) {
  final iso = _isoDateRe.firstMatch(line);
  if (iso != null) {
    return _validDate(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }

  final monthFirst = _monthFirstRe.firstMatch(line);
  if (monthFirst != null) {
    final month = _monthIndex(monthFirst.group(1)!);
    if (month != null) {
      return _validDate(
        int.parse(monthFirst.group(3)!),
        month,
        int.parse(monthFirst.group(2)!),
      );
    }
  }

  final dayFirst = _dayFirstRe.firstMatch(line);
  if (dayFirst != null) {
    final month = _monthIndex(dayFirst.group(2)!);
    if (month != null) {
      return _validDate(
        int.parse(dayFirst.group(3)!),
        month,
        int.parse(dayFirst.group(1)!),
      );
    }
  }

  final numeric = _numericDateRe.firstMatch(line);
  if (numeric != null) {
    var year = int.parse(numeric.group(3)!);
    if (year < 100) year += 2000;
    final a = int.parse(numeric.group(1)!);
    final b = int.parse(numeric.group(2)!);
    // Default to North American MM/DD; fall back to DD/MM when unambiguous.
    if (a > 12 && b <= 12) {
      return _validDate(year, b, a);
    }
    return _validDate(year, a, b) ?? _validDate(year, b, a);
  }

  return null;
}

int? _monthIndex(String name) {
  final key = name.toLowerCase();
  for (var i = 0; i < _monthNames.length; i++) {
    if (key.startsWith(_monthNames[i])) return i + 1;
  }
  return null;
}

DateTime? _validDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final d = DateTime(year, month, day);
  // Reject rollovers like Feb 30 -> Mar 2.
  if (d.year != year || d.month != month || d.day != day) return null;
  return d;
}

bool _lineHasDate(String line) => _parseDateFromLine(line) != null;

/// Picks the merchant name: the first line with real alphabetic content that is
/// not a price, a date, or a mostly-numeric line (phone/address).
String? _findMerchant(List<String> lines) {
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final letters = line.replaceAll(RegExp('[^A-Za-z]'), '');
    if (letters.length < 2) continue;
    if (_extractAmounts(line).isNotEmpty) continue;
    if (_lineHasDate(line)) continue;
    final digits = line.replaceAll(RegExp('[^0-9]'), '');
    if (digits.length > letters.length) continue;
    return line;
  }
  return null;
}
