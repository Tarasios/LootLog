/// The Homestead — meta-progression visualization of the war chest.
///
/// Text-mode-first: the homestead's build stage and progress render as a styled
/// text panel with a block-character bar, so the screen is complete before any
/// pixel art exists. Each stage carries a sprite slot for a later art tier, and
/// a stage may reference a user-uploaded sprite blob (the same pipeline as
/// member sprites). The flavour name and the stage ladder are editable —
/// cosmetic settings synced as events. This is pure visualization of the real
/// pool balance — nothing here gates or modifies a cent (the firewall).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/blobs/blob_store.dart';
import '../../data/providers.dart';
import '../../domain/event.dart';
import '../../domain/ids.dart';
import '../../game/rewards/homestead.dart';
import '../../game/text_mode/text_widgets.dart';
import '../../ui/format.dart';
import '../../ui/money_input.dart';
import '../../ui/theme.dart';
import '../shared/sprite_picker.dart';

class HomesteadScreen extends ConsumerWidget {
  const HomesteadScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HomesteadScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(homesteadViewProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(view?.flavorName ?? 'Homestead'),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: view == null ? null : () => _rename(context, ref, view),
          ),
          IconButton(
            tooltip: 'Edit stages',
            icon: const Icon(Icons.stairs_outlined),
            onPressed: view == null
                ? null
                : () => HomesteadStagesEditor.open(context),
          ),
        ],
      ),
      body: view == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [_HomesteadPanel(view: view), _StagesPanel(view: view)],
            ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    HomesteadView view,
  ) async {
    final controller = TextEditingController(text: view.flavorName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'What are you building?',
            helperText: 'e.g. Homestead, Town, The Ward',
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == view.flavorName) return;
    final actions = ref.read(householdActionsProvider);
    if (actions == null) return;
    final now = DateTime.now().toUtc();
    await actions.append(CosmeticSet(
      eventId: uuidv7(),
      deviceId: actions.deviceId,
      userId: actions.meUserId,
      occurredAt: now,
      createdAt: now,
      key: 'homestead.flavor',
      value: name,
    ));
  }
}

class _HomesteadPanel extends StatelessWidget {
  const _HomesteadPanel({required this.view});

  final HomesteadView view;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final next = view.nextStage;
    return TextPanel(
      title: '${view.flavorName} — stage ${view.stageNumber}/${view.totalStages}',
      icon: Icons.cottage_outlined,
      accent: scheme.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sprite slot: a custom stage sprite if one was uploaded, else a
          // labelled placeholder until the pixel tier lands.
          _StageArtSlot(stage: view.currentStage),
          const SizedBox(height: AppSpacing.md),
          Text(view.currentStage.name,
              style: monoStyle(context, weight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          Text('War chest: ${money(view.balanceCents)}',
              style: monoStyle(context, color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${textBar(view.progressToNext)}  '
            '${(view.progressToNext * 100).round()}%',
            style: monoStyle(context, color: scheme.tertiary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            next == null
                ? 'The build is complete — nothing left to raise.'
                : '${money(view.centsToNextStage!)} more to "${next.name}".',
            style: monoStyle(context, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// The current stage's art: the user-uploaded stage sprite when one exists
/// (rendered pixelated, like every custom sprite), else a labelled placeholder
/// slot — the partial asset tier. Never blocks the screen on missing art.
class _StageArtSlot extends ConsumerWidget {
  const _StageArtSlot({required this.stage});

  final HomesteadStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final sha = stage.customSpriteSha256;
    return Container(
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surfaceContainerHighest,
      ),
      child: sha == null
          ? Text(
              stage.spriteSlot,
              style: monoStyle(context, color: scheme.onSurfaceVariant),
            )
          : _BlobSprite(
              sha256: sha,
              fallback: Text(
                stage.spriteSlot,
                style: monoStyle(context, color: scheme.onSurfaceVariant),
              ),
            ),
    );
  }
}

/// A pixelated render of a sprite blob; shows [fallback] while loading or when
/// the blob is missing on this device. Never an error box.
class _BlobSprite extends ConsumerWidget {
  const _BlobSprite({required this.sha256, required this.fallback});

  final String sha256;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(blobStoreProvider);
    return FutureBuilder<Uint8List?>(
      future: _loadBytes(store, sha256),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return fallback;
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            bytes,
            height: 88,
            fit: BoxFit.contain,
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

class _StagesPanel extends ConsumerWidget {
  const _StagesPanel({required this.view});

  final HomesteadView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final stages = ref.watch(homesteadConfigProvider).stages;
    return TextPanel(
      title: 'The ladder',
      icon: Icons.stairs_outlined,
      trailing: TextButton(
        onPressed: () => HomesteadStagesEditor.open(context),
        child: const Text('Edit'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stages.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${i < view.stageNumber ? '[x]' : '[ ]'} '
                '${stages[i].name}'
                '${stages[i].thresholdCents > 0 ? '  (${money(stages[i].thresholdCents)})' : ''}',
                style: monoStyle(
                  context,
                  color: i == view.stageNumber - 1
                      ? scheme.tertiary
                      : scheme.onSurfaceVariant,
                  weight:
                      i == view.stageNumber - 1 ? FontWeight.w800 : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Stage ladder editor — cosmetic settings only.
// ===========================================================================

/// One stage row being edited (name, threshold text, optional sprite blob).
class _StageDraft {
  _StageDraft({required this.name, required this.threshold, this.spriteSha});

  final TextEditingController name;
  final TextEditingController threshold;
  String? spriteSha;

  void dispose() {
    name.dispose();
    threshold.dispose();
  }
}

/// Edits the homestead's stage ladder: names, thresholds and optional custom
/// stage art. Saves a `homestead.stages` cosmetic event — display thresholds
/// for the war chest visualization, never a gate on any money.
class HomesteadStagesEditor extends ConsumerStatefulWidget {
  const HomesteadStagesEditor({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HomesteadStagesEditor()),
      );

  @override
  ConsumerState<HomesteadStagesEditor> createState() =>
      _HomesteadStagesEditorState();
}

class _HomesteadStagesEditorState extends ConsumerState<HomesteadStagesEditor> {
  late final List<_StageDraft> _drafts;

  @override
  void initState() {
    super.initState();
    final stages = ref.read(homesteadConfigProvider).stages;
    _drafts = [for (final s in stages) _draftOf(s)];
  }

  _StageDraft _draftOf(HomesteadStage s) => _StageDraft(
        name: TextEditingController(text: s.name),
        threshold: TextEditingController(
            text: s.thresholdCents == 0
                ? '0'
                : (s.thresholdCents % 100 == 0
                    ? '${s.thresholdCents ~/ 100}'
                    : (s.thresholdCents / 100).toStringAsFixed(2))),
        spriteSha: s.customSpriteSha256,
      );

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  /// Builds the cosmetic value from the drafts, or null with a reason when the
  /// ladder is invalid.
  (List<Map<String, Object?>>?, String?) _validate() {
    final maps = <Map<String, Object?>>[];
    var last = -1;
    for (var i = 0; i < _drafts.length; i++) {
      final d = _drafts[i];
      final name = d.name.text.trim();
      if (name.isEmpty) return (null, 'Stage ${i + 1} needs a name.');
      final cents = i == 0 ? 0 : tryParseMoneyCents(d.threshold.text);
      if (cents == null) {
        return (null, 'Stage ${i + 1} needs a valid amount.');
      }
      if (cents <= last) {
        return (
          null,
          'Stage ${i + 1} must cost more than the stage before it.',
        );
      }
      last = cents;
      maps.add({
        'name': name,
        'thresholdCents': cents,
        if (d.spriteSha != null) 'spriteSha256': d.spriteSha,
      });
    }
    if (maps.isEmpty) return (null, 'Keep at least one stage.');
    return (maps, null);
  }

  Future<void> _save() async {
    final (value, error) = _validate();
    final messenger = ScaffoldMessenger.of(context);
    if (value == null) {
      messenger.showSnackBar(SnackBar(content: Text(error!)));
      return;
    }
    // Round-trip through the pure parser so the saved value is exactly what
    // every device will read back.
    assert(stagesFromCosmetic(value) != null);
    final actions = ref.read(householdActionsProvider);
    if (actions == null) return;
    final navigator = Navigator.of(context);
    final now = DateTime.now().toUtc();
    await actions.append(CosmeticSet(
      eventId: uuidv7(),
      deviceId: actions.deviceId,
      userId: actions.meUserId,
      occurredAt: now,
      createdAt: now,
      key: 'homestead.stages',
      value: value,
    ));
    if (navigator.mounted) navigator.pop();
  }

  Future<void> _resetToDefaults() async {
    final actions = ref.read(householdActionsProvider);
    if (actions == null) return;
    final navigator = Navigator.of(context);
    final now = DateTime.now().toUtc();
    // A null ladder value reads back as "use the defaults" on every device.
    await actions.append(CosmeticSet(
      eventId: uuidv7(),
      deviceId: actions.deviceId,
      userId: actions.meUserId,
      occurredAt: now,
      createdAt: now,
      key: 'homestead.stages',
      value: null,
    ));
    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit stages'),
        actions: [
          TextButton(
            onPressed: _resetToDefaults,
            child: const Text('Reset to defaults'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Stages are display thresholds for the war-chest picture — '
            'change them freely, no money moves.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < _drafts.length; i++) _stageCard(context, i),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => setState(() => _drafts.add(_StageDraft(
                  name: TextEditingController(),
                  threshold: TextEditingController(),
                ))),
            icon: const Icon(Icons.add),
            label: const Text('Add stage'),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _save, child: const Text('Save')),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  Widget _stageCard(BuildContext context, int i) {
    final scheme = Theme.of(context).colorScheme;
    final d = _drafts[i];
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Stage ${i + 1}',
                      style: AppText.sectionLabel(context)),
                ),
                if (_drafts.length > 1)
                  IconButton(
                    tooltip: 'Remove stage',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        setState(() => _drafts.removeAt(i).dispose()),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
              ],
            ),
            TextField(
              controller: d.name,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: d.threshold,
              enabled: i > 0,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Reached at',
                prefixText: r'$ ',
                helperText: i == 0
                    ? 'The first stage always starts at \$0.'
                    : 'War-chest balance that unlocks this stage.',
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    d.spriteSha == null
                        ? 'Default art slot'
                        : 'Custom stage art set',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (d.spriteSha != null) ...[
                  _BlobSprite(
                    sha256: d.spriteSha!,
                    fallback: const SizedBox.shrink(),
                  ),
                  IconButton(
                    tooltip: 'Remove art',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => d.spriteSha = null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
                TextButton(
                  onPressed: () async {
                    final sha = await pickAndIngestSprite(
                        ref, ScaffoldMessenger.of(context));
                    if (sha != null) setState(() => d.spriteSha = sha);
                  },
                  child: const Text('Choose PNG'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
