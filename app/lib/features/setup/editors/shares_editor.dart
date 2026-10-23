part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Editor (bottom sheet) for the adults' group-cost shares
// ---------------------------------------------------------------------------

Future<Map<String, int>?> showSharesEditor(
    BuildContext context, SetupController controller) {
  final ctrls = {
    for (final adult in controller.adults)
      adult.localId: TextEditingController(
        text: ((controller.effectiveShares()[adult.localId] ?? 0) / 10).toStringAsFixed(1),
      ),
  };
  return showModalBottomSheet<Map<String, int>>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share split (%)',
              style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const Text('Shares fund group costs off the top. They should add to '
              '100%.'),
          const SizedBox(height: AppSpacing.md),
          for (final adult in controller.adults)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: TextField(
                controller: ctrls[adult.localId],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: adult.name, suffixText: '%'),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(<String, int>{}),
                  child: const Text('Reset to even'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final result = <String, int>{
                      for (final adult in controller.adults)
                        adult.localId: ((double.tryParse(
                                        ctrls[adult.localId]!.text.trim()) ??
                                    0) *
                                10)
                            .round(),
                    };
                    Navigator.of(sheetContext).pop(result);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ).then((shares) {
    // An empty map is the "reset to even" sentinel.
    if (shares == null) return null;
    return shares.isEmpty ? null : shares;
  });
}
