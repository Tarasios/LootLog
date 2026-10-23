/// Plain-words copy for what a receipt scan found. The same in Standard and
/// Adventure: it is help text, not flavor. Every failure line points at the
/// keypad, so a failed scan is never a dead end.
library;

import '../../data/ocr/receipt_scan_outcome.dart';

/// The one-line status shown on the confirm screen after a scan.
String scanStatusLine(ReceiptScanOutcome outcome) => switch (outcome.issue) {
      null => 'Scanned — check the amount before saving',
      ReceiptScanIssue.unsupported =>
        'Scanning runs on Android — enter the amount below',
      ReceiptScanIssue.recognizerFailed =>
        "The scanner couldn't run (${outcome.errorMessage ?? 'unknown error'})"
            ' — enter the amount below',
      ReceiptScanIssue.noText =>
        'No text found in the photo — enter the amount below',
      ReceiptScanIssue.noAmount =>
        'Found text but no total — enter the amount below',
    };

/// A short verdict for the scanner test screen.
String scanVerdict(ReceiptScanOutcome outcome) => switch (outcome.issue) {
      null => 'Found a total',
      ReceiptScanIssue.unsupported => 'Scanning runs on Android',
      ReceiptScanIssue.recognizerFailed => 'The scanner hit an error',
      ReceiptScanIssue.noText => 'No text found',
      ReceiptScanIssue.noAmount => 'Text found, but no total',
    };

/// A snackbar line for a scan that ran after attaching a receipt to an
/// existing purchase and could not suggest a total; null when there is
/// nothing worth saying (a total was found, or scanning does not run here).
String? attachedScanProblemLine(ReceiptScanOutcome outcome) =>
    switch (outcome.issue) {
      null || ReceiptScanIssue.unsupported => null,
      ReceiptScanIssue.recognizerFailed =>
        "Receipt attached. The scanner couldn't run "
            '(${outcome.errorMessage ?? 'unknown error'})',
      ReceiptScanIssue.noText => 'Receipt attached. No text found in the photo',
      ReceiptScanIssue.noAmount =>
        'Receipt attached. Found text but no total',
    };
