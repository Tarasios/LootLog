part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Step 5 — fixed expenses
// ---------------------------------------------------------------------------

class _ExpensesStep extends StatelessWidget {
  const _ExpensesStep({required this.controller});
  final SetupController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Recurring bills that come off the top before budgets are funded. '
          'Group bills split across the household; personal ones sit on one '
          'adult. Bills that change month to month (like utilities) can use an '
          'estimate — you enter the real amount at month end.',
        ),
        for (var i = 0; i < controller.fixedExpenses.length; i++)
          _expenseTile(context, i),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final expense = await showExpenseEditor(context, controller);
              if (expense != null) controller.addFixedExpense(expense);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add bill'),
          ),
        ),
      ],
    );
  }

  Widget _expenseTile(BuildContext context, int i) {
    final expense = controller.fixedExpenses[i];
    final owner = expense.shared ? 'Group' : (controller.memberById(expense.ownerLocalId ?? '')?.name ?? 'Personal');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.autorenew),
      title: Text(expense.name),
      subtitle: Text(
        '$owner · ${money(expense.amountCents)}'
        '${expense.kind == RecurringKind.variable ? ' est.' : ''} · '
        '${expense.cadence == RecurringCadence.annual ? 'annual' : 'monthly'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final edited =
                  await showExpenseEditor(context, controller, existing: expense);
              if (edited != null) controller.updateFixedExpense(i, edited);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => controller.removeFixedExpense(i),
          ),
        ],
      ),
    );
  }
}
