/// The status dashboard: a pure widget rendering a [DashboardModel] into a
/// designed set of cards. It owns no state and reads no providers, so it is
/// golden-testable at any size. The screen wrapper supplies the model, activity
/// items, sync status, and the action callbacks.
///
/// Layout is responsive: on a phone-width viewport it is one scrolling column;
/// past [kDashboardWideBreakpoint] the month hero spans the top and the
/// remaining cards split into a primary/secondary two-column grid.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../ui/category_palette.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/app_card.dart';
import '../../ui/widgets/progress_ring.dart';
import '../activity/activity_model.dart';
import '../activity/activity_view.dart';
import '../networth/networth_model.dart';
import '../spoils/spoils_model.dart';
import '../sync/sync_status.dart';
import 'dashboard_model.dart';

/// At or above this width the dashboard becomes a two-column grid.
const double kDashboardWideBreakpoint = 720;

/// Callbacks the dashboard needs; defaulted to no-ops so goldens can omit them.
class DashboardCallbacks {
  const DashboardCallbacks({
    this.onOpenSpoils,
    this.onOpenReport,
    this.onApproveWithdrawal,
    this.onCancelWithdrawal,
    this.onGetStarted,
    this.onNewGoal,
  });

  final VoidCallback? onOpenSpoils;

  /// Opens the monthly spend report. Null in goldens (button hidden).
  final VoidCallback? onOpenReport;
  final void Function(String proposalId)? onApproveWithdrawal;
  final void Function(String proposalId)? onCancelWithdrawal;

  /// Opens budget setup from the new-household empty state.
  final VoidCallback? onGetStarted;

  /// Opens the new savings-goal editor. Null in goldens (button hidden).
  final VoidCallback? onNewGoal;
}

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.model,
    this.activityItems = const [],
    this.syncStatus = SyncStatus.localOnly,
    this.showActivity = true,
    this.callbacks = const DashboardCallbacks(),
  });

  final DashboardModel model;
  final List<ActivityItem> activityItems;
  final SyncStatus syncStatus;

  /// On desktop the activity feed lives in its own pane, so the dashboard omits
  /// the inline activity section.
  final bool showActivity;
  final DashboardCallbacks callbacks;

  /// A household with no slices and no quests has never been set up.
  bool get _isNewHousehold => model.slices.isEmpty && model.quests.isEmpty;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kDashboardWideBreakpoint;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          children: wide ? _wide(context) : _narrow(context),
        );
      },
    );
  }

  // ---- Section builders --------------------------------------------------

  Widget _hero(BuildContext context) => _HeroCard(
        model: model,
        syncStatus: syncStatus,
        onOpenReport: callbacks.onOpenReport,
      );

  List<Widget> _topFullWidth(BuildContext context) => [
        if (_isNewHousehold) _GetStartedCard(onGetStarted: callbacks.onGetStarted),
        if (model.spoils != null)
          _SpoilsBanner(ritual: model.spoils!, onOpen: callbacks.onOpenSpoils),
      ];

  /// The primary column: what you spend and what's coming.
  List<Widget> _primary(BuildContext context) => [
        _CategoriesCard(rings: model.slices),
        _TimelineCard(timeline: model.timeline),
        if (model.upcoming.isNotEmpty) _UpcomingCard(items: model.upcoming),
      ];

  /// The secondary column: goals, pouches, and reserves.
  List<Widget> _secondary(BuildContext context) => [
        _QuestsCard(quests: model.quests, onNewGoal: callbacks.onNewGoal),
        _VaultCard(vault: model.vault, meName: model.meName),
        _WarChestCard(card: model.warChest, callbacks: callbacks),
        if (model.netWorth.show) _NetWorthCard(summary: model.netWorth),
        if (model.maintenance.isNotEmpty) _MaintenanceCard(items: model.maintenance),
        if (model.emergencyFunds.isNotEmpty)
          _EmergencyFundsCard(funds: model.emergencyFunds),
      ];

  List<Widget> _activity(BuildContext context) => [
        if (showActivity && activityItems.isNotEmpty)
          AppCard(
            child: ActivityFeedView(
              items: activityItems,
              padding: EdgeInsets.zero,
              header: true,
              embedded: true,
            ),
          ),
      ];

  // ---- Narrow (phone): one column ---------------------------------------
  List<Widget> _narrow(BuildContext context) {
    return _gap([
      _hero(context),
      ..._topFullWidth(context),
      ..._primary(context),
      ..._secondary(context),
      ..._activity(context),
    ]);
  }

  // ---- Wide (desktop): hero on top, two columns below -------------------
  List<Widget> _wide(BuildContext context) {
    return _gap([
      _hero(context),
      ..._topFullWidth(context),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(children: _gap(_primary(context))),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Column(
              children: _gap([..._secondary(context), ..._activity(context)]),
            ),
          ),
        ],
      ),
    ]);
  }
}

/// Inserts a uniform vertical gap between a list of stacked cards.
List<Widget> _gap(List<Widget> children) {
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) out.add(const SizedBox(height: AppSpacing.md));
    out.add(children[i]);
  }
  return out;
}

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
              builder: (context, t, _) => Opacity(
                opacity: t,
                child: Container(height: height, color: fill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The new-household empty state: a warm, single-call-to-action card shown when
/// no budgets or quests exist yet.
class _GetStartedCard extends StatelessWidget {
  const _GetStartedCard({this.onGetStarted});

  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rocket_launch_outlined, color: scheme.onPrimaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Welcome to your household',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Start by carving your monthly budget into categories — one each for '
            'the household’s adults, plus shared ones like groceries. Everything '
            'else (quests, the war chest, receipts) builds from there.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onGetStarted,
            icon: const Icon(Icons.tune),
            label: const Text('Set up budgets'),
          ),
        ],
      ),
    );
  }
}

class _SpoilsBanner extends StatelessWidget {
  const _SpoilsBanner({required this.ritual, this.onOpen});

  final SpoilsRitual ritual;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = ritual.daysRemaining;
    final slices = ritual.sliceLeftovers.length;
    final tallies = ritual.variableTallies.length;
    final parts = <String>[
      if (slices > 0) '$slices categor${slices == 1 ? 'y' : 'ies'} to divide',
      if (tallies > 0) '$tallies to tally',
    ];
    return AppCard(
      color: scheme.tertiaryContainer,
      onTap: onOpen,
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: scheme.onTertiaryContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Divide monthly leftovers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  [
                    parts.join(' · '),
                    'defaults in ${days}d',
                  ].where((s) => s.isNotEmpty).join(' — '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
        ],
      ),
    );
  }
}

/// The colour-coded category grid: one tile per budget category, tinted by its
/// main-category colour with an animated consumption ring.
class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({required this.rings});

  final List<SliceRing> rings;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'Budgets', icon: Icons.category_outlined),
          if (rings.isEmpty)
            const AppEmptyHint(
              icon: Icons.donut_large_outlined,
              message: 'No budgets yet — set one up to start tracking spend.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const target = 168.0;
                final cols =
                    (constraints.maxWidth / target).floor().clamp(1, 4);
                const spacing = AppSpacing.sm;
                final tileWidth =
                    (constraints.maxWidth - spacing * (cols - 1)) / cols;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final r in rings)
                      SizedBox(
                        width: tileWidth,
                        child: _CategoryTile(ring: r),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.ring});

  final SliceRing ring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    // A category without a main category falls back to a semantic role so the
    // tile still reads as one of the coloured set.
    final fallback = ring.isGroup
        ? scheme.tertiary
        : (ring.mine ? scheme.primary : scheme.secondary);
    final colors = categoryColorsFor(
      ring.mainCategoryColorArgb,
      brightness,
      fallback: fallback,
    );
    final ringColor = ring.overspent ? scheme.error : colors.accent;
    final subtitle = ring.isGroup
        ? 'Joint'
        : (ring.petName ?? ring.ownerName ?? '');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadii.card,
      ),
      child: Row(
        children: [
          ProgressRing(
            fraction: ring.fraction,
            color: ringColor,
            trackColor: colors.track,
            overspent: ring.overspent,
            overColor: scheme.error,
            size: 46,
            strokeWidth: 5,
            center: Text(
              ring.overspent ? '!' : '${ring.pctSpent}%',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ring.overspent ? scheme.error : colors.onContainer,
                  ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ring.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onContainer,
                      ),
                ),
                Text(
                  ring.overspent
                      ? '${money(ring.overspendCents)} over'
                      : '${money(ring.remainingCents)} left',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ring.overspent
                            ? scheme.error
                            : colors.onContainer.withValues(alpha: 0.8),
                        fontWeight:
                            ring.overspent ? FontWeight.w700 : FontWeight.w400,
                      ),
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.onContainer.withValues(alpha: 0.7),
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({required this.vault, required this.meName});

  final VaultCard vault;
  final String meName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined, color: scheme.onSecondaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$meName’s vault',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            money(vault.balanceCents),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          if (vault.inconsistent)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Balance clamped at zero — check recent charges',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ),
          if (vault.projectedLeftoverCents > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Projected leftover this month: '
                '${signedMoney(vault.projectedVaultCents)} to personal spending '
                '(${money(vault.projectedLeftoverCents)} leftover at current spend)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

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
          for (final p in timeline.points)
            BarChartGroupData(
              x: p.day,
              barRods: [
                BarChartRodData(
                  toY: p.cents.toDouble(),
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

class _QuestsCard extends StatelessWidget {
  const _QuestsCard({required this.quests, this.onNewGoal});

  final List<QuestCard> quests;
  final VoidCallback? onNewGoal;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Savings goals',
            icon: Icons.flag_outlined,
            trailing: onNewGoal == null
                ? null
                : TextButton.icon(
                    onPressed: onNewGoal,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New goal'),
                  ),
          ),
          if (quests.isEmpty)
            const AppEmptyHint(
              icon: Icons.flag_outlined,
              message: 'No savings goals yet. Set a target for something you’re '
                  'saving toward and fund it from your leftovers at month close.',
            )
          else
            for (var i = 0; i < quests.length; i++) ...[
              if (i > 0) const Divider(),
              _QuestTile(quest: quests[i]),
            ],
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest});

  final QuestCard quest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      quest.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (quest.isShared)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: _tag(context, 'Shared'),
                    ),
                  if (quest.completed)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                '${money(quest.totalContributedCents)} / ${money(quest.targetCents)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _ProportionBar(
          fraction: quest.progress,
          fill: quest.completed ? scheme.primary : scheme.tertiary,
          track: scheme.surfaceContainerHighest,
          height: 8,
        ),
        if (quest.isShared && quest.contributors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              quest.contributors
                  .map((c) => '${c.name} ${money(c.cents)}')
                  .join('  ·  '),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }
}

Widget _tag(BuildContext context, String text) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 1),
    decoration: BoxDecoration(
      color: scheme.tertiaryContainer,
      borderRadius: AppRadii.chip,
    ),
    child: Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(color: scheme.onTertiaryContainer),
    ),
  );
}

class _WarChestCard extends StatelessWidget {
  const _WarChestCard({required this.card, required this.callbacks});

  final WarChestCard card;
  final DashboardCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'War chest',
            icon: Icons.account_balance,
            iconColor: scheme.primary,
            trailing: Text(
              money(card.balanceCents),
              style: AppText.metricValue(context),
            ),
          ),
          if (card.hasGoal) ...[
            _ProportionBar(
              fraction: (card.pctComplete ?? 0).clamp(0.0, 1.0),
              fill: scheme.primary,
              track: scheme.surfaceContainerHighest,
              height: 8,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                '${((card.pctComplete ?? 0) * 100).round()}% of ${money(card.targetCents!)}',
                if (card.monthsToGo != null)
                  'about ${card.monthsToGo} month${card.monthsToGo == 1 ? '' : 's'} to go',
              ].join(' · '),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          for (final w in card.pendingForMe) ...[
            const SizedBox(height: AppSpacing.md),
            _WithdrawalTile(card: w, callbacks: callbacks, needsMe: true),
          ],
          for (final w in card.otherPending) ...[
            const SizedBox(height: AppSpacing.md),
            _WithdrawalTile(card: w, callbacks: callbacks, needsMe: false),
          ],
          for (final r in card.ransacks) ...[
            const SizedBox(height: AppSpacing.md),
            _RansackTile(ransack: r),
          ],
        ],
      ),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({
    required this.card,
    required this.callbacks,
    required this.needsMe,
  });

  final WithdrawalCard card;
  final DashboardCallbacks callbacks;
  final bool needsMe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: needsMe ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
        border: needsMe ? Border.all(color: scheme.primary, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 18,
                color: needsMe ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  needsMe
                      ? 'Writ awaiting your signature'
                      : 'Writ awaiting the other signature',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: needsMe
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                ),
              ),
              Text(
                money(card.amountCents),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: needsMe
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              '${card.byUserName} · ${card.purpose} → ${card.destinationLabel}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: needsMe
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (needsMe)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  TextButton(
                    onPressed: callbacks.onCancelWithdrawal == null
                        ? null
                        : () => callbacks.onCancelWithdrawal!(card.proposalId),
                    child: const Text('Decline'),
                  ),
                  FilledButton(
                    onPressed: callbacks.onApproveWithdrawal == null
                        ? null
                        : () => callbacks.onApproveWithdrawal!(card.proposalId),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 40),
                    ),
                    child: const Text('Sign'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RansackTile extends StatelessWidget {
  const _RansackTile({required this.ransack});

  final RansackCard ransack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadii.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The war chest was ransacked',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onErrorContainer,
                      ),
                ),
                Text(
                  '${money(ransack.excessCents)} for ${ransack.fundName}'
                  '${ransack.purpose.isEmpty ? '' : ' · ${ransack.purpose}'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    for (final s in spots) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
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

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.items});

  final List<UpcomingPayment> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Upcoming payments',
            icon: Icons.event_outlined,
          ),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final p = items[i];
                final soon = p.daysUntilDue <= 7;
                final label = recurringDueLabel(
                  isAnnual: p.isAnnual,
                  dueDay: p.dueDay,
                  dueMonth: p.dueMonth,
                );
                return Container(
                  width: 148,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: soon
                        ? scheme.tertiaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: AppRadii.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            p.isAnnual
                                ? Icons.event_repeat_outlined
                                : Icons.calendar_today_outlined,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        money(p.amountCents),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                      Text(
                        '$label · ${dueCountdown(p.daysUntilDue)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: soon
                                  ? scheme.onTertiaryContainer
                                  : scheme.onSurfaceVariant,
                              fontWeight:
                                  soon ? FontWeight.w600 : FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.items});

  final List<MaintenanceItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Equipment maintenance',
            icon: Icons.build_outlined,
          ),
          for (final m in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    m.isShared ? Icons.groups_outlined : Icons.person_outline,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          [
                            m.isVariable ? 'Variable' : 'Fixed',
                            if (m.isShared)
                              'shared'
                            else if (m.ownerName != null)
                              m.ownerName!,
                          ].join(' · '),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (m.awaitingTally)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: AppRadii.chip,
                      ),
                      child: Text(
                        'Awaiting tally',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onTertiaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    )
                  else
                    Text(
                      money(m.amountCents),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmergencyFundsCard extends StatelessWidget {
  const _EmergencyFundsCard({required this.funds});

  final List<EmergencyFundCard> funds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Reserve caches',
            icon: Icons.shield_outlined,
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final f in funds)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: AppRadii.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emergency_outlined,
                              size: 16, color: scheme.error),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            f.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        money(f.balanceCents),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                      if (f.petName != null)
                        Text(
                          f.petName!,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
