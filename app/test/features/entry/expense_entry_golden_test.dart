import 'package:lootlog/features/entry/amount_keypad.dart';
import 'package:lootlog/features/entry/expense_entry_view.dart';
import 'package:lootlog/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../charge_fixtures.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: child,
    );

void main() {
  testWidgets('cents-aware keypad shifts digits left', (tester) async {
    var committed = 0;
    await tester.pumpWidget(_host(ExpenseEntryView(
      groups: sampleChargeGroups(),
      now: DateTime(2026, 7, 4, 9),
      onCommit: (d) => committed = d.amountCents,
    )));

    await tester.tap(find.widgetWithText(InkWell, '7'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, '5'));
    await tester.pump();
    expect(find.text('\$0.75'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, '⌫'));
    await tester.pump();
    expect(find.text('\$0.07'), findsOneWidget);

    // Tapping a charge chip commits with the entered amount.
    await tester.ensureVisible(find.text('Food'));
    await tester.tap(find.text('Food'));
    expect(committed, 7);
  });

  testWidgets('entry keypad golden (phone)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(ExpenseEntryView(
      groups: sampleChargeGroups(),
      initialCents: 2450,
      now: DateTime(2026, 7, 4, 9),
      onCommit: (_) {},
    )));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ExpenseEntryView),
      matchesGoldenFile('goldens/entry_keypad.png'),
    );
  });

  testWidgets('applyDigit caps at the max amount', (tester) async {
    expect(applyDigit(kMaxEntryCents, 9), kMaxEntryCents);
    expect(applyBackspace(75), 7);
  });
}
