part of '../adventure_dashboard.dart';

// ===========================================================================
// Provisioning ledger + reserve caches.
// ===========================================================================

class ProvisioningLedger extends StatelessWidget {
  const ProvisioningLedger({super.key, required this.lines});

  final List<ProvisionLine> lines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'Equipment maintenance & provisioning',
      child: Column(
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    switch (line.kind) {
                      ProvisionKind.emergencyProvision =>
                        Icons.shield_outlined,
                      ProvisionKind.variableMaintenance =>
                        Icons.build_circle_outlined,
                      ProvisionKind.fixedMaintenance =>
                        Icons.build_outlined,
                    },
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.name,
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text(
                          [
                            if (line.isAnnualContract)
                              'Contract'
                            else
                              switch (line.kind) {
                                ProvisionKind.emergencyProvision => 'Provision',
                                ProvisionKind.variableMaintenance => 'Variable',
                                ProvisionKind.fixedMaintenance => 'Fixed',
                              },
                            if (line.shared)
                              'shared'
                            else if (line.ownerName != null)
                              line.ownerName!,
                            if (line.isAnnualContract)
                              recurringDueLabel(
                                isAnnual: true,
                                dueDay: line.dueDay ?? 1,
                                dueMonth: line.dueMonth,
                              ),
                          ].join(' · '),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (line.awaitingTally)
                    _Tag(
                      label: 'Awaiting tally',
                      color: scheme.tertiary,
                    )
                  else if (line.isAnnualContract)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${money(line.amountCents)}/floor',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                        ),
                        _Tag(
                          label: dueCountdown(line.daysUntilDue ?? 0),
                          color: (line.daysUntilDue ?? 99) <= 7
                              ? scheme.tertiary
                              : scheme.primary,
                        ),
                      ],
                    )
                  else
                    Text(
                      money(line.amountCents),
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

class ReserveCacheStrip extends StatelessWidget {
  const ReserveCacheStrip({super.key, required this.caches});

  final List<ReserveCache> caches;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Reserve caches',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [for (final cache in caches) _CacheChip(cache: cache)],
      ),
    );
  }
}

class _CacheChip extends StatelessWidget {
  const _CacheChip({required this.cache});

  final ReserveCache cache;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
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
              Icon(Icons.shield_moon_outlined, size: 16, color: scheme.error),
              const SizedBox(width: AppSpacing.xs),
              Text(
                cache.name,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text(
            money(cache.balanceCents),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          if (cache.petName != null)
            Text(
              cache.petName!,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
