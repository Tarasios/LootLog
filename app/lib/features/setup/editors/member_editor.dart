part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Editor (bottom sheet) for a party member — returned via a typed result
// ---------------------------------------------------------------------------

class MemberDraftResult {
  const MemberDraftResult(
      {required this.name, this.description, this.sprite, this.fundedBy});
  final String name;
  final String? description;
  final String? sprite;

  /// Pet only: the adult localId funding this pet's budgets (null = group).
  final String? fundedBy;
}

Future<MemberDraftResult?> showMemberEditor(
  BuildContext context,
  WidgetRef ref, {
  required DraftRole role,
  DraftMember? existing,
  List<DraftMember> adults = const [],
}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final descriptionController = TextEditingController(text: existing?.descriptionText ?? '');
  String? sprite = existing?.spriteSha256;
  String? fundedBy = existing?.fundedByUserId;

  return showModalBottomSheet<MemberDraftResult>(
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
              Text('${existing == null ? 'New' : 'Edit'} ${_roleWord(role)}',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Character description (optional)',
                  helperText: 'Invited free text — feeds text-mode adventure',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined),
                title: Text(sprite == null ? 'Default sprite' : 'Custom sprite'),
                trailing: Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    if (sprite != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setSheet(() => sprite = null),
                      ),
                    TextButton(
                      onPressed: () async {
                        final sha = await _pickSprite(ref, sheetContext);
                        if (sha != null) setSheet(() => sprite = sha);
                      },
                      child: const Text('Choose PNG'),
                    ),
                  ],
                ),
              ),
              if (role == DraftRole.pet && adults.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
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
                    for (final adult in adults)
                      DropdownMenuItem(value: adult.localId, child: Text(adult.name)),
                  ],
                  onChanged: (value) => setSheet(() => fundedBy = value),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final desc = descriptionController.text.trim();
                  Navigator.of(sheetContext).pop(MemberDraftResult(
                    name: name,
                    description: desc.isEmpty ? null : desc,
                    sprite: sprite,
                    fundedBy: fundedBy,
                  ));
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Onboarding-time sprite ingest: the household actions provider is still null
/// (no member exists yet), so ingest straight through the blob store.
Future<String?> _pickSprite(WidgetRef ref, BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  const typeGroup = XTypeGroup(label: 'PNG image', extensions: ['png']);
  final file = await openFile(acceptedTypeGroups: const [typeGroup]);
  if (file == null) return null;
  try {
    final bytes = await file.readAsBytes();
    final ingested = await ingestSprite(bytes, ref.read(blobStoreProvider));
    return ingested.sha256;
  } on SpriteRejected catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('Sprite rejected: ${error.message}')));
  } on Object {
    messenger.showSnackBar(
        const SnackBar(content: Text('Could not read that image')));
  }
  return null;
}
