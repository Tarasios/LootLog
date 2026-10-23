/// The Vault: savings milestones. Each savings goal's progress as a share of
/// its goal toward the 25/50/75/100% marks, and the run of consecutive months
/// with a savings choice toward the 3/6/12 marks. Rule 8: percentages and
/// consistency only — no dollar amount is ever shown here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme.dart';
import '../config/balance.dart';
import 'hall_common.dart';
import 'hall_ledger_view.dart';
import 'hall_names.dart';

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key, required this.onOpenLedger});

  final VoidCallback onOpenLedger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(hallLedgerViewProvider);
    final questMarks = Balance.questMilestoneGems.keys.toList()..sort();
    final streakMarks = Balance.savingsStreakGems.keys.toList()..sort();
    final run = view.savingsRunMonths;
    final nextStreak = streakMarks.where((m) => m > run).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Vault')),
      body: HallPage(children: [
        HallSection(
          title: 'Savings goals',
          icon: Icons.flag_outlined,
          child: view.quests.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'No savings goals yet. Set one up in the ledger and the '
                        'Vault will celebrate every quarter of the way.',
                        style: hallMutedStyle(context)),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: onOpenLedger,
                      child: const Text('Open the ledger'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final q in view.quests)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                q.shared ? '${q.name} (shared)' : q.name,
                                style: hallBodyStyle(context,
                                    weight: FontWeight.w700)),
                            Row(
                              children: [
                                Expanded(child: HallBar(q.percent / 100, width: 20)),
                                const SizedBox(width: AppSpacing.sm),
                                Text('${q.percent}%',
                                    style: hallBodyStyle(context)),
                              ],
                            ),
                            Text(
                                _marks(questMarks, (m) => q.percent >= m,
                                    (m) => '$m%'),
                                style: hallMutedStyle(context)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        HallSection(
          title: 'Saving streak',
          icon: Icons.calendar_month_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  run == 0
                      ? 'Choose to save some leftover at the next month-end '
                          'and the streak begins.'
                      : '$run month${run == 1 ? '' : 's'} in a row with a '
                          'savings choice.',
                  style: hallBodyStyle(context)),
              Text(
                  _marks(streakMarks, (m) => run >= m,
                      (m) => '$m months'),
                  style: hallMutedStyle(context)),
              if (nextStreak != null)
                Text(
                    'Next milestone: $nextStreak months '
                    '(${HallNames.gems(Balance.savingsStreakGems[nextStreak]!)}).',
                    style: hallMutedStyle(context)),
            ],
          ),
        ),
        Text(
            'Milestones pay gems into your inbox. They measure how far and how '
            'steadily you save, never how much.',
            style: hallMutedStyle(context)),
      ]),
    );
  }

  /// "[x] 25%  [x] 50%  [ ] 75%  [ ] 100%".
  static String _marks(
          List<int> marks, bool Function(int) reached, String Function(int) label) =>
      [for (final m in marks) '${reached(m) ? '[x]' : '[ ]'} ${label(m)}']
          .join('  ');
}
