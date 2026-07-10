import 'package:lootlog/data/ocr/receipt_parse.dart';
import 'package:lootlog/features/ocr/ocr_confirm_view.dart';
import 'package:lootlog/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../charge_fixtures.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: child,
    );

ReceiptScan _scan() => ReceiptScan(
      candidateTotals: const [
        AmountCandidate(amountCents: 3888, sourceLine: 'TOTAL 38.88', score: 200),
      ],
      candidateDate: DateTime(2026, 3, 15),
      merchantGuess: 'Trattoria Roma',
    );

void main() {
  testWidgets('confirm requires a target and prefills from the scan',
      (tester) async {
    // A tall viewport so the (lazily built) charge chips are all laid out.
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    OcrConfirmResult? result;
    await tester.pumpWidget(_host(OcrConfirmView(
      groups: sampleChargeGroups(),
      scan: _scan(),
      now: DateTime(2026, 7, 4, 9),
      onConfirm: (r) => result = r,
    )));
    await tester.pumpAndSettle();

    // Amount is prefilled from the best candidate total.
    expect(find.text('\$38.88'), findsOneWidget);
    // Merchant is prefilled.
    expect(find.widgetWithText(TextField, 'Trattoria Roma'), findsOneWidget);

    // Confirm is disabled until a charge target is picked.
    final confirm = find.widgetWithText(FilledButton, 'Pick where it goes');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.ensureVisible(find.text('Food'));
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm expense'));
    expect(result, isNotNull);
    expect(result!.amountCents, 3888);
    expect(result!.merchant, 'Trattoria Roma');
  });

  testWidgets('ocr confirm golden (phone)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(OcrConfirmView(
      groups: sampleChargeGroups(),
      scan: _scan(),
      now: DateTime(2026, 7, 4, 9),
      onConfirm: (_) {},
    )));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OcrConfirmView),
      matchesGoldenFile('goldens/ocr_confirm.png'),
    );
  });
}
