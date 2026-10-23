part of '../dashboard_view.dart';

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
                final item = items[i];
                final soon = item.daysUntilDue <= 7;
                final label = recurringDueLabel(
                  isAnnual: item.isAnnual,
                  dueDay: item.dueDay,
                  dueMonth: item.dueMonth,
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
                            item.isAnnual
                                ? Icons.event_repeat_outlined
                                : Icons.calendar_today_outlined,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        money(item.amountCents),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                      Text(
                        '$label · ${dueCountdown(item.daysUntilDue)}',
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
