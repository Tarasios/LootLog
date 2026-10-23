part of '../text_adventure_view.dart';

/// Quest bosses: savings goals hunted across floors.
extension _QuestBossesSection on TextAdventureView {
  Widget _questBosses(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'Quest Bosses',
      icon: Icons.flag_outlined,
      accent: scheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final quest in game.questMonsters) _questLine(context, quest),
        ],
      ),
    );
  }

  Widget _questLine(BuildContext context, QuestMonster quest) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(quest.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle(context, weight: FontWeight.w700)),
              ),
              Text(
                quest.completed ? 'FELLED ✓' : '${quest.hp.pct}%',
                style: monoStyle(context,
                    color: quest.completed ? scheme.tertiary : scheme.secondary),
              ),
            ],
          ),
          Text(
            '${textBar(quest.hp.fraction)}  '
            '${money(quest.contributedCents)} / ${money(quest.targetCents)}',
            style: monoStyle(context,
                color: quest.completed ? scheme.tertiary : scheme.secondary),
          ),
          if (quest.descriptionText?.isNotEmpty == true)
            Text(quest.descriptionText!,
                style: monoStyle(context, color: scheme.onSurfaceVariant)
                    .copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
