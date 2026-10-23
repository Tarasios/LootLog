part of '../adventure_dashboard.dart';

/// An "expedition abroad" side-floor: an open vacation rendered as its own
/// mini-dungeon with budget rings, a supply ration, and overspend warnings.
class ExpeditionFloorCard extends StatelessWidget {
  const ExpeditionFloorCard({super.key, required this.expedition});

  final ExpeditionFloor expedition;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trip = expedition;
    final ration = trip.daysRemaining > 0
        ? '${money(trip.dailyAllowanceRemainingCents)}/day · '
            '${trip.daysRemaining} days left'
        : 'expedition over';
    return _SectionCard(
      title: 'Expedition abroad — ${trip.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.explore_outlined, size: 16, color: scheme.tertiary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${money(trip.totalSpentCents)} of ${money(trip.totalBudgetCents)} '
                  'provisions spent · $ration',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (trip.overspent)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _Tag(
                label: 'Over provisions by ${money(trip.totalOverspendCents)}',
                color: scheme.error,
              ),
            ),
          if (trip.fundExhausted)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _Tag(
                label: 'Cache depleted by ${money(-trip.fundBalanceCents)}',
                color: scheme.error,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final ring in trip.rings) _ExpeditionRingChip(ring: ring)],
          ),
        ],
      ),
    );
  }
}

class _ExpeditionRingChip extends StatelessWidget {
  const _ExpeditionRingChip({required this.ring});

  final ExpeditionRing ring;

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
          Text(
            ring.name,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            '${money(ring.spentCents)} / ${money(ring.budgetCents)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: ring.overspent ? scheme.error : null,
                ),
          ),
        ],
      ),
    );
  }
}
