/// The Homestead — meta-progression visualization of the war chest.
///
/// Text-mode-first: the homestead's build stage and progress render as a styled
/// text panel with a block-character bar, so the screen is complete before any
/// pixel art exists. Each stage carries a sprite slot for a later art tier. This
/// is pure visualization of the real pool balance — nothing here gates or
/// modifies a cent (the firewall).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/event.dart';
import '../../domain/ids.dart';
import '../../game/rewards/homestead.dart';
import '../../game/text_mode/text_widgets.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';

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
          // Sprite slot: a labelled placeholder until the pixel tier lands.
          _StageArtSlot(view: view),
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

/// A labelled placeholder for the (later) pixel-art stage sprite — the partial
/// asset tier. Never blocks the screen on missing art.
class _StageArtSlot extends StatelessWidget {
  const _StageArtSlot({required this.view});

  final HomesteadView view;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surfaceContainerHighest,
      ),
      child: Text(
        view.currentStage.spriteSlot,
        style: monoStyle(context, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _StagesPanel extends StatelessWidget {
  const _StagesPanel({required this.view});

  final HomesteadView view;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Rebuild the configured ladder for the checklist; the view already knows
    // the current stage index via stageNumber.
    final defaults = HomesteadConfig.defaults();
    return TextPanel(
      title: 'The ladder',
      icon: Icons.stairs_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < defaults.stages.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${i < view.stageNumber ? '[x]' : '[ ]'} '
                '${defaults.stages[i].name}'
                '${defaults.stages[i].thresholdCents > 0 ? '  (${money(defaults.stages[i].thresholdCents)})' : ''}',
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
