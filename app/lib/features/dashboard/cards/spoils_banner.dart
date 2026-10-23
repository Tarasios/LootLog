part of '../dashboard_view.dart';

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
    );
  }
}
