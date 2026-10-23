part of '../dashboard_view.dart';

/// The month hero: the headline income / spent / remaining figures, plus the
/// month label, sync status, and report shortcut.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.model,
    required this.syncStatus,
    this.onOpenReport,
  });

  final DashboardModel model;
  final SyncStatus syncStatus;
  final VoidCallback? onOpenReport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hero = model.hero;
    final over = hero.overBudget;
    final bigColor = over
        ? scheme.error
        : (hero.hasIncome ? scheme.onSurface : scheme.onSurface);
    final bigLabel = hero.hasIncome ? 'REMAINING THIS MONTH' : 'SPENT THIS MONTH';
    final bigCents = hero.hasIncome ? hero.remainingCents : hero.spentCents;

    return AppCard(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthLabel(model.currentMonth.year, model.currentMonth.month),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (onOpenReport != null)
                IconButton(
                  tooltip: 'Monthly report',
                  visualDensity: VisualDensity.compact,
                  onPressed: onOpenReport,
                  icon: const Icon(Icons.pie_chart_outline),
                ),
              SyncStatusIndicator(status: syncStatus),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(bigLabel, style: AppText.metricLabel(context)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            over ? '-${money(-bigCents)}' : money(bigCents),
            style: AppText.heroAmount(context).copyWith(color: bigColor),
          ),
          if (hero.hasIncome) ...[
            const SizedBox(height: AppSpacing.md),
            _ProportionBar(
              fraction: hero.spentFraction,
              fill: over ? scheme.error : scheme.primary,
              track: scheme.surfaceContainerHighest,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    label: 'INCOME',
                    value: money(hero.incomeCents),
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _HeroMetric(
                    label: 'SPENT',
                    value: money(hero.spentCents),
                    color: over ? scheme.error : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add your income to see what’s left to spend this month.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.metricLabel(context)),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.metricValue(context).copyWith(color: color),
        ),
      ],
    );
  }
}

/// A slim rounded proportion bar (spent-of-income, quest progress, …).
class _ProportionBar extends StatelessWidget {
  const _ProportionBar({
    required this.fraction,
    required this.fill,
    required this.track,
    this.height = 10,
  });

  final double fraction;
  final Color fill;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(height: height, color: track),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, opacity, _) => Opacity(
                opacity: opacity,
                child: Container(height: height, color: fill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
