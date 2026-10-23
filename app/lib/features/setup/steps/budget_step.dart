part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Step 6 — budget allocation
// ---------------------------------------------------------------------------

class _BudgetStep extends StatelessWidget {
  const _BudgetStep({required this.controller});
  final SetupController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _Banner(
          icon: Icons.savings_outlined,
          text: 'Total monthly income: ${money(controller.totalIncomeCents)}',
        ),
        const _StepIntro(
          'Fund group categories first, propose the split, then give each adult '
          'personal categories until their leftover counter reaches zero.',
        ),
        if (controller.anyOverAllocated)
          _Banner(
            icon: Icons.warning_amber_outlined,
            text: 'A plan exceeds someone\'s income — trim limits below '
                'until every adult is at or under zero.',
          ),
        _mainCategoriesCard(context),
        Text('Group categories', style: AppText.sectionLabel(context)),
        for (var i = 0; i < controller.categories.length; i++)
          if (controller.categories[i].group) _categoryTile(context, i),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final category = await showCategoryEditor(context, controller, group: true);
              if (category != null) controller.addCategory(category);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add group category'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Banner(
          icon: Icons.groups_outlined,
          text: 'Group burden (funded by shares): ${money(controller.groupBurdenCents)}',
        ),
        if (controller.adults.length > 1) _sharesCard(context),
        const Divider(height: AppSpacing.xl),
        Text('Personal categories', style: AppText.sectionLabel(context)),
        for (final adult in controller.adults) _adultBudget(context, adult, scheme),
      ],
    );
  }

  Widget _mainCategoriesCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Main categories',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton(
                  onPressed: () => showMainCategoriesEditor(context, controller),
                  child: const Text('Customize'),
                ),
              ],
            ),
            Text(
              controller.mainCategories.map((mainCategory) => mainCategory.name).join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sharesCard(BuildContext context) {
    final shares = controller.effectiveShares();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Share split',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton(
                  onPressed: () async {
                    final editedShares = await showSharesEditor(context, controller);
                    if (editedShares != null) controller.setShares(editedShares);
                  },
                  child: Text(controller.shares == null ? 'Even (edit)' : 'Custom (edit)'),
                ),
              ],
            ),
            for (final adult in controller.adults)
              Text(
                  '${adult.name}: ${(shares[adult.localId] ?? 0) / 10}%'),
          ],
        ),
      ),
    );
  }

  Widget _adultBudget(BuildContext context, DraftMember adult, ColorScheme scheme) {
    final alloc = controller.allocationFor(adult.localId);
    final left = alloc.unallocatedCents;
    final color = left == 0
        ? scheme.primary
        : (left < 0 ? scheme.error : scheme.onSurfaceVariant);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(adult.name,
                        style: Theme.of(context).textTheme.titleMedium)),
                Text(
                  left == 0
                      ? 'All allocated'
                      : '${signedMoney(left)} left',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Text(
              'Income ${money(alloc.incomeCents)} · group ${money(alloc.groupShareCents)} '
              '· fixed ${money(alloc.personalFixedCents)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < controller.categories.length; i++)
              if (!controller.categories[i].group &&
                  controller.categories[i].ownerLocalId == adult.localId)
                _categoryTile(context, i, dense: true),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final category = await showCategoryEditor(context, controller,
                        group: false, ownerLocalId: adult.localId);
                    if (category != null) controller.addCategory(category);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add category'),
                ),
                TextButton.icon(
                  onPressed: () => controller.splitEvenlyFor(adult.localId),
                  icon: const Icon(Icons.balance_outlined),
                  label: const Text('Split evenly'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTile(BuildContext context, int i, {bool dense = false}) {
    final category = controller.categories[i];
    return ListTile(
      dense: dense,
      contentPadding: EdgeInsets.zero,
      leading: dense ? null : const Icon(Icons.pie_chart_outline),
      title: Text(category.name),
      subtitle: Text(category.tithePct > 0
          ? '${money(category.limitCents)} · ${category.tithePct}% '
              '${Glossary.carryTax.classic}'
          : money(category.limitCents)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final edited = await showCategoryEditor(context, controller,
                  group: category.group,
                  ownerLocalId: category.ownerLocalId,
                  existing: category);
              if (edited != null) controller.updateCategory(i, edited);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => controller.removeCategory(i),
          ),
        ],
      ),
    );
  }
}
