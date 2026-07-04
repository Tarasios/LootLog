/// Thin, platform-guarded wrapper around on-device text recognition.
///
/// The heuristics that turn text into a [ReceiptScan] live in the pure,
/// unit-tested `receipt_parse.dart`. This file adds the one impure step —
/// running the recognizer — and nothing else. Recognition is **Android-only**
/// (ML Kit ships no desktop implementation), so callers must check
/// [ReceiptOcr.isSupported] and fall back to plain photo attachment elsewhere.
///
/// This never creates or modifies an event; it only produces suggestions the
/// user must confirm.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_parse.dart';

/// On-device receipt recognition. Implementations are confirm-only: they return
/// suggestions, never events.
abstract interface class ReceiptOcr {
  /// Whether recognition can run on this platform.
  bool get isSupported;

  /// Recognizes the receipt image at [imagePath] and parses it. Throws
  /// [UnsupportedError] where [isSupported] is false.
  Future<ReceiptScan> scanImageFile(String imagePath);
}

/// ML Kit-backed recognition (Android). The model is bundled and runs fully
/// on-device with no network.
class MlKitReceiptOcr implements ReceiptOcr {
  const MlKitReceiptOcr();

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  @override
  Future<ReceiptScan> scanImageFile(String imagePath) async {
    if (!isSupported) {
      throw UnsupportedError('On-device OCR is only available on Android');
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final lines = <String>[
        for (final block in recognized.blocks)
          for (final line in block.lines) line.text,
      ];
      return parseReceiptLines(lines);
    } finally {
      await recognizer.close();
    }
  }
}

/// Recognition unavailable (desktop). Reports unsupported and refuses to scan.
class UnsupportedReceiptOcr implements ReceiptOcr {
  const UnsupportedReceiptOcr();

  @override
  bool get isSupported => false;

  @override
  Future<ReceiptScan> scanImageFile(String imagePath) async =>
      throw UnsupportedError('On-device OCR is only available on Android');
}

/// The recognizer for this platform: ML Kit on Android, unsupported elsewhere.
final receiptOcrProvider = Provider<ReceiptOcr>((ref) {
  if (!kIsWeb && Platform.isAndroid) {
    return const MlKitReceiptOcr();
  }
  return const UnsupportedReceiptOcr();
});
