/// The Vault: savings milestones. Each savings goal's progress as a share of
/// its goal toward the 25/50/75/100% marks, and the run of consecutive months
/// with a savings choice toward the 3/6/12 marks. Rule 8: percentages and
/// consistency only — no dollar amount is ever shown here.
///
/// Framed in the pixel tier (wood board, parchment cards, meters); the text
/// tier keeps its text panels and "[x] 25%" mark lines.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/balance.dart';
import 'hall_common.dart';
import 'hall_framed.dart';
import 'hall_ledger_view.dart';
import 'hall_names.dart';
import 'hall_resource_chips.dart';
import 'kit/kit.dart';
import 'vault_marks.dart';

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key, required this.onOpenLedger});

  final VoidCallback onOpenLedger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(hallLedgerViewProvider);
    final game = hallGameState(ref);
    final questMarks = Balance.questMilestoneGems.keys.toList()..sort();
    final streakMarks = Balance.savingsStreakGems.keys.toList()..sort();
    final run = view.savingsRunMonths;
    final nextStreak = streakMarks.where((mark) => mark > run).firstOrNull;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return FramedHallScreen(
      title: 'Vault',
      trailing: [gemsChip(game.person(view.meId ?? '').gems, compact: compact)],
      children: [
        FramedSection(
          title: 'Savings goals',
          icon: Icons.flag_outlined,
          child: view.quests.isEmpty
              ? _NoGoalsYet(onOpenLedger: onOpenLedger)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, quest) in view.quests.indexed) ...[
                      if (index > 0) const SizedBox(height: AdventureTokens.gapLarge - 4),
                      _GoalProgress(quest: quest, marks: questMarks),
                    ],
                  ],
                ),
        ),
        FramedSection(
          title: 'Saving streak',
          icon: Icons.calendar_month_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                run == 0
                    ? 'Choose to save some leftover at the next month-end '
                        'and the streak begins.'
                    : '$run month${run == 1 ? '' : 's'} in a row with a '
                        'savings choice.',
                style: framedBodyStyle(context),
              ),
              if (nextStreak != null && run > 0 && !hallTextTier(context)) ...[
                const SizedBox(height: AdventureTokens.gap),
                FramedMeter(
                  run / nextStreak,
                  color: AdventureTokens.hpBlue,
                  semanticsLabel: 'Progress to the $nextStreak month milestone',
                ),
              ],
              const SizedBox(height: AdventureTokens.gap),
              MilestoneMarks(
                marks: streakMarks,
                reached: (mark) => run >= mark,
                label: (mark) => '$mark months',
              ),
              if (nextStreak != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Next milestone: $nextStreak months '
                    '(${HallNames.gems(Balance.savingsStreakGems[nextStreak]!)}).',
                    style: framedMutedStyle(context),
                  ),
                ),
            ],
          ),
        ),
        _MilestoneNote(),
      ],
    );
  }
}

/// The empty state: no goals yet, and the way to the ledger to set one up.
class _NoGoalsYet extends StatelessWidget {
  const _NoGoalsYet({required this.onOpenLedger});

  final VoidCallback onOpenLedger;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No savings goals yet. Set one up in the ledger and the '
            'Vault will celebrate every quarter of the way.',
            style: framedMutedStyle(context),
          ),
          const SizedBox(height: AdventureTokens.gap),
          FramedButton(label: 'Open the ledger', onPressed: onOpenLedger, secondary: true),
        ],
      );
}

/// One savings goal: its name, a meter and percent, and the quarter marks.
class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.quest, required this.marks});

  final HallQuest quest;
  final List<int> marks;

  @override
  Widget build(BuildContext context) {
    final percent = quest.percent;
    return Column(
      key: ValueKey('vault-goal-${quest.questId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          quest.shared ? '${quest.name} (shared)' : quest.name,
          style: hallTextTier(context)
              ? framedBodyStyle(context, weight: FontWeight.w700)
              : AdventureTokens.label(context),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: FramedMeter(
                percent / 100,
                color: quest.completed ? AdventureTokens.gold : AdventureTokens.hpGreen,
                semanticsLabel: '${quest.name} progress',
                textWidth: 20,
              ),
            ),
            const SizedBox(width: AdventureTokens.gap),
            Text(
              '$percent%',
              style: hallTextTier(context)
                  ? framedBodyStyle(context)
                  : AdventureTokens.amount(context),
            ),
          ],
        ),
        const SizedBox(height: 4),
        MilestoneMarks(
          marks: marks,
          reached: (mark) => percent >= mark,
          label: (mark) => '$mark%',
        ),
      ],
    );
  }
}

/// The closing reassurance: milestones pay gems and measure steadiness.
class _MilestoneNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const message = 'Milestones pay gems into your inbox. They measure how far and how '
        'steadily you save, never how much.';
    if (hallTextTier(context)) return Text(message, style: hallMutedStyle(context));
    return InsetWell(
      key: const ValueKey('vault-note'),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined, color: AdventureTokens.inkMuted),
          const SizedBox(width: AdventureTokens.gap),
          Expanded(child: Text(message, style: framedBodyStyle(context))),
        ],
      ),
    );
  }
}
