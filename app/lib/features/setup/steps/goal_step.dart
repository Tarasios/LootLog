part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Step 7 — first goal + mode
// ---------------------------------------------------------------------------

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.controller});
  final SetupController controller;

  @override
  Widget build(BuildContext context) {
    final firstQuest = controller.firstQuest;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Pick a first savings goal. Optional, but '
          'goals are what make the whole thing sing. Fund it at month close.',
        ),
        if (firstQuest == null)
          OutlinedButton.icon(
            onPressed: () async {
              final quest = await showGoalEditor(context, controller);
              if (quest != null) controller.setFirstQuest(quest);
            },
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Choose a first goal'),
          )
        else
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag),
              title: Text(firstQuest.name),
              subtitle: Text(
                  'Target ${money(firstQuest.targetCents)} · ${firstQuest.shared ? 'shared' : 'personal'}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => controller.setFirstQuest(null),
              ),
            ),
          ),
        const Divider(height: AppSpacing.xl),
        Text(controller.adults.length > 1 ? 'Who wants to play?' : 'Play the game?',
            style: AppText.sectionLabel(context)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Adventure turns the budget into a game (the default). Standard is '
          'the plain budgeting app — their logging still helps the household. '
          'Anyone can switch any time in Settings.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        for (final adult in controller.adults) ...[
          const SizedBox(height: AppSpacing.sm),
          if (controller.adults.length > 1) Text(adult.name),
          SegmentedButton<PlayMode>(
            segments: const [
              ButtonSegment(
                value: PlayMode.adventure,
                label: Text('Adventure'),
                icon: Icon(Icons.castle_outlined),
              ),
              ButtonSegment(
                value: PlayMode.standard,
                label: Text('Standard'),
                icon: Icon(Icons.dashboard_outlined),
              ),
            ],
            selected: {controller.modeOf(adult.localId)},
            onSelectionChanged: (selection) => controller.setModeFor(adult.localId, selection.first),
          ),
        ],
      ],
    );
  }
}
