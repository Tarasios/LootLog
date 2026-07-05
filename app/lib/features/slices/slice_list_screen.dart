/// A flat list of every budget slice, grouped by owner, with add/edit routing
/// into the shared [SliceEditorScreen]. Reached from Settings; Budget setup gives
/// the same slices a side-by-side layout.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../household_context.dart';
import 'slice_editor_screen.dart';

class SliceListScreen extends ConsumerWidget {
  const SliceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final names = ref.watch(userNamesProvider);
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final slices = state.slices.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Budget slices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => SliceEditorScreen.open(context),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: slices.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No slices yet.\nAdd one to start budgeting.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: slices.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = slices[i];
                final owner = s.isGroup
                    ? 'Group'
                    : (names[s.ownerUserId] ?? 'Personal');
                final extras = <String>[
                  if (!s.isGroup && s.poolTithePct > 0)
                    '${s.poolTithePct}% tithe',
                  if (s.emergencyContributionCents > 0)
                    '${money(s.emergencyContributionCents)} reserve',
                  if (s.taxDeductibleByDefault) 'tax',
                ];
                return ListTile(
                  leading: Icon(
                      s.isGroup ? Icons.groups_outlined : Icons.person_outline),
                  title: Text(s.name),
                  subtitle: Text([owner, ...extras].join(' · ')),
                  trailing: Text(
                    money(s.limitCents),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => SliceEditorScreen.open(context, existing: s),
                );
              },
            ),
    );
  }
}
