part of '../pixel_adventure_view.dart';

/// The central floor viewport: monsters sized by their budget, party
/// contracts and quest bosses.
extension _FloorViewportPanel on PixelAdventureView {
  Widget _floorViewport(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monsters = <Monster>[
      ...game.monsters,
      for (final partyMember in game.party) ...partyMember.monsters,
    ];
    final maxBudget = monsters.fold<int>(
        0, (largest, monster) => monster.maxHpCents > largest ? monster.maxHpCents : largest);
    return _PixelPanel(
      title: 'The Dungeon Entrance',
      accent: scheme.secondary,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 140),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: AppRadii.card,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (monsters.isEmpty && game.questMonsters.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Text(
                    'No monsters stir on this floor yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            if (monsters.isNotEmpty)
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  for (final monster in monsters)
                    _MonsterTile(
                      monster: monster,
                      scale: _budgetScale(monster.maxHpCents, maxBudget),
                      resolver: resolver,
                      animate: animate,
                    ),
                ],
              ),
            if (game.contracts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final contract in game.contracts) _contractRow(context, contract),
            ],
            if (game.questMonsters.isNotEmpty) ...[
              const Divider(height: AppSpacing.xl),
              Text('Quest bosses',
                  style: AppText.sectionLabel(context)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  for (final quest in game.questMonsters)
                    _BossTile(quest: quest, resolver: resolver, animate: animate),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Maps a monster's budget (its max HP) to an integer sprite scale so bigger
  /// budgets literally loom larger on the floor. Whole-number scales only, so
  /// pixels never blur.
  int _budgetScale(int hpCents, int maxBudgetCents) {
    if (maxBudgetCents <= 0) return 2;
    final fill = hpCents / maxBudgetCents;
    if (fill >= 0.66) return 4;
    if (fill >= 0.33) return 3;
    return 2;
  }

  Widget _contractRow(BuildContext context, PartyContract contract) {
    final scheme = Theme.of(context).colorScheme;
    final color = contract.enraged ? scheme.error : scheme.tertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(Icons.handshake_outlined, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${contract.name} (party)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 2),
                _PixelHpBar(fraction: contract.hp.fraction, color: color),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            contract.enraged ? 'ENRAGED' : '${contract.hp.pct}%',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MonsterTile extends StatelessWidget {
  const _MonsterTile({
    required this.monster,
    required this.scale,
    required this.resolver,
    required this.animate,
  });

  final Monster monster;
  final int scale;
  final SpriteResolver resolver;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = monster.enraged
        ? scheme.error
        : (monster.mine ? scheme.primary : scheme.secondary);
    return SizedBox(
      width: (kSpriteBaseSize * 4) + AppSpacing.sm * 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: monster.enraged
                ? BoxDecoration(
                    borderRadius: AppRadii.chip,
                    border: Border.all(color: scheme.error, width: 1.5),
                  )
                : null,
            child: GameSprite(
              sprite: monster.sprite,
              resolver: resolver,
              scale: scale,
              animate: animate,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            monster.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          _PixelHpBar(fraction: monster.hp.fraction, color: color),
          Text(
            monster.enraged
                ? '+${money(monster.excessCents)} broke through'
                : '${monster.hp.pct}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: monster.enraged ? scheme.error : scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Boss tile: a quest boss sprite with its progress toward completion.
// ===========================================================================

class _BossTile extends StatelessWidget {
  const _BossTile({
    required this.quest,
    required this.resolver,
    required this.animate,
  });

  final QuestMonster quest;
  final SpriteResolver resolver;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = quest.completed ? scheme.primary : scheme.secondary;
    return SizedBox(
      width: (kSpriteBaseSize * 4) + AppSpacing.sm * 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              GameSprite(
                sprite: quest.sprite,
                resolver: resolver,
                scale: 4,
                animate: animate && !quest.completed,
              ),
              if (quest.completed)
                GameSprite(
                  sprite: const SpriteRef.asset(Sprites.trophy, label: 'Trophy'),
                  resolver: resolver,
                  scale: 1,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            quest.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          _PixelHpBar(fraction: quest.hp.fraction, color: color),
          Text(
            quest.completed ? 'FELLED ✓' : '${quest.hp.pct}%',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Year minimap tile.
// ===========================================================================
