/// Emergency funds ("reserve caches"): create, rename, and optionally link to a
/// pet. Balances are derived (contributions less emergency-charged spending); the
/// list shows them read-only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/state.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';

class EmergencyFundsScreen extends ConsumerWidget {
  const EmergencyFundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final funds = state.emergencyFunds.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency funds')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editFund(context, ref, state),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: funds.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No emergency funds yet.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: funds.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final f = funds[i];
                final petName =
                    f.petId == null ? null : state.pets[f.petId]?.name;
                return ListTile(
                  leading: const Icon(Icons.emergency_outlined),
                  title: Text(f.name),
                  subtitle: petName == null ? null : Text('Pet: $petName'),
                  trailing: Text(
                    money(f.balanceCents),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => _editFund(context, ref, state, existing: f),
                );
              },
            ),
    );
  }

  Future<void> _editFund(
    BuildContext context,
    WidgetRef ref,
    HouseholdState state, {
    EmergencyFundState? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String? petId = existing?.petId;
    final pets = state.pets.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: StatefulBuilder(
          builder: (context, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'New emergency fund' : 'Edit fund',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String?>(
                initialValue: petId,
                decoration: const InputDecoration(labelText: 'Pet (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  for (final p in pets)
                    DropdownMenuItem(value: p.petId, child: Text(p.name)),
                ],
                onChanged: (v) => setSheet(() => petId = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      await ref.read(householdActionsProvider)?.setEmergencyFund(
            fundId: existing?.fundId,
            name: nameController.text.trim(),
            petId: petId,
          );
    }
  }
}
