/// A scripted [ReceiptTextRecognizer] for widget tests: returns fixed lines
/// or throws a fixed error, and records which images it was asked to read.
library;

import 'package:lootlog/data/ocr/text_recognizer.dart';

class FakeTextRecognizer implements ReceiptTextRecognizer {
  FakeTextRecognizer.returning(this.lines)
      : error = null,
        isSupported = true;

  FakeTextRecognizer.throwing(Object this.error)
      : lines = const [],
        isSupported = true;

  FakeTextRecognizer.unsupported()
      : lines = const [],
        error = null,
        isSupported = false;

  final List<String> lines;
  final Object? error;
  final List<String> requestedPaths = [];

  @override
  final bool isSupported;

  @override
  Future<List<String>> recognizeLines(String imagePath) async {
    requestedPaths.add(imagePath);
    final failure = error;
    if (failure != null) throw failure;
    return lines;
  }
}
