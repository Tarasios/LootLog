part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Editor (bottom sheet) for the main categories
// ---------------------------------------------------------------------------

/// Rename existing main categories or add new ones. Changes live in the
/// controller and become `MainCategorySet` events at finish.
Future<void> showMainCategoriesEditor(BuildContext context, SetupController controller) {
  final newNameController = TextEditingController();
  return showModalBottomSheet<void>(
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
              Text('Main categories',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The big buckets your reports and savings goals group by. Rename '
                'any of them, or add your own.',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final mainCategory in controller.mainCategories)
                _MainCategoryRow(
                  key: ValueKey(mainCategory.id),
                  category: mainCategory,
                  onRenamed: (name) =>
                      setSheet(() => controller.renameMainCategory(mainCategory.id, name)),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newNameController,
                      decoration:
                          const InputDecoration(labelText: 'New main category'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () {
                      final name = newNameController.text.trim();
                      if (name.isEmpty) return;
                      setSheet(() {
                        controller.addMainCategory(name);
                        newNameController.clear();
                      });
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One rename row: a text field seeded with the category's name that commits
/// on every change (the controller ignores empty names).
class _MainCategoryRow extends StatefulWidget {
  const _MainCategoryRow(
      {super.key, required this.category, required this.onRenamed});

  final MainCategory category;
  final ValueChanged<String> onRenamed;

  @override
  State<_MainCategoryRow> createState() => _MainCategoryRowState();
}

class _MainCategoryRowState extends State<_MainCategoryRow> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.category.name);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Color(widget.category.colorArgb),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(isDense: true),
              onChanged: widget.onRenamed,
            ),
          ),
        ],
      ),
    );
  }
}
