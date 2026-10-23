part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Step 8 — summary
// ---------------------------------------------------------------------------

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({required this.controller});
  final SetupController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Your household is ready',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        _summaryRow(context, Icons.groups_outlined, 'Members',
            '${controller.adults.length} adult(s), ${controller.members.length - controller.adults.length} others'),
        _summaryRow(context, Icons.payments_outlined, 'Total income',
            '${money(controller.totalIncomeCents)}/mo'),
        _summaryRow(context, Icons.trending_up, 'Tracked accounts',
            '${controller.accounts.length}'),
        _summaryRow(context, Icons.autorenew, 'Fixed expenses',
            '${controller.fixedExpenses.length}'),
        _summaryRow(context, Icons.pie_chart_outline, 'Budget categories',
            '${controller.categories.length}'),
        _summaryRow(context, Icons.flag_outlined, 'First goal',
            controller.firstQuest?.name ?? 'none yet'),
        _summaryRow(
            context,
            Icons.videogame_asset_outlined,
            'Mode',
            [
              for (final adult in controller.adults)
                [
                  if (controller.adults.length > 1) '${adult.name}:',
                  if (controller.modeOf(adult.localId) == PlayMode.adventure)
                    'Adventure'
                  else
                    'Standard',
                ].join(' '),
            ].join(' · ')),
        const SizedBox(height: AppSpacing.lg),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.lock_clock, size: 20),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Everything you set up here is written to a permanent, '
                    'append-only log. Nothing is ever deleted — later changes '
                    'and corrections are recorded as new entries you can review '
                    'any time in the budget change log.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
      BuildContext context, IconData icon, String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
