/// Thin, platform-guarded wrapper around on-device text recognition.
///
/// The heuristics that turn text into a [ReceiptScan] live in the pure,
/// unit-tested `receipt_parse.dart`, and the classification of what a scan
/// found in `receipt_scan_outcome.dart`. This file adds the one impure step —
/// running the recognizer — behind the [ReceiptTextRecognizer] interface so
/// tests inject a fake. Recognition is **Android-only** (ML Kit ships no
/// desktop implementation); elsewhere [ReceiptOcr] reports
/// [ReceiptScanIssue.unsupported] and callers fall back to manual entry.
///
/// This never creates or modifies an event; it only produces suggestions the
/// user must confirm.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_scan_outcome.dart';

export 'receipt_scan_outcome.dart';

/// Turns an image into lines of text. Implementations only read; they never
/// write events.
abstract interface class ReceiptTextRecognizer {
  /// Whether recognition can run on this platform.
  bool get isSupported;

  /// The text lines in the image at [imagePath], top to bottom. May throw.
  Future<List<String>> recognizeLines(String imagePath);
}

/// ML Kit-backed recognition (Android). The model is bundled and runs fully
/// on-device with no network.
class MlKitTextRecognizer implements ReceiptTextRecognizer {
  const MlKitTextRecognizer();

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  @override
  Future<List<String>> recognizeLines(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return [
        for (final block in recognized.blocks)
          for (final line in block.lines) line.text,
      ];
    } finally {
      await recognizer.close();
    }
  }
}

/// Recognition unavailable (desktop).
class UnsupportedTextRecognizer implements ReceiptTextRecognizer {
  const UnsupportedTextRecognizer();

  @override
  bool get isSupported => false;

  @override
  Future<List<String>> recognizeLines(String imagePath) async =>
      throw UnsupportedError('On-device OCR is only available on Android');
}

/// Runs a [ReceiptTextRecognizer] and reports a [ReceiptScanOutcome]. Never
/// throws: a recognizer failure becomes [ReceiptScanIssue.recognizerFailed]
/// with a short reason, so the user always sees what happened and can type
/// the amount themselves.
class ReceiptOcr {
  const ReceiptOcr(this.recognizer);

  final ReceiptTextRecognizer recognizer;

  /// Whether recognition can run on this platform.
  bool get isSupported => recognizer.isSupported;

  /// Recognizes and parses the receipt image at [imagePath].
  Future<ReceiptScanOutcome> scanImageFile(String imagePath) async {
    if (!isSupported) return ReceiptScanOutcome.unsupported;
    final stopwatch = Stopwatch()..start();
    try {
      final lines = await recognizer.recognizeLines(imagePath);
      return ReceiptScanOutcome.fromRecognizedLines(
        lines,
        elapsed: stopwatch.elapsed,
      );
    } on Object catch (error) {
      return ReceiptScanOutcome.recognizerFailed(
        describeRecognizerError(error),
        elapsed: stopwatch.elapsed,
      );
    }
  }
}

/// A short, readable reason for a recognizer [error].
String describeRecognizerError(Object error) {
  if (error is MissingPluginException) {
    return 'the text recognizer is missing from this build';
  }
  if (error is PlatformException) {
    final detail = error.message?.trim();
    return shortErrorReason(
      detail == null || detail.isEmpty ? error.code : '${error.code}: $detail',
    );
  }
  return shortErrorReason(error.toString());
}

/// The text recognizer for this platform: ML Kit on Android, unsupported
/// elsewhere. Tests override this with a fake.
final receiptTextRecognizerProvider = Provider<ReceiptTextRecognizer>((ref) {
  if (!kIsWeb && Platform.isAndroid) {
    return const MlKitTextRecognizer();
  }
  return const UnsupportedTextRecognizer();
});

/// Receipt scanning over the platform's recognizer.
final receiptOcrProvider = Provider<ReceiptOcr>(
  (ref) => ReceiptOcr(ref.watch(receiptTextRecognizerProvider)),
);
