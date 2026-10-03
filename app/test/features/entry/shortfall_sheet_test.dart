import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/features/entry/shortfall.dart';
import 'package:lootlog/features/entry/shortfall_sheet.dart';

void main() {
  Future<ShortfallChoice?> open(WidgetTester tester, ShortfallOptions o,
      Future<void> Function() interact) async {
    ShortfallChoice? result;
    var closed = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showShortfallSheet(context, o);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await interact();
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    return result;
  }

  const categoryShort = ShortfallOptions(
    shortCents: 5000,
    generalAvailableCents: 10000,
    savingsSources: [],
    canBorrow: true,
    sliceId: 'clothes',
    sliceName: 'Clothing',
  );

  testWidgets('general savings is pre-selected when it covers the gap',
      (tester) async {
    final choice = await open(tester, categoryShort, () async {
      expect(find.textContaining(r'$50.00 short'), findsOneWidget);
      await tester.tap(find.text('Cover it'));
    });
    expect(choice, isA<CoverFromGeneral>());
    expect((choice! as CoverFromGeneral).amountCents, 5000);
  });

  testWidgets('borrowing carries the chosen number of months', (tester) async {
    final choice = await open(tester, categoryShort, () async {
      await tester.tap(find.text('Borrow from future Clothing months'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More months'));
      await tester.pump();
      await tester.tap(find.text('Cover it'));
    });
    expect((choice! as BorrowAhead).months, 2);
  });

  testWidgets('leaving it records nothing', (tester) async {
    final choice = await open(tester, categoryShort, () async {
      await tester.tap(find.text('Leave it as overspending'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cover it'));
    });
    expect(choice, isA<LeaveIt>());
  });

  testWidgets('a goal purchase can be topped up from category savings',
      (tester) async {
    const goal = ShortfallOptions(
      shortCents: 2000,
      generalAvailableCents: 0,
      savingsSources: [
        SavingsSource(
          sliceId: 'clothes',
          name: 'Clothing',
          balanceCents: 4500,
          moveCents: 2223,
          taxCents: 223,
          deliveredCents: 2000,
        ),
      ],
      canBorrow: false,
      questId: 'canoe',
    );
    final choice = await open(tester, goal, () async {
      expect(find.textContaining(r'$2.23 to shared savings'), findsOneWidget);
      await tester.tap(find.text('From Clothing savings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cover it'));
    });
    final s = choice! as CoverFromSavings;
    expect(s.sliceId, 'clothes');
    expect(s.moveCents, 2223);
  });
}
