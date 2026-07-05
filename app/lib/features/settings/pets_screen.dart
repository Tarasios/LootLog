/// Pets: display-level party members with a name and an optional custom sprite.
/// Pets have no ledger; slices and emergency funds may reference one. Sprites go
/// through the same blob pipeline (PNG, ≤128px) as every other custom art.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/state.dart';
import '../../ui/theme.dart';
import '../shared/sprite_picker.dart';

class PetsScreen extends ConsumerWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pets = state.pets.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: const Text('Pets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editPet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: pets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No pets yet.\nAdd a party member.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: pets.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = pets[i];
                return ListTile(
                  leading: const Icon(Icons.pets_outlined),
                  title: Text(p.name),
                  subtitle: Text(p.customSpriteSha256 == null
                      ? 'Default sprite'
                      : 'Custom sprite'),
                  onTap: () => _editPet(context, ref, existing: p),
                );
              },
            ),
    );
  }

  Future<void> _editPet(BuildContext context, WidgetRef ref,
      {PetState? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String? spriteSha = existing?.customSpriteSha256;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'New pet' : 'Edit pet',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined),
                title: Text(spriteSha == null
                    ? 'Default sprite'
                    : 'Custom sprite set'),
                trailing: Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    if (spriteSha != null)
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => setSheet(() => spriteSha = null),
                        icon: const Icon(Icons.close),
                      ),
                    TextButton(
                      onPressed: () async {
                        final sha = await pickAndIngestSprite(
                            ref, ScaffoldMessenger.of(sheetContext));
                        if (sha != null) setSheet(() => spriteSha = sha);
                      },
                      child: const Text('Choose PNG'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      await ref.read(householdActionsProvider)?.setPet(
            petId: existing?.petId,
            name: nameController.text.trim(),
            customSpriteSha256: spriteSha,
          );
    }
  }
}
