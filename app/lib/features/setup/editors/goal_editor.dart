part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Editor (bottom sheet) for the first savings goal — returned via a typed result
// ---------------------------------------------------------------------------

Future<DraftQuest?> showGoalEditor(BuildContext context, SetupController controller) {
  final nameController = TextEditingController();
  final targetController = TextEditingController();
  final descriptionController = TextEditingController();
  var shared = true;
  String? owner = controller.adults.isNotEmpty ? controller.adults.first.localId : null;
  const mainCat = 'savings';

  int centsOf() {
    final trimmed = targetController.text.trim();
    if (trimmed.isEmpty) return 0;
    try {
      return Money.parse(trimmed).cents;
    } on FormatException {
      return 0;
    }
  }

  return showModalBottomSheet<DraftQuest>(
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
              Text('First goal',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Goal name', hintText: 'e.g. Canoe'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: targetController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Target amount', prefixText: '\$'),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shared goal'),
                subtitle: const Text('Any adult can fund it'),
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
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  helperText: 'Feeds text-mode adventure',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final desc = descriptionController.text.trim();
                  Navigator.of(sheetContext).pop(DraftQuest(
                    name: name,
                    targetCents: centsOf(),
                    shared: shared,
                    ownerLocalId: shared ? null : owner,
                    mainCategoryId: mainCat,
                    descriptionText: desc.isEmpty ? null : desc,
                  ));
                },
                child: const Text('Set goal'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
