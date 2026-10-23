part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Editor (bottom sheet) for a tracked account — returned via a typed result
// ---------------------------------------------------------------------------

Future<DraftAccount?> showAccountEditor(BuildContext context) {
  final nameController = TextEditingController();
  final balanceController = TextEditingController();
  final aprController = TextEditingController();
  final minimumPaymentController = TextEditingController();
  var kind = AccountKind.savings;
  const accrual = AccountCadence.monthly;
  var update = AccountCadence.quarterly;

  int centsOf(TextEditingController textController) {
    final trimmed = textController.text.trim();
    if (trimmed.isEmpty) return 0;
    try {
      return Money.parse(trimmed).cents;
    } on FormatException {
      return 0;
    }
  }

  return showModalBottomSheet<DraftAccount>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New account',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<AccountKind>(
                segments: const [
                  ButtonSegment(value: AccountKind.savings, label: Text('Savings')),
                  ButtonSegment(
                      value: AccountKind.investment, label: Text('Investment')),
                  ButtonSegment(value: AccountKind.debt, label: Text('Debt')),
                ],
                selected: {kind},
                onSelectionChanged: (selection) => setSheet(() => kind = selection.first),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: balanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: kind == AccountKind.debt
                      ? 'Amount owed'
                      : kind == AccountKind.investment
                          ? 'Current value'
                          : 'Balance',
                  prefixText: '\$',
                ),
              ),
              if (kind == AccountKind.savings || kind == AccountKind.debt) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: aprController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'APR %',
                    helperText: 'Interest accrues at read time',
                  ),
                ),
              ],
              if (kind == AccountKind.debt) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: minimumPaymentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Minimum payment',
                    helperText: 'Surfaces automatically as a recurring expense',
                    prefixText: '\$',
                  ),
                ),
              ],
              if (kind == AccountKind.investment) ...[
                const SizedBox(height: AppSpacing.sm),
                _CadenceDropdown(
                  label: 'Update cadence',
                  value: update,
                  onChanged: (value) => setSheet(() => update = value),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final aprPct = double.tryParse(aprController.text.trim()) ?? 0;
                  Navigator.of(sheetContext).pop(DraftAccount(
                    name: name,
                    kind: kind,
                    balanceCents: centsOf(balanceController),
                    aprBps: (kind == AccountKind.savings ||
                            kind == AccountKind.debt)
                        ? (aprPct * 100).round()
                        : null,
                    accrualCadence: (kind == AccountKind.savings ||
                            kind == AccountKind.debt)
                        ? accrual
                        : null,
                    updateCadence:
                        kind == AccountKind.investment ? update : null,
                    minPaymentCents:
                        kind == AccountKind.debt ? centsOf(minimumPaymentController) : null,
                  ));
                },
                child: const Text('Add account'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
