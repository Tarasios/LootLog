part of '../dashboard_view.dart';

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
          AppSectionHeader(
            title: _plain(Glossary.recurring),
            icon: Icons.build_outlined,
          ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    item.isShared ? Icons.groups_outlined : Icons.person_outline,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          [
                            item.isVariable ? 'Variable' : 'Fixed',
                            if (item.isShared)
                              'shared'
                            else if (item.ownerName != null)
                              item.ownerName!,
                          ].join(' · '),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (item.awaitingTally)
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
                      money(item.amountCents),
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
