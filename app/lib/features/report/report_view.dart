/// The pure month-report widget: a pie of spend by main category (coloured by
/// each main category's colour) with a household / per-adult scope toggle, plus
/// a budgeted/spent/leftover table. It owns no state and reads no providers, so
/// it is golden-testable at any size. [ReportScreen] supplies the data and the
/// month/scope callbacks.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/report.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';

/// One selectable scope in the toggle: the household, or a single adult.
class ReportScope {
  const ReportScope({required this.userId, required this.label});

  /// null = whole household.
  final String? userId;
  final String label;
}

class ReportView extends StatelessWidget {
  const ReportView({
    super.key,
    required this.report,
    required this.monthLabel,
    this.scopes = const [],
    this.onPrevMonth,
    this.onNextMonth,
    this.onScopeChanged,
  });

  final MonthReport report;
  final String monthLabel;

  /// Scope options; when fewer than two, the toggle is hidden.
  final List<ReportScope> scopes;
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;
  final void Function(String? userId)? onScopeChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _monthSelector(context),
        const SizedBox(height: AppSpacing.md),
        if (scopes.length > 1) ...[
          _scopeSelector(context),
          const SizedBox(height: AppSpacing.lg),
        ],
        _PieCard(report: report),
        const SizedBox(height: AppSpacing.md),
        _TableCard(report: report),
      ],
    );
  }

  Widget _monthSelector(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPrevMonth,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(monthLabel, style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          onPressed: onNextMonth,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _scopeSelector(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String?>(
        segments: [
          for (final s in scopes)
            ButtonSegment<String?>(value: s.userId, label: Text(s.label)),
        ],
        selected: {report.userId},
        showSelectedIcon: false,
        onSelectionChanged:
            onScopeChanged == null ? null : (s) => onScopeChanged!(s.first),
      ),
    );
  }
}

/// The spend-by-main-category pie plus a colour legend.
class _PieCard extends StatelessWidget {
  const _PieCard({required this.report});

  final MonthReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slices = report.byMainCategory;
    final total = report.totalSpentCents;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Spend by main category',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            if (slices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Text(
                  'No spending recorded this month.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              )
            else ...[
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 48,
                    sections: [
                      for (final s in slices)
                        PieChartSectionData(
                          value: s.spentCents.toDouble(),
                          color: Color(s.colorArgb),
                          title: total == 0
                              ? ''
                              : '${(s.spentCents * 100 / total).round()}%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          radius: 56,
                        ),
                    ],
                  ),
                  duration: Duration.zero,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Color(s.colorArgb),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(s.name)),
                      Text(money(s.spentCents),
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The budgeted / spent / leftover table across every category in scope.
class _TableCard extends StatelessWidget {
  const _TableCard({required this.report});

  final MonthReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = report.categories;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Budgeted, spent, leftover',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('No categories yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
              )
            else
              _table(context, rows),
          ],
        ),
      ),
    );
  }

  Widget _table(BuildContext context, List<ReportCategoryRow> rows) {
    final labelStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            Text('Category', style: labelStyle),
            _num(context, 'Budget', header: true),
            _num(context, 'Spent', header: true),
            _num(context, 'Left', header: true),
          ],
        ),
        for (final r in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(r.name),
              ),
              _num(context, money(r.budgetedCents)),
              _num(context, money(r.spentCents),
                  color: r.overspent
                      ? Theme.of(context).colorScheme.error
                      : null),
              _num(context, money(r.leftoverCents)),
            ],
          ),
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          children: [
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text('Total',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            _num(context, money(report.totalBudgetedCents), bold: true),
            _num(context, money(report.totalSpentCents), bold: true),
            _num(context, money(report.totalLeftoverCents), bold: true),
          ],
        ),
      ],
    );
  }

  Widget _num(BuildContext context, String text,
      {bool header = false, bool bold = false, Color? color}) {
    final base = header
        ? Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: base?.copyWith(
          fontWeight: bold ? FontWeight.w700 : null,
          color: color,
        ),
      ),
    );
  }
}
