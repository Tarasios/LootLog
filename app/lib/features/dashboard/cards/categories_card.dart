part of '../dashboard_view.dart';

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
                    for (final ring in rings)
                      SizedBox(
                        width: tileWidth,
                        child: _CategoryTile(ring: ring),
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
                  ring.lockedCents > 0
                      ? (ring.effectiveLimitCents == 0
                          ? 'Locked — repaying ${money(ring.lockedCents)}'
                          : '${money(ring.remainingCents)} left · '
                              '${money(ring.lockedCents)} repaying')
                      : ring.overspent
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
                if (ring.savingsCents > 0)
                  Text(
                    '+ ${money(ring.savingsCents)} saved',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onContainer.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
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
