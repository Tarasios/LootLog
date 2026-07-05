/// The partner activity feed widget: a newest-first list of [ActivityItem]s.
/// Pure — takes its items and renders them, so it drops into the dashboard's
/// desktop side pane or the phone's Activity tab unchanged.
library;

import 'package:flutter/material.dart';

import '../../ui/format.dart';
import '../../ui/theme.dart';
import 'activity_model.dart';

class ActivityFeedView extends StatelessWidget {
  const ActivityFeedView({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.header = true,
    this.embedded = false,
  });

  final List<ActivityItem> items;
  final EdgeInsets padding;
  final bool header;

  /// When embedded inside another scrollable (the phone dashboard), the feed
  /// shrink-wraps and does not scroll on its own.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'No activity yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    final children = <Widget>[
      if (header)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text('Activity', style: AppText.sectionLabel(context)),
        ),
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.sm),
        _ActivityTile(item: items[i]),
      ],
    ];
    if (embedded) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
    }
    return ListView(
      padding: padding,
      children: children,
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amount = item.amountCents;
    final positive = amount != null && amount >= 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: item.isMine
              ? scheme.primaryContainer
              : scheme.secondaryContainer,
          child: Icon(
            _iconFor(item.kind),
            size: 16,
            color: item.isMine
                ? scheme.onPrimaryContainer
                : scheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                [
                  isoDay(item.occurredAt),
                  if (item.subtitle != null) item.subtitle,
                ].whereType<String>().join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        if (amount != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            signedMoney(amount),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: positive ? scheme.primary : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ],
    );
  }

  static IconData _iconFor(ActivityKind kind) => switch (kind) {
        ActivityKind.purchase => Icons.shopping_bag_outlined,
        ActivityKind.purchaseVoided => Icons.undo,
        ActivityKind.gift => Icons.card_giftcard,
        ActivityKind.quest => Icons.flag_outlined,
        ActivityKind.allocation => Icons.auto_awesome_outlined,
        ActivityKind.withdrawal => Icons.assignment_outlined,
        ActivityKind.contribution => Icons.account_balance_outlined,
        ActivityKind.taxRefund => Icons.workspace_premium_outlined,
        ActivityKind.income => Icons.inventory_2_outlined,
        ActivityKind.config => Icons.tune,
      };
}
