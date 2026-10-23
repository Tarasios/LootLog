/// A flat list of every budget category, grouped by owner, with add/edit routing
/// into the shared [CategoryEditorScreen]. Reached from Settings; Budget setup
/// gives the same categories a side-by-side layout.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../household_context.dart';
import 'category_editor_screen.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final names = ref.watch(userNamesProvider);
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final categories = state.slices.values.toList()
      ..sort((first, second) => first.name.compareTo(second.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Budget categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CategoryEditorScreen.open(context),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: categories.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No categories yet.\nAdd one to start budgeting.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final category = categories[i];
                final owner = category.isGroup
                    ? 'Group'
                    : (names[category.ownerUserId] ?? 'Personal');
                final mainCat = category.mainCategoryId == null
                    ? null
                    : state.mainCategories[category.mainCategoryId];
                final extras = <String>[
                  if (mainCat != null) mainCat.name,
                  if (!category.isGroup && category.poolTithePct > 0)
                    '${category.poolTithePct}% to savings',
                  if (category.emergencyContributionCents > 0)
                    '${money(category.emergencyContributionCents)} reserve',
                  if (category.taxDeductibleByDefault) 'tax',
                ];
                return ListTile(
                  leading: mainCat != null
                      ? CircleAvatar(
                          radius: 12,
                          backgroundColor: Color(mainCat.colorArgb),
                        )
                      : Icon(category.isGroup
                          ? Icons.groups_outlined
                          : Icons.person_outline),
                  title: Text(category.name),
                  subtitle: Text([owner, ...extras].join(' · ')),
                  trailing: Text(
                    money(category.limitCents),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () =>
                      CategoryEditorScreen.open(context, existing: category),
                );
              },
            ),
    );
  }
}
