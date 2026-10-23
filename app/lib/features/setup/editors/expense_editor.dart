part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Editor (bottom sheet) for a fixed expense — returned via a typed result
// ---------------------------------------------------------------------------

Future<DraftFixedExpense?> showExpenseEditor(
    BuildContext context, SetupController controller,
    {DraftFixedExpense? existing}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final amountController = TextEditingController(
      text: existing == null ? '' : Money(existing.amountCents).format());
  final dueDayController = TextEditingController(text: '${existing?.dueDay ?? 1}');
  var shared = existing?.shared ?? true;
  String? owner = existing?.ownerLocalId ??
      (controller.adults.isNotEmpty ? controller.adults.first.localId : null);
  var kind = existing?.kind ?? RecurringKind.fixed;
  var cadence = existing?.cadence ?? RecurringCadence.monthly;
  var dueMonth = existing?.dueMonth ?? 1;
  // Labels follow this device's adult's chosen mode (Adventure by default).
  final meLocalId = controller.meLocalId;
  final adventure = meLocalId == null || controller.modeOf(meLocalId) == PlayMode.adventure;

  int centsOf() {
    final trimmed = amountController.text.trim();
    if (trimmed.isEmpty) return 0;
    try {
      return Money.parse(trimmed).cents;
    } on FormatException {
      return 0;
    }
  }

  return showModalBottomSheet<DraftFixedExpense>(
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
              Text(existing == null ? 'New bill' : 'Edit bill',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<RecurringKind>(
                segments: [
                  ButtonSegment(
                    value: RecurringKind.fixed,
                    label: Text(
                        Glossary.fixedBill.label(isAdventure: adventure)),
                  ),
                  ButtonSegment(
                    value: RecurringKind.variable,
                    label: Text(
                        Glossary.variableBill.label(isAdventure: adventure)),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (selection) => setSheet(() => kind = selection.first),
              ),
              if (kind == RecurringKind.variable) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Glossary.variableBill.helper,
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText:
                        kind == RecurringKind.variable ? 'Estimate' : 'Amount',
                    prefixText: '\$'),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Group expense'),
                subtitle: const Text('Split across the household; off = one adult'),
                value: shared,
                onChanged: (value) => setSheet(() => shared = value),
              ),
              if (!shared && controller.adults.length > 1)
                _OwnerDropdown(
                  adults: controller.adults,
                  value: owner,
                  onChanged: (value) => setSheet(() => owner = value),
                ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<RecurringCadence>(
                segments: const [
                  ButtonSegment(
                      value: RecurringCadence.monthly, label: Text('Monthly')),
                  ButtonSegment(
                      value: RecurringCadence.annual, label: Text('Annual')),
                ],
                selected: {cadence},
                onSelectionChanged: (selection) => setSheet(() => cadence = selection.first),
              ),
              if (cadence == RecurringCadence.annual) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Annual bills accrue 1/12 each month off the top, so the '
                  'year is fully reserved by the time it comes due.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MonthDropdown(
                  value: dueMonth,
                  onChanged: (value) => setSheet(() => dueMonth = value),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: dueDayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Due day of month (1–31)',
                  helperText: '31 reads as "last day of month"',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final day = (int.tryParse(dueDayController.text.trim()) ?? 1)
                      .clamp(1, 31);
                  Navigator.of(sheetContext).pop(DraftFixedExpense(
                    name: name,
                    shared: shared,
                    ownerLocalId: shared ? null : owner,
                    amountCents: centsOf(),
                    kind: kind,
                    cadence: cadence,
                    dueDay: day,
                    dueMonth:
                        cadence == RecurringCadence.annual ? dueMonth : null,
                  ));
                },
                child: Text(existing == null ? 'Add bill' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
