part of '../adventure_dashboard.dart';

// ===========================================================================
// Gold pouch (vault).
// ===========================================================================

class GoldPouchCard extends StatelessWidget {
  const GoldPouchCard({
    super.key,
    required this.pouch,
    required this.heroName,
  });

  final GoldPouch pouch;
  final String heroName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadii.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.paid_outlined, color: scheme.onSecondaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '$heroName’s gold pouch',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                money(pouch.balanceCents),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          if (pouch.clampedFlag)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Pouch scraped empty — check recent charges',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ),
          if (pouch.projectedMintCents > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'This floor’s spoils would mint '
                '${money(pouch.projectedMintCents)} into the pouch',
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
