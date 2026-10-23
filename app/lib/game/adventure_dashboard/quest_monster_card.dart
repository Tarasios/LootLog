part of '../adventure_dashboard.dart';

// ===========================================================================
// Quest monster.
// ===========================================================================

class QuestMonsterCard extends StatelessWidget {
  const QuestMonsterCard({
    super.key,
    required this.quest,
    this.resolver = const PlaceholderSpriteResolver(),
  });

  final QuestMonster quest;
  final SpriteResolver resolver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GameSprite(
          sprite: quest.sprite,
          resolver: resolver,
          scale: 3,
          animate: !quest.completed,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      quest.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (quest.shared)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: _Tag(label: 'Shared', color: scheme.tertiary),
                    ),
                  if (quest.completed)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: Icon(Icons.emoji_events,
                          size: 16, color: scheme.primary),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _HpBarView(
                bar: quest.hp,
                color: quest.completed ? scheme.primary : scheme.tertiary,
                trackColor: scheme.surfaceContainerHighest,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${money(quest.contributedCents)} / '
                '${money(quest.targetCents)} HP'
                '${quest.completed ? ' · trophy claimed' : ''}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              if (quest.shared && quest.contributors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    quest.contributors
                        .map((contribution) => '${contribution.name} ${money(contribution.cents)}')
                        .join('  ·  '),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
