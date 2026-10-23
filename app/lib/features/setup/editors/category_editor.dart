part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Editor (bottom sheet) for a budget category — returned via a typed result
// ---------------------------------------------------------------------------

Future<DraftCategory?> showCategoryEditor(
  BuildContext context,
  SetupController controller, {
  required bool group,
  String? ownerLocalId,
  DraftCategory? existing,
}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final limitController = TextEditingController(
      text: existing == null ? '' : Money(existing.limitCents).format());
  final titheController = TextEditingController(text: '${existing?.tithePct ?? 0}');
  String mainCat = existing?.mainCategoryId ?? controller.mainCategories.first.id;
  final petOwners = <String>{...?existing?.petOwnerIds};

  int centsOf() {
    final trimmed = limitController.text.trim();
    if (trimmed.isEmpty) return 0;
    try {
      return Money.parse(trimmed).cents;
    } on FormatException {
      return 0;
    }
  }

  return showModalBottomSheet<DraftCategory>(
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
              Text(
                  existing == null
                      ? '${group ? 'Group' : 'Personal'} category'
                      : 'Edit category',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: limitController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Monthly limit', prefixText: '\$'),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: mainCat,
                decoration: const InputDecoration(labelText: 'Main category'),
                items: [
                  for (final mainCategory in controller.mainCategories)
                    DropdownMenuItem(value: mainCategory.id, child: Text(mainCategory.name)),
                ],
                onChanged: (value) => setSheet(() => mainCat = value ?? mainCat),
              ),
              if (!group) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: titheController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Carry tax % (0–100)',
                    helperText: '${Glossary.carryTax.helper} 0 keeps it all.',
                    helperMaxLines: 3,
                  ),
                ),
              ],
              if (group && controller.pets.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Belongs to pets (optional)',
                    style: Theme.of(sheetContext).textTheme.labelLarge),
                Text(
                  'Pick every pet this budget covers — they share it '
                  'equally, each paid from that pet\'s funding source.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final pet in controller.pets)
                      FilterChip(
                        label: Text(pet.name),
                        selected: petOwners.contains(pet.localId),
                        onSelected: (selected) => setSheet(() => selected
                            ? petOwners.add(pet.localId)
                            : petOwners.remove(pet.localId)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.of(sheetContext).pop(DraftCategory(
                    name: name,
                    limitCents: centsOf(),
                    group: group,
                    ownerLocalId: group ? null : ownerLocalId,
                    mainCategoryId: mainCat,
                    petOwnerIds:
                        group ? List.unmodifiable(petOwners) : const [],
                    tithePct: (int.tryParse(titheController.text.trim()) ?? 0)
                        .clamp(0, 100),
                  ));
                },
                child: Text(existing == null ? 'Add category' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
