part of '../dashboard_view.dart';

/// The net-worth summary card: signed total, assets/debts split, and a recorded
/// trend sparkline. Tracked accounts only — never budget money.
class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({required this.summary});

  final NetWorthSummary summary;

  String _signed(int cents) => cents < 0 ? '-${money(-cents)}' : money(cents);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Net worth',
            icon: Icons.trending_up,
            trailing: Text(
              _signed(summary.totalCents),
              style: AppText.metricValue(context).copyWith(
                color: summary.totalCents < 0 ? scheme.error : scheme.onSurface,
              ),
            ),
          ),
          if (!summary.hasAccounts)
            const AppEmptyHint(
              icon: Icons.account_balance_wallet_outlined,
              message: 'Add savings, investment, or debt accounts to track your '
                  'net worth over time.',
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    label: 'ASSETS',
                    value: money(summary.assetsCents),
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _HeroMetric(
                    label: 'DEBTS',
                    value: money(summary.debtsCents),
                    color: summary.debtsCents > 0
                        ? scheme.error
                        : scheme.onSurface,
                  ),
                ),
              ],
            ),
            if (summary.hasHistory) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 56,
                child: _Sparkline(series: summary.series),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.series});

  final List<BalancePoint> series;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rising = series.last.balanceCents >= series.first.balanceCents;
    final line = rising ? scheme.primary : scheme.error;

    final spots = <FlSpot>[
      for (var i = 0; i < series.length; i++)
        FlSpot(i.toDouble(), series[i].balanceCents.toDouble()),
    ];
    var minY = spots.first.y;
    var maxY = spots.first.y;
    for (final spot in spots) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }
    final pad = ((maxY - minY).abs() * 0.15).clamp(100, double.infinity);

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 2.5,
            color: line,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: line.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}
