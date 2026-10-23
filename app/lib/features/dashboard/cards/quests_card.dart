part of '../dashboard_view.dart';

class _QuestsCard extends StatelessWidget {
  const _QuestsCard({required this.quests, this.onNewGoal});

  final List<QuestCard> quests;
  final VoidCallback? onNewGoal;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Savings goals',
            icon: Icons.flag_outlined,
            trailing: onNewGoal == null
                ? null
                : TextButton.icon(
                    onPressed: onNewGoal,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New goal'),
                  ),
          ),
          if (quests.isEmpty)
            const AppEmptyHint(
              icon: Icons.flag_outlined,
              message: 'No savings goals yet. Set a target for something you’re '
                  'saving toward and fund it from your leftovers at month close.',
            )
          else
            for (var i = 0; i < quests.length; i++) ...[
              if (i > 0) const Divider(),
              _QuestTile(quest: quests[i]),
            ],
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest});

  final QuestCard quest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      quest.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (quest.isShared)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: _tag(context, 'Shared'),
                    ),
                  if (quest.completed)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                '${money(quest.totalContributedCents)} / ${money(quest.targetCents)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _ProportionBar(
          fraction: quest.progress,
          fill: quest.completed ? scheme.primary : scheme.tertiary,
          track: scheme.surfaceContainerHighest,
          height: 8,
        ),
        if (quest.isShared && quest.contributors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
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
    );
  }
}
