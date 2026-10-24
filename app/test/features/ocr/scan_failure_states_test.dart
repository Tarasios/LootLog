/// A failed scan says why in plain words on the confirm screen, and the
/// keypad still works: (a) the recognizer threw, (b) it found no text,
/// (c) it found text but no total. Nothing is created without Confirm.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/ocr/text_recognizer.dart';
import 'package:lootlog/features/ocr/ocr_confirm_view.dart';
import 'package:lootlog/ui/theme.dart';

import '../charge_fixtures.dart';
import 'fake_text_recognizer.dart';

Future<ReceiptScanOutcome> _scanWith(FakeTextRecognizer recognizer) =>
    ReceiptOcr(recognizer).scanImageFile('/photos/receipt.jpg');

Future<List<OcrConfirmResult>> _pumpConfirm(
  WidgetTester tester,
  ReceiptScanOutcome outcome,
) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final confirmed = <OcrConfirmResult>[];
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: OcrConfirmView(
      groups: sampleChargeGroups(),
      outcome: outcome,
      now: DateTime(2026, 7, 4, 9),
      onConfirm: confirmed.add,
    ),
  ));
  await tester.pumpAndSettle();
  return confirmed;
}

/// Types $12.34 on the keypad, picks Food, and confirms.
Future<void> _typeAmountAndConfirm(WidgetTester tester) async {
  for (final digit in ['1', '2', '3', '4']) {
    await tester.tap(find.text(digit).first);
    await tester.pump();
  }
  await tester.ensureVisible(find.text('Food'));
  await tester.tap(find.text('Food'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Confirm expense'));
  await tester.pump();
}

void main() {
  testWidgets('(a) a recognizer error shows its short reason', (tester) async {
    final outcome = await tester.runAsync(() => _scanWith(
          FakeTextRecognizer.throwing(PlatformException(
            code: 'MLKitTextRecognizer',
            message: 'Failed to load the text model',
          )),
        ));
    final confirmed = await _pumpConfirm(tester, outcome!);

    expect(
      find.text("The scanner couldn't run (MLKitTextRecognizer: Failed to "
          'load the text model) — enter the amount below'),
      findsOneWidget,
    );
    expect(find.text('\$0.00'), findsOneWidget);
    expect(confirmed, isEmpty, reason: 'nothing is created without Confirm');

    await _typeAmountAndConfirm(tester);
    expect(confirmed.single.amountCents, 1234);
  });

  testWidgets('(b) no text found says so', (tester) async {
    final outcome =
        await tester.runAsync(() => _scanWith(FakeTextRecognizer.returning([])));
    final confirmed = await _pumpConfirm(tester, outcome!);

    expect(find.text('No text found in the photo — enter the amount below'),
        findsOneWidget);

    await _typeAmountAndConfirm(tester);
    expect(confirmed.single.amountCents, 1234);
  });

  testWidgets('(c) text without a total says so and keeps the merchant',
      (tester) async {
    final outcome = await tester.runAsync(() => _scanWith(
          FakeTextRecognizer.returning(['CORNER MARKET', 'Thank you!']),
        ));
    final confirmed = await _pumpConfirm(tester, outcome!);

    expect(find.text('Found text but no total — enter the amount below'),
        findsOneWidget);
    expect(find.widgetWithText(TextField, 'CORNER MARKET'), findsOneWidget);

    await _typeAmountAndConfirm(tester);
    expect(confirmed.single.amountCents, 1234);
    expect(confirmed.single.merchant, 'CORNER MARKET');
  });

  testWidgets('a readable total prefills and says to check it',
      (tester) async {
    final outcome = await tester.runAsync(() => _scanWith(
          FakeTextRecognizer.returning(['CORNER MARKET', 'TOTAL 14.70']),
        ));
    await _pumpConfirm(tester, outcome!);

    expect(find.text('Scanned — check the amount before saving'),
        findsOneWidget);
    expect(find.text('\$14.70'), findsOneWidget);
  });

  testWidgets('off Android the screen says scanning runs on Android',
      (tester) async {
    final recognizer = FakeTextRecognizer.unsupported();
    final outcome = await tester.runAsync(() => _scanWith(recognizer));
    await _pumpConfirm(tester, outcome!);

    expect(find.text('Scanning runs on Android — enter the amount below'),
        findsOneWidget);
    expect(recognizer.requestedPaths, isEmpty);
  });
}
