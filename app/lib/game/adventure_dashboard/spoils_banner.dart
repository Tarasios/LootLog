part of '../adventure_dashboard.dart';

// ===========================================================================
// Spoils call-to-action banner.
// ===========================================================================

/// The data the spoils CTA renders (kept tiny; the full ritual is its own
/// screen). Sourced from the classic spoils view-model at the call site.
class AdventureSpoilsBanner {
  const AdventureSpoilsBanner({
    required this.monstersToRecap,
    required this.talliesPending,
    required this.daysRemaining,
  });

  final int monstersToRecap;
  final int talliesPending;
  final int daysRemaining;
}

class _SpoilsCta extends StatelessWidget {
  const _SpoilsCta({required this.banner, this.onOpen});

  final AdventureSpoilsBanner banner;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = <String>[
      if (banner.monstersToRecap > 0)
        '${banner.monstersToRecap} monster${banner.monstersToRecap == 1 ? '' : 's'} to loot',
      if (banner.talliesPending > 0) '${banner.talliesPending} to tally',
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
              Icon(Icons.military_tech, color: scheme.onTertiaryContainer),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Divide the spoils',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onTertiaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      [
                        parts.join(' · '),
                        'defaults in ${banner.daysRemaining}d',
                      ].where((part) => part.isNotEmpty).join(' — '),
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
