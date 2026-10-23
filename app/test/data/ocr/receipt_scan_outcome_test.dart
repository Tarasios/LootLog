import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/ocr/receipt_scan_outcome.dart';

void main() {
  group('ReceiptScanOutcome.fromRecognizedLines', () {
    test('a receipt with a total has no issue and keeps the raw text', () {
      final outcome = ReceiptScanOutcome.fromRecognizedLines(
        const ['CORNER MARKET', '2026-03-15', 'TOTAL 14.70'],
        elapsed: const Duration(milliseconds: 412),
      );

      expect(outcome.issue, isNull);
      expect(outcome.foundAmount, isTrue);
      expect(outcome.scan.bestTotalCents, 1470);
      expect(outcome.scan.merchantGuess, 'CORNER MARKET');
      expect(outcome.recognizedText, 'CORNER MARKET\n2026-03-15\nTOTAL 14.70');
      expect(outcome.elapsed, const Duration(milliseconds: 412));
      expect(outcome.errorMessage, isNull);
    });

    test('no lines at all is "no text"', () {
      final outcome = ReceiptScanOutcome.fromRecognizedLines(const []);

      expect(outcome.issue, ReceiptScanIssue.noText);
      expect(outcome.foundAmount, isFalse);
    });

    test('only blank lines is still "no text"', () {
      final outcome = ReceiptScanOutcome.fromRecognizedLines(const ['', '   ']);

      expect(outcome.issue, ReceiptScanIssue.noText);
    });

    test('text without any amount is "no amount", merchant still extracted',
        () {
      final outcome = ReceiptScanOutcome.fromRecognizedLines(
        const ['CORNER MARKET', 'Thank you for shopping'],
      );

      expect(outcome.issue, ReceiptScanIssue.noAmount);
      expect(outcome.foundAmount, isFalse);
      expect(outcome.scan.merchantGuess, 'CORNER MARKET');
    });
  });

  group('ReceiptScanOutcome.recognizerFailed', () {
    test('carries the reason and an empty scan', () {
      final outcome = ReceiptScanOutcome.recognizerFailed(
        'model not found',
        elapsed: const Duration(milliseconds: 30),
      );

      expect(outcome.issue, ReceiptScanIssue.recognizerFailed);
      expect(outcome.errorMessage, 'model not found');
      expect(outcome.scan.candidateTotals, isEmpty);
      expect(outcome.recognizedLines, isEmpty);
      expect(outcome.elapsed, const Duration(milliseconds: 30));
    });
  });

  test('unsupported has the unsupported issue and nothing recognized', () {
    expect(ReceiptScanOutcome.unsupported.issue, ReceiptScanIssue.unsupported);
    expect(ReceiptScanOutcome.unsupported.recognizedLines, isEmpty);
    expect(ReceiptScanOutcome.unsupported.foundAmount, isFalse);
  });

  group('shortErrorReason', () {
    test('keeps a short message as is', () {
      expect(shortErrorReason('model not found'), 'model not found');
    });

    test('keeps only the first non-empty line', () {
      expect(
        shortErrorReason('\n  Failed to load model  \n  at frame 1\n'),
        'Failed to load model',
      );
    });

    test('drops a generic "Exception: " prefix', () {
      expect(shortErrorReason('Exception: camera busy'), 'camera busy');
    });

    test('cuts long messages with an ellipsis', () {
      final reason = shortErrorReason('x' * 300, maxLength: 20);
      expect(reason.length, 20);
      expect(reason.endsWith('…'), isTrue);
    });

    test('an empty message becomes a plain fallback', () {
      expect(shortErrorReason('   '), 'unknown error');
    });
  });
}
