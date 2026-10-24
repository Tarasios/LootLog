/// The shared Adventure / Standard switch, reachable from both modes: an
/// overflow-menu entry for the ledger shell and the guild hall, and a
/// segmented control at the top of Settings. Every path asks for the same
/// one-line confirmation (it is reversible and nothing is lost) and then
/// records the person's choice through `play_mode_providers.dart`.
///
/// Lives outside `lib/game/` so Standard mode can offer the way back into
/// Adventure without loading any game objects.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../ui/glossary.dart';
import '../../ui/theme.dart';
import 'play_mode.dart';
import 'play_mode_providers.dart';

/// The mode the other side of the switch leads to.
PlayMode otherPlayMode(PlayMode mode) =>
    mode == PlayMode.adventure ? PlayMode.standard : PlayMode.adventure;

String _modeLabel(PlayMode mode) => (mode == PlayMode.adventure
        ? Glossary.adventureMode
        : Glossary.standardMode)
    .classic;

/// Confirms, then switches this device's adult to [target]. With
/// [returnHome] the navigator first pops back to the launch screen, which
/// rebuilds for the new mode. Returns whether the switch was recorded.
Future<bool> confirmAndSwitchPlayMode(
  BuildContext context,
  WidgetRef ref,
  PlayMode target, {
  bool returnHome = false,
}) async {
  final actions = ref.read(householdActionsProvider);
  if (actions == null) return false;
  final switchLabel =
      Glossary.switchPlayModeLabel(toAdventure: target == PlayMode.adventure);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('$switchLabel?'),
      content: const Text(Glossary.playModeSwitchReassurance),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Switch'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  if (returnHome) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
  await setPlayMode(actions, target);
  return true;
}

/// The app-bar overflow menu holding the Adventure / Standard switch.
class PlayModeMenuButton extends ConsumerWidget {
  const PlayModeMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = (ref.watch(playPrefsProvider) ?? PlayPrefs.defaults).mode;
    final target = otherPlayMode(current);
    return PopupMenuButton<PlayMode>(
      tooltip: 'More options',
      icon: const Icon(Icons.more_vert),
      onSelected: (mode) => unawaited(
        confirmAndSwitchPlayMode(context, ref, mode, returnHome: true),
      ),
      itemBuilder: (_) => [
        PopupMenuItem<PlayMode>(
          value: target,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.swap_horiz),
            title: Text(Glossary.playMode.classic),
            subtitle: Text(Glossary.switchPlayModeLabel(
              toAdventure: target == PlayMode.adventure,
            )),
          ),
        ),
      ],
    );
  }
}

/// The Adventure / Standard switch at the top of Settings.
class PlayModeSwitchTile extends ConsumerWidget {
  const PlayModeSwitchTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = (ref.watch(playPrefsProvider) ?? PlayPrefs.defaults).mode;
    final helperStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_esports_outlined),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Glossary.playMode.classic),
                    Text(Glossary.playMode.helper, style: helperStyle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<PlayMode>(
            segments: [
              for (final mode in const [PlayMode.adventure, PlayMode.standard])
                ButtonSegment(value: mode, label: Text(_modeLabel(mode))),
            ],
            selected: {current},
            onSelectionChanged: (selection) => unawaited(
              confirmAndSwitchPlayMode(context, ref, selection.first),
            ),
          ),
        ],
      ),
    );
  }
}
