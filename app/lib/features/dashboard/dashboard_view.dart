/// The status dashboard: a pure widget rendering a [DashboardModel] into cards.
/// It owns no state and reads no providers, so it is golden-testable at any size.
/// The screen wrapper supplies the model, activity items, sync status, and the
/// action callbacks.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/progress_ring.dart';
import '../activity/activity_model.dart';
import '../activity/activity_view.dart';
import '../spoils/spoils_model.dart';
import '../sync/sync_status.dart';
import 'dashboard_model.dart';

/// Callbacks the dashboard needs; defaulted to no-ops so goldens can omit them.
class DashboardCallbacks {
  const DashboardCallbacks({
    this.onOpenSpoils,
    this.onApproveWithdrawal,
    this.onCancelWithdrawal,
  });

  final VoidCallback? onOpenSpoils;
  final void Function(String proposalId)? onApproveWithdrawal;
  final void Function(String proposalId)? onCancelWithdrawal;
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: [
        _header(context),
        if (model.spoils != null) ...[
          const SizedBox(height: AppSpacing.md),
          _SpoilsBanner(
            ritual: model.spoils!,
            onOpen: callbacks.onOpenSpoils,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _SlicesCard(rings: model.slices),
        const SizedBox(height: AppSpacing.md),
        _VaultCard(vault: model.vault, meName: model.meName),
        const SizedBox(height: AppSpacing.md),
        _TimelineCard(timeline: model.timeline),
        if (model.quests.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _QuestsCard(quests: model.quests),
        ],
        const SizedBox(height: AppSpacing.md),
        _WarChestCard(card: model.warChest, callbacks: callbacks),
        if (model.maintenance.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _MaintenanceCard(items: model.maintenance),
        ],
        if (model.emergencyFunds.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _EmergencyFundsCard(funds: model.emergencyFunds),
        ],
        if (showActivity && activityItems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: ActivityFeedView(
              items: activityItems,
              padding: EdgeInsets.zero,
              header: true,
              embedded: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            monthLabel(model.currentMonth.year, model.currentMonth.month),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        SyncStatusIndicator(status: syncStatus),
      ],
    );
  }
}

/// A shared card container matching the app's rounded-surface language.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLow,
        borderRadius: AppRadii.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
  }
}

Widget _cardTitle(BuildContext context, String text, {Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(child: Text(text, style: AppText.sectionLabel(context))),
        ?trailing,
      ],
    ),
  );
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
      if (slices > 0) '$slices slice${slices == 1 ? '' : 's'} to divide',
      if (tallies > 0) '$tallies to tally',
    ];
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: AppRadii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: scheme.onTertiaryContainer),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Divide the spoils',
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
        ),
      ),
    );
  }
}

class _SlicesCard extends StatelessWidget {
  const _SlicesCard({required this.rings});

  final List<SliceRing> rings;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, 'Budgets'),
          if (rings.isEmpty)
            Text(
              'No budgets yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: [for (final r in rings) _SliceRingTile(ring: r)],
            ),
        ],
      ),
    );
  }
}

class _SliceRingTile extends StatelessWidget {
  const _SliceRingTile({required this.ring});

  final SliceRing ring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ringColor = ring.overspent
        ? scheme.error
        : (ring.isGroup
            ? scheme.tertiary
            : (ring.mine ? scheme.primary : scheme.secondary));
    final subtitle = ring.isGroup
        ? 'Joint'
        : (ring.petName ?? ring.ownerName ?? '');
    return SizedBox(
      width: 104,
      child: Column(
        children: [
          ProgressRing(
            fraction: ring.fraction,
            color: ringColor,
            trackColor: scheme.surfaceContainerHighest,
            overspent: ring.overspent,
            overColor: scheme.error,
            size: 72,
            center: Text(
              ring.overspent ? '!' : '${ring.pctSpent}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ring.overspent ? scheme.error : scheme.onSurface,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ring.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            '${money(ring.remainingCents)} left',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (subtitle.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.xxs),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: ring.isGroup
                    ? scheme.tertiaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: AppRadii.chip,
              ),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ring.isGroup
                          ? scheme.onTertiaryContainer
                          : scheme.onSurfaceVariant,
                    ),
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
    return _Card(
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
                'Projected spoils this month: '
                '${signedMoney(vault.projectedVaultCents)} to vault '
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
    final scheme = Theme.of(context).colorScheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            context,
            'Spend this month',
            trailing: Text(
              money(timeline.totalCents),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
          SizedBox(
            height: 120,
            child: timeline.isEmpty
                ? Center(
                    child: Text(
                      'Nothing spent yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
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
                final show = day == 1 ||
                    day == timeline.daysInMonth ||
                    day % 7 == 0;
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
  const _QuestsCard({required this.quests});

  final List<QuestCard> quests;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, 'Quests'),
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
            Text(
              '${money(quest.totalContributedCents)} / ${money(quest.targetCents)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: quest.progress,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            color: quest.completed ? scheme.primary : scheme.tertiary,
          ),
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
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'War chest',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                money(card.balanceCents),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          if (card.hasGoal) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (card.pctComplete ?? 0).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: scheme.primary,
              ),
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
        border: needsMe
            ? Border.all(color: scheme.primary, width: 1.5)
            : null,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: callbacks.onCancelWithdrawal == null
                        ? null
                        : () => callbacks.onCancelWithdrawal!(card.proposalId),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.items});

  final List<MaintenanceItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, 'Equipment maintenance'),
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
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
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
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, 'Reserve caches'),
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
