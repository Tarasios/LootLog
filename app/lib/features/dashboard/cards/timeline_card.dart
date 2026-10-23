part of '../dashboard_view.dart';

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.timeline});

  final SpendTimeline timeline;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Spend this month',
            icon: Icons.show_chart,
            trailing: Text(
              money(timeline.totalCents),
              style: AppText.metricValue(context),
            ),
          ),
          SizedBox(
            height: 120,
            child: timeline.isEmpty
                ? const AppEmptyHint(
                    icon: Icons.bar_chart_outlined,
                    message: 'Nothing spent yet this month.',
                  )
                : _SpendBarChart(timeline: timeline),
          ),
        ],
      ),
    );
  }
}

class _SpendBarChart extends StatelessWidget {
  const _SpendBarChart({required this.timeline});

  final SpendTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = (timeline.maxDayCents * 1.15).clamp(100, double.infinity);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: maxY.toDouble(),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barTouchData: const BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                final show =
                    day == 1 || day == timeline.daysInMonth || day % 7 == 0;
                if (!show) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '$day',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (final point in timeline.points)
            BarChartGroupData(
              x: point.day,
              barRods: [
                BarChartRodData(
                  toY: point.cents.toDouble(),
                  width: 5,
                  color: scheme.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ],
            ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}
