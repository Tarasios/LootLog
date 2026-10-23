part of '../adventure_dashboard.dart';

// ===========================================================================
// Floor header: dungeon floor + both idle avatars + hero HP.
// ===========================================================================

class _FloorHeader extends StatelessWidget {
  const _FloorHeader({required this.game, required this.resolver});

  final DungeonState game;
  final SpriteResolver resolver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        gradient: LinearGradient(
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GameSprite(
                sprite: game.heroSprite,
                resolver: resolver,
                scale: 2,
                animate: true,
              ),
              for (final companion in game.companionSprites) ...[
                const SizedBox(width: AppSpacing.xs),
                GameSprite(
                  sprite: companion,
                  resolver: resolver,
                  scale: 2,
                  animate: true,
                ),
              ],
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dungeon floor ${game.floorNumber}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      monthLabel(
                        game.currentMonth.year,
                        game.currentMonth.month,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _HeroStatus(game: game),
        ],
      ),
    );
  }
}

class _HeroStatus extends StatelessWidget {
  const _HeroStatus({required this.game});

  final DungeonState game;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          game.heroWounded ? Icons.favorite : Icons.favorite_border,
          size: 18,
          color: game.heroWounded ? scheme.error : scheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            game.heroWounded
                ? '${game.heroName} took ${money(game.heroHpLostCents)} of '
                    'overspend damage'
                : '${game.heroName} is hale — no monster broke through',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: game.heroWounded
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
          ),
        ),
        if (game.expeditionSuppliesCents > 0)
          _Pill(
            icon: Icons.inventory_2_outlined,
            label: '${money(game.expeditionSuppliesCents)} supplies',
            color: scheme.tertiaryContainer,
            onColor: scheme.onTertiaryContainer,
          ),
      ],
    );
  }
}
