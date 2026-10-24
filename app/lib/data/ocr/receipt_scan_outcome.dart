/// What one receipt scan produced, including why it found nothing usable.
///
/// Pure Dart (no Flutter imports) so the classification is unit-tested. The
/// plugin wrapper in `text_recognizer.dart` builds an outcome from whatever
/// the recognizer returned or threw; screens turn the [ReceiptScanIssue] into
/// plain words. Like the parser, an outcome is only a suggestion: nothing
/// here creates an event.
library;

import 'receipt_parse.dart';

/// Why a scan could not suggest an amount.
enum ReceiptScanIssue {
  /// Scanning does not run on this platform (it is Android-only).
  unsupported,

  /// The recognizer threw; [ReceiptScanOutcome.errorMessage] says why.
  recognizerFailed,

  /// The recognizer ran but found no text in the image.
  noText,

  /// Text was found, but none of it looked like a total.
  noAmount,
}

/// The full result of one scan: the raw recognized text, what the parser
/// extracted from it, how long recognition took, and any issue.
class ReceiptScanOutcome {
  const ReceiptScanOutcome({
    required this.scan,
    this.recognizedLines = const [],
    this.elapsed = Duration.zero,
    this.issue,
    this.errorMessage,
  });

  /// Parses the [lines] a recognizer returned and classifies the result.
  factory ReceiptScanOutcome.fromRecognizedLines(
    List<String> lines, {
    Duration elapsed = Duration.zero,
  }) {
    final scan = parseReceiptLines(lines);
    final hasText = lines.any((line) => line.trim().isNotEmpty);
    return ReceiptScanOutcome(
      scan: scan,
      recognizedLines: List.unmodifiable(lines),
      elapsed: elapsed,
      issue: !hasText
          ? ReceiptScanIssue.noText
          : scan.bestTotalCents == null
              ? ReceiptScanIssue.noAmount
              : null,
    );
  }

  /// The recognizer threw; [reason] is a short, readable explanation.
  factory ReceiptScanOutcome.recognizerFailed(
    String reason, {
    Duration elapsed = Duration.zero,
  }) =>
      ReceiptScanOutcome(
        scan: emptyScan,
        elapsed: elapsed,
        issue: ReceiptScanIssue.recognizerFailed,
        errorMessage: reason,
      );

  /// Scanning is not available on this platform.
  static const unsupported = ReceiptScanOutcome(
    scan: emptyScan,
    issue: ReceiptScanIssue.unsupported,
  );

  /// A scan with no suggestions.
  static const emptyScan = ReceiptScan(candidateTotals: []);

  /// What the parser extracted (possibly nothing).
  final ReceiptScan scan;

  /// The recognizer's raw lines, top to bottom.
  final List<String> recognizedLines;

  /// How long recognition and parsing took.
  final Duration elapsed;

  /// Why no amount could be suggested, or null when one was found.
  final ReceiptScanIssue? issue;

  /// The recognizer's error, shortened for display; only for
  /// [ReceiptScanIssue.recognizerFailed].
  final String? errorMessage;

  /// The raw recognized text as one block.
  String get recognizedText => recognizedLines.join('\n');

  /// Whether the parser suggested a total.
  bool get foundAmount => scan.bestTotalCents != null;
}

/// Shortens an error [message] to one readable line: the first non-empty
/// line, without a generic `Exception: ` prefix, cut to [maxLength]
/// characters with an ellipsis.
String shortErrorReason(String message, {int maxLength = 120}) {
  const genericPrefix = 'Exception: ';
  final firstLine = message
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  if (firstLine.isEmpty) return 'unknown error';
  final reason = firstLine.startsWith(genericPrefix)
      ? firstLine.substring(genericPrefix.length)
      : firstLine;
  if (reason.length <= maxLength) return reason;
  return '${reason.substring(0, maxLength - 1)}…';
}
