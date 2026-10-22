/// The onboarding bill editor offers a fixed/variable choice: a variable bill
/// is drafted with its estimate, and editing it again keeps the choice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/settings/play_mode.dart';
import 'package:lootlog/features/setup/onboarding_plan.dart';
import 'package:lootlog/features/setup/setup_controller.dart';
import 'package:lootlog/features/setup/setup_screen.dart';
import 'package:lootlog/ui/glossary.dart';

/// Pumps a button that opens the bill editor and records what it returns.
Future<void> _pumpOpener(
  WidgetTester tester,
  SetupController c,
  void Function(DraftFixedExpense?) onResult, {
  DraftFixedExpense? existing,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                onResult(await showExpenseEditor(context, c, existing: existing)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  SetupController seeded({PlayMode mode = PlayMode.standard}) {
    final c = SetupController();
    final a = c.addMember(DraftRole.adult, 'Robin');
    c.setModeFor(a, mode);
    return c;
  }

  testWidgets('choosing "Varies" drafts a variable bill with helper text',
      (tester) async {
    final c = seeded();
    DraftFixedExpense? result;
    await _pumpOpener(tester, c, (e) => result = e);

    final fixedLabel = Glossary.fixedBill.label(isAdventure: false);
    final variableLabel = Glossary.variableBill.label(isAdventure: false);
    expect(find.text(fixedLabel), findsOneWidget);
    expect(find.text(variableLabel), findsOneWidget);
    // Fixed is the default; the variable explanation appears once chosen.
    expect(find.text(Glossary.variableBill.helper), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Hydro');
    await tester.tap(find.text(variableLabel));
    await tester.pumpAndSettle();
    expect(find.text(Glossary.variableBill.helper), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Estimate'), '120');

    await tester.ensureVisible(find.text('Add bill'));
    await tester.tap(find.text('Add bill'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Hydro');
    expect(result!.kind, RecurringKind.variable);
    expect(result!.amountCents, 12000);
  });

  testWidgets('leaving the default drafts a fixed bill', (tester) async {
    final c = seeded();
    DraftFixedExpense? result;
    await _pumpOpener(tester, c, (e) => result = e);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Rent');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '2000');
    await tester.ensureVisible(find.text('Add bill'));
    await tester.tap(find.text('Add bill'));
    await tester.pumpAndSettle();

    expect(result!.kind, RecurringKind.fixed);
    expect(result!.amountCents, 200000);
  });

  testWidgets('editing a variable bill keeps it variable', (tester) async {
    final c = seeded();
    DraftFixedExpense? result;
    await _pumpOpener(
      tester,
      c,
      (e) => result = e,
      existing: const DraftFixedExpense(
        name: 'Hydro',
        shared: true,
        amountCents: 12000,
        kind: RecurringKind.variable,
      ),
    );

    expect(find.text(Glossary.variableBill.helper), findsOneWidget);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result!.kind, RecurringKind.variable);
    expect(result!.amountCents, 12000);
  });

  testWidgets('Adventure players see the flavor labels, even on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = seeded(mode: PlayMode.adventure);
    await _pumpOpener(tester, c, (_) {});
    await tester.tap(find.text(Glossary.variableBill.adventure));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text(Glossary.fixedBill.adventure), findsOneWidget);
    expect(find.text(Glossary.variableBill.adventure), findsOneWidget);
  });
}
