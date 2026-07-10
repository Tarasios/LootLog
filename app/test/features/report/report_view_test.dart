import 'package:lootlog/domain/report.dart';
import 'package:lootlog/domain/state.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/features/report/report_view.dart';
import 'package:lootlog/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MonthReport _report() => const MonthReport(
      month: Month(2026, 1),
      userId: null,
      categories: [
        ReportCategoryRow(
          categoryId: 'groceries',
          name: 'Groceries',
          mainCategoryId: 'food',
          isGroup: false,
          ownerUserId: 'u1',
          budgetedCents: 40000,
          spentCents: 15000,
          leftoverCents: 25000,
        ),
        ReportCategoryRow(
          categoryId: 'bus',
          name: 'Bus',
          mainCategoryId: 'transport',
          isGroup: false,
          ownerUserId: 'u1',
          budgetedCents: 10000,
          spentCents: 12000,
          leftoverCents: 0,
        ),
      ],
      byMainCategory: [
        MainCategorySpend(
          mainCategory:
              MainCategory(id: 'food', name: 'Food', colorArgb: 0xFFF28E2B, sortOrder: 1),
          spentCents: 15000,
        ),
        MainCategorySpend(
          mainCategory: MainCategory(
              id: 'transport', name: 'Transport', colorArgb: 0xFFE15759, sortOrder: 2),
          spentCents: 12000,
        ),
      ],
    );

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders the legend, table rows, and totals', (tester) async {
    await tester.pumpWidget(_host(ReportView(
      report: _report(),
      monthLabel: 'January 2026',
      scopes: const [
        ReportScope(userId: null, label: 'Household'),
        ReportScope(userId: 'u1', label: 'Alex'),
      ],
    )));
    await tester.pumpAndSettle();

    // Pie legend + table both name the main/budget categories.
    expect(find.text('Spend by main category'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);

    // Totals: budgeted 500.00, spent 270.00, leftover 250.00 (the last also
    // appears on the Groceries row, whose leftover happens to equal the total).
    expect(find.text('Total'), findsOneWidget);
    expect(find.text(r'$500.00'), findsOneWidget);
    expect(find.text(r'$270.00'), findsOneWidget);
    expect(find.text(r'$250.00'), findsNWidgets(2));
  });

  testWidgets('shows an empty state when nothing was spent', (tester) async {
    await tester.pumpWidget(_host(ReportView(
      report: const MonthReport(
        month: Month(2026, 1),
        userId: null,
        categories: [],
        byMainCategory: [],
      ),
      monthLabel: 'January 2026',
    )));
    await tester.pumpAndSettle();

    expect(find.text('No spending recorded this month.'), findsOneWidget);
    expect(find.text('No categories yet.'), findsOneWidget);
  });
}
