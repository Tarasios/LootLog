part of '../adventure_dashboard.dart';

// ===========================================================================
// Monster card (personal slice).
// ===========================================================================

/// A personal-slice monster with an HP bar and an optional hit-flash overlay.
class MonsterCard extends StatelessWidget {
  const MonsterCard({
    super.key,
    required this.monster,
    this.resolver = const PlaceholderSpriteResolver(),
    this.flash = false,
  });

  final Monster monster;
  final SpriteResolver resolver;

  /// Momentary "just took damage" tint (driven by the screen on a new hit).
  final bool flash;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final barColor = monster.enraged
        ? scheme.error
        : (monster.mine ? scheme.primary : scheme.secondary);
    return AnimatedContainer(
      duration: AppDurations.fast,
      decoration: BoxDecoration(
        color: flash
            ? scheme.error.withValues(alpha: 0.18)
            : scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
        border: monster.enraged
            ? Border.all(color: scheme.error, width: 1.5)
            : null,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          GameSprite(
            sprite: monster.sprite,
            resolver: resolver,
            scale: 3,
            animate: true,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        monster.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (monster.enraged)
                      _Tag(label: 'ENRAGED', color: scheme.error)
                    else if (monster.defeated)
                      _Tag(label: 'DEFEATED', color: scheme.primary)
                    else if (!monster.mine && monster.ownerName != null)
                      Text(
                        monster.ownerName!,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _HpBarView(
                  bar: monster.hp,
                  color: barColor,
                  trackColor: scheme.surfaceContainerLow,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  monster.enraged
                      ? '${money(monster.damageCents)} dealt · '
                          '${money(monster.excessCents)} broke through'
                      : '${money(monster.damageCents)} / '
                          '${money(monster.maxHpCents)} HP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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
