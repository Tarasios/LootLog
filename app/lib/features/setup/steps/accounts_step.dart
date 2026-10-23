part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Step 4 — tracked accounts
// ---------------------------------------------------------------------------

class _AccountsStep extends StatelessWidget {
  const _AccountsStep({required this.controller});
  final SetupController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Optional: track savings, investments, and debts for your net-worth '
          'screen. These never touch your budget — they just get watched.',
        ),
        for (var i = 0; i < controller.accounts.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_accountIcon(controller.accounts[i].kind)),
            title: Text(controller.accounts[i].name),
            subtitle: Text(
                '${controller.accounts[i].kind.name} · ${money(controller.accounts[i].balanceCents)}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => controller.removeAccount(i),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final account = await showAccountEditor(context);
              if (account != null) controller.addAccount(account);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add account'),
          ),
        ),
      ],
    );
  }
}
