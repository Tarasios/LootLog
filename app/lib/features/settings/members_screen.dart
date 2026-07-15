/// Members: the household party. Adults carry income, a vault and personal
/// categories; dependents and pets are display-level party members with no
/// ledger of their own. Each member has a name, a role, an optional character
/// description (used by text-mode adventure) and an optional custom sprite
/// (same blob pipeline as every other custom art). Retiring keeps history —
/// nothing is ever deleted.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/blobs/blob_store.dart';
import '../../data/providers.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';
import '../../ui/theme.dart';
import '../shared/sprite_picker.dart';
import 'member_edit_diff.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final members = state.members.values.toList()
      ..sort((a, b) {
        // Active first, then by role (adult, dependent, pet), then name.
        if (a.active != b.active) return a.active ? -1 : 1;
        final r = a.role.index.compareTo(b.role.index);
        return r != 0 ? r : a.name.compareTo(b.name);
      });
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('New'),
      ),
      body: members.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No members yet.\nAdd the adventurers, kids, and pets in your '
                  'party.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: members.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = members[i];
                return ListTile(
                  leading: Icon(_iconFor(m.role)),
                  title: Text(m.name),
                  subtitle: Text(_subtitle(m)),
                  trailing: m.active
                      ? null
                      : const Chip(label: Text('Retired')),
                  onTap: () => _edit(context, ref, existing: m),
                );
              },
            ),
    );
  }

  static IconData _iconFor(MemberRole role) => switch (role) {
        MemberRole.adult => Icons.person_outline,
        MemberRole.dependent => Icons.child_care_outlined,
        MemberRole.pet => Icons.pets_outlined,
      };

  static String _roleLabel(MemberRole role) => switch (role) {
        MemberRole.adult => 'Adult',
        MemberRole.dependent => 'Dependent',
        MemberRole.pet => 'Pet',
      };

  static String _subtitle(MemberState m) {
    final sprite = m.customSpriteSha256 == null ? 'Default sprite' : 'Custom sprite';
    return '${_roleLabel(m.role)} · $sprite';
  }

  Future<void> _edit(BuildContext context, WidgetRef ref,
      {MemberState? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController =
        TextEditingController(text: existing?.descriptionText ?? '');
    var role = existing?.role ?? MemberRole.adult;
    var active = existing?.active ?? true;
    String? spriteSha = existing?.customSpriteSha256;
    String? fundedBy = existing?.fundedByUserId;
    final adults = (ref.read(householdStateProvider).value?.members.values ??
            const <MemberState>[])
        .where((m) => m.isAdult && m.active)
        .toList();

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
          builder: (sheetContext, setSheet) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? 'New member' : 'Edit member',
                    style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Role', style: AppText.sectionLabel(sheetContext)),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<MemberRole>(
                  segments: const [
                    ButtonSegment(
                      value: MemberRole.adult,
                      label: Text('Adult'),
                      icon: Icon(Icons.person_outline),
                    ),
                    ButtonSegment(
                      value: MemberRole.dependent,
                      label: Text('Dependent'),
                      icon: Icon(Icons.child_care_outlined),
                    ),
                    ButtonSegment(
                      value: MemberRole.pet,
                      label: Text('Pet'),
                      icon: Icon(Icons.pets_outlined),
                    ),
                  ],
                  selected: {role},
                  onSelectionChanged: (s) => setSheet(() => role = s.first),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  role == MemberRole.adult
                      ? 'Adults carry income, a vault, and personal categories.'
                      : 'Display-only party member — no ledger of their own.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (role == MemberRole.pet && adults.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String?>(
                    initialValue: fundedBy,
                    decoration: const InputDecoration(
                      labelText: 'Whose budget funds this pet?',
                      helperText:
                          'The group splits pet costs by shares unless one '
                          'adult takes them on.',
                      helperMaxLines: 2,
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('The group')),
                      for (final a in adults)
                        DropdownMenuItem(
                            value: a.memberId, child: Text(a.name)),
                    ],
                    onChanged: (v) => setSheet(() => fundedBy = v),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: descController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    helperText: 'Used by text-mode adventure',
                  ),
                  textCapitalization: TextCapitalization.sentences,
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
                if (spriteSha != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _SpritePreview(sha256: spriteSha!),
                ],
                if (existing != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: const Text('Turn off to retire (history is kept)'),
                    value: active,
                    onChanged: (v) => setSheet(() => active = v),
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
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      final name = nameController.text.trim();
      final desc = descController.text.trim();
      final description = desc.isEmpty ? null : desc;
      final petFunding = role == MemberRole.pet ? fundedBy : null;
      if (existing != null &&
          !memberEditChanged(
            existing,
            name: name,
            role: role,
            active: active,
            customSpriteSha256: spriteSha,
            descriptionText: description,
            fundedByUserId: petFunding,
          )) {
        return; // Nothing changed — append no event.
      }
      await ref.read(householdActionsProvider)?.setMember(
            memberId: existing?.memberId,
            name: name,
            role: role,
            active: active,
            customSpriteSha256: spriteSha,
            descriptionText: description,
            fundedByUserId: petFunding,
          );
    }
  }
}

/// A small pixelated preview of an uploaded custom sprite, shown next to the
/// sprite tile in the member editor. Renders nothing (never an error) if the
/// blob is missing. The load future is memoized per sha so sheet rebuilds
/// (every setSheet call) don't refetch and flash the image.
class _SpritePreview extends ConsumerStatefulWidget {
  const _SpritePreview({required this.sha256});

  final String sha256;

  @override
  ConsumerState<_SpritePreview> createState() => _SpritePreviewState();
}

class _SpritePreviewState extends ConsumerState<_SpritePreview> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _loadBytes(ref.read(blobStoreProvider), widget.sha256);
  }

  @override
  void didUpdateWidget(covariant _SpritePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sha256 != widget.sha256) {
      _bytes = _loadBytes(ref.read(blobStoreProvider), widget.sha256);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return const SizedBox.shrink();
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            bytes,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
        );
      },
    );
  }

  static Future<Uint8List?> _loadBytes(BlobStore store, String sha) async {
    if (!await store.exists(sha)) return null;
    try {
      return await store.read(sha);
    } catch (_) {
      return null;
    }
  }
}
