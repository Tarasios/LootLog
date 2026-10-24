/// Settings → Test receipt scanner, with a fake recognizer and photo picker:
/// it shows the raw text, what the parser extracted ("not found" when
/// absent), timing and errors, and is Android-only.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lootlog/data/ocr/text_recognizer.dart';
import 'package:lootlog/features/ocr/scanner_test_screen.dart';

import 'fake_text_recognizer.dart';

Future<List<ImageSource>> _pumpScreen(
  WidgetTester tester,
  FakeTextRecognizer recognizer, {
  ScannerPhotoPicker? picker,
}) async {
  final requestedSources = <ImageSource>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [receiptTextRecognizerProvider.overrideWithValue(recognizer)],
    child: MaterialApp(
      home: ReceiptScannerTestScreen(
        pickPhoto: picker ??
            (source) async {
              requestedSources.add(source);
              return '/photos/receipt.jpg';
            },
      ),
    ),
  ));
  await tester.pump();
  return requestedSources;
}

Future<void> _scan(WidgetTester tester, String buttonLabel) async {
  await tester.tap(find.text(buttonLabel));
  // The fake resolves on a microtask; let it land, then rebuild.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the raw text and everything the parser extracted',
      (tester) async {
    final recognizer = FakeTextRecognizer.returning(
        ['CORNER MARKET', '2026-03-15', 'SUBTOTAL 13.74', 'TOTAL 14.70']);
    final sources = await _pumpScreen(tester, recognizer);

    await _scan(tester, 'Take a photo');

    expect(sources, [ImageSource.camera]);
    expect(recognizer.requestedPaths, ['/photos/receipt.jpg']);
    expect(find.text('Found a total'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Took \d+ ms$')), findsOneWidget);
    expect(find.text('\$14.70'), findsOneWidget);
    expect(find.text('2026-03-15'), findsOneWidget);
    expect(find.text('CORNER MARKET'), findsOneWidget);
    expect(
      find.text('CORNER MARKET\n2026-03-15\nSUBTOTAL 13.74\nTOTAL 14.70'),
      findsOneWidget,
    );
    expect(find.text('not found'), findsNothing);
  });

  testWidgets('says "not found" for each missing value', (tester) async {
    final recognizer = FakeTextRecognizer.returning(['Thank you!']);
    final sources = await _pumpScreen(tester, recognizer);

    await _scan(tester, 'Choose a photo');

    expect(sources, [ImageSource.gallery]);
    expect(find.text('Text found, but no total'), findsOneWidget);
    // Amount and date are absent; the merchant guess is the only line.
    expect(find.text('not found'), findsNWidgets(2));
  });

  testWidgets('shows a recognizer error with its message', (tester) async {
    final recognizer = FakeTextRecognizer.throwing(
        PlatformException(code: 'mlkit', message: 'Model missing'));
    await _pumpScreen(tester, recognizer);

    await _scan(tester, 'Take a photo');

    expect(find.text('The scanner hit an error'), findsOneWidget);
    expect(find.text('Error: mlkit: Model missing'), findsOneWidget);
    expect(find.text('(no text)'), findsOneWidget);
    expect(find.text('not found'), findsNWidgets(3));
  });

  testWidgets('shows "no text" when the photo holds none', (tester) async {
    await _pumpScreen(tester, FakeTextRecognizer.returning([]));

    await _scan(tester, 'Take a photo');

    expect(find.text('No text found'), findsOneWidget);
    expect(find.text('(no text)'), findsOneWidget);
  });

  testWidgets('a cancelled photo scans nothing', (tester) async {
    final recognizer = FakeTextRecognizer.returning(['TOTAL 1.00']);
    await _pumpScreen(tester, recognizer, picker: (_) async => null);

    await _scan(tester, 'Take a photo');

    expect(recognizer.requestedPaths, isEmpty);
    expect(find.text('Found a total'), findsNothing);
  });

  testWidgets('off Android it explains in one line and offers no scan',
      (tester) async {
    await _pumpScreen(tester, FakeTextRecognizer.unsupported());

    expect(find.text(scannerUnsupportedLine), findsOneWidget);
    expect(find.text('Take a photo'), findsNothing);
    expect(find.text('Choose a photo'), findsNothing);
  });
}
