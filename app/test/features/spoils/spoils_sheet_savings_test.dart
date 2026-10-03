import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/pools.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/spoils/spoils_model.dart';
import 'package:lootlog/features/spoils/spoils_sheet.dart';

void main() {
  final asOf = DateTime.utc(2026, 9, 3, 18);

  SpoilsRitual ritual({TaxedBalance savings = const TaxedBalance(4500, 500)}) =>
      SpoilsRitual(
        month: const Month(2026, 8),
        forUserId: 'u1',
        graceDeadline: asOf.add(const Duration(days: 4)),
        asOf: asOf,
        variableTallies: const [],
        sliceLeftovers: [
          SliceLeftover(
            sliceId: 'clothes',
            name: 'Clothing',
            leftoverCents: 5000,
            poolTithePct: 10,
            defaultPolicy: const CarryInSlice(),
            questOptions: const [],
            generalRatePct: 20,
            savings: savings,
          ),
        ],
        groupFlows: const [],
        emergencyContribs: const [],
      );

  Future<SpoilsResult?> run(WidgetTester tester, SpoilsRitual r,
      Future<void> Function() interact) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SpoilsResult? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpoilsSheetView(ritual: r, onConfirm: (res) => result = res),
      ),
    ));
    await interact();
    await tester.tap(find.text('Confirm the division'));
    await tester.pump();
    return result;
  }

  testWidgets('saving shows the carry tax before confirming; savings stay put',
      (tester) async {
    final result = await run(tester, ritual(), () async {
      expect(find.textContaining(r'$45.00 saved in Clothing'), findsOneWidget);
      expect(find.textContaining(r'$5.00 to shared savings'), findsOneWidget);
      expect(find.textContaining('stays put'), findsOneWidget);
    });
    final lines = result!.allocations.single.allocations;
    expect(lines, hasLength(1));
    expect(lines.single.destination, const CarryInSlice());
    expect(lines.single.source, AllocationSource.allowance);
  });

  testWidgets('general savings previews the general rate', (tester) async {
    await run(tester, ritual(), () async {
      await tester.tap(find.widgetWithText(ChoiceChip, 'General savings').first);
      await tester.pump();
      expect(find.textContaining(r'$40.00 to general savings'), findsWidgets);
    });
  });

  testWidgets('moving savings out pays only the difference', (tester) async {
    final result = await run(tester, ritual(), () async {
      await tester.tap(find.widgetWithText(ChoiceChip, 'Move to general savings'));
      await tester.pump();
      // $45 that already paid $5 tops up to 20%: $5 more, $40 lands.
      expect(find.textContaining(r'Savings: $40.00 to general savings'),
          findsOneWidget);
    });
    final lines = result!.allocations.single.allocations;
    final fromSavings =
        lines.where((a) => a.source == AllocationSource.savings).single;
    expect(fromSavings.destination, const Discretionary());
    expect(fromSavings.amountCents, 4500);
  });

  testWidgets('no savings row when nothing is saved', (tester) async {
    await run(tester, ritual(savings: TaxedBalance.zero), () async {
      expect(find.textContaining('stays put'), findsNothing);
    });
  });
}
