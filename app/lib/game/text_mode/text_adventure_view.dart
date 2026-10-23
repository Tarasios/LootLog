/// The text-adventure dashboard (tier 3): a camp outside the dungeon, rendered
/// entirely as styled text panels — the party gathered around the campfire, the
/// current floor's monsters waiting at the dungeon entrance, the treasury
/// (gold pouch / war chest / reserve caches), the equipment-maintenance report,
/// and a scrolling adventure log in game voice. A pinned "strike a monster —
/// log a purchase" bar keeps quick entry one tap away, never scrolled off.
///
/// A pure [StatelessWidget]: it renders the [DungeonState] + [LogEntry] list the
/// adapter produced and calls back for the few actions. It reads only the game
/// read-model and never computes a cent, so it is widget-testable without the
/// data layer.
///
/// This file holds the view, its layout, the pinned prime action and the line
/// helpers the sections share; each section (camp, call-outs, dungeon
/// entrance, quest bosses, treasury, provisioning, log) is a part file under
/// `sections/`, written as a private extension on [TextAdventureView].
library;

import 'package:flutter/material.dart';

import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../dungeon_state.dart';
import 'text_widgets.dart';

part 'sections/adventure_log.dart';
part 'sections/callouts.dart';
part 'sections/camp.dart';
part 'sections/dungeon_entrance.dart';
part 'sections/provisioning.dart';
part 'sections/quest_bosses.dart';
part 'sections/treasury.dart';

/// The handful of things the text dashboard can trigger.
class TextAdventureCallbacks {
  const TextAdventureCallbacks({
    this.onStrikeMonster,
    this.onOpenSpoils,
    this.onSwitchToClassic,
    this.onSwitchToPixels,
    this.onSignWrit,
    this.onDeclineWrit,
    this.onSealLoan,
    this.onCancelLoan,
  });

  /// "Strike a monster" — log a purchase (the two-tap quick entry).
  final VoidCallback? onStrikeMonster;

  /// Open the month-close battle (dividing the spoils).
  final VoidCallback? onOpenSpoils;

  /// Drop to the Classic ledger view.
  final VoidCallback? onSwitchToClassic;

  /// Return to the pixel presentation (tiers 1–2). Null hides the toggle, so a
  /// caller that only offers Classic keeps a single control.
  final VoidCallback? onSwitchToPixels;

  final void Function(String proposalId)? onSignWrit;
  final void Function(String proposalId)? onDeclineWrit;

  /// Seals (approves) another adventurer's guild loan.
  final void Function(String advanceId)? onSealLoan;

  /// Refuses another adventurer's guild loan, or withdraws my own.
  final void Function(String advanceId)? onCancelLoan;
}

class TextAdventureView extends StatelessWidget {
  const TextAdventureView({
    super.key,
    required this.game,
    required this.log,
    this.encouragement,
    this.campAmbience,
    this.spoilsPending = false,
    this.callbacks = const TextAdventureCallbacks(),
  });

  final DungeonState game;
  final List<LogEntry> log;

  /// A supportive line drawn from `assets/game/text/`, shown atop the log.
  final String? encouragement;

  /// A scene-setting ambience line drawn from `assets/game/text/`, spoken at
  /// the campfire. Falls back to a built-in line when the assets are unloaded.
  final String? campAmbience;

  /// Whether a month-close battle is waiting to be fought.
  final bool spoilsPending;

  final TextAdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _campHeader(context),
                    if (spoilsPending) _spoilsCallout(context),
                    for (final ransack in game.warChest.ransacks)
                      _ransack(context, ransack),
                    if (game.overbudgets.isNotEmpty) _overbudgets(context),
                    _dungeonEntrance(context),
                    if (game.questMonsters.isNotEmpty) _questBosses(context),
                    _treasury(context),
                    if (game.warChest.writsForMe.isNotEmpty ||
                        game.warChest.writsForOther.isNotEmpty)
                      _writs(context),
                    if (game.warChest.loans.isNotEmpty) _loans(context),
                    if (game.provisioning.isNotEmpty) _provisioning(context),
                    _logPanel(context),
                  ],
                ),
              ),
            ),
          ),
        ),
        _strikeBar(context),
      ],
    );
  }

  /// The pinned prime action: quick entry, never scrolled away.
  Widget _strikeBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: callbacks.onStrikeMonster,
                      icon: const Icon(Icons.bolt),
                      label: const Text('Strike a monster — log a purchase'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hpLine(
    BuildContext context, {
    required String name,
    required String bar,
    required String value,
    required String tag,
    Color? tint,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle(context, weight: FontWeight.w600)),
              ),
              if (tag.isNotEmpty)
                Text(tag,
                    style: monoStyle(context,
                        color: tint ?? scheme.onSurfaceVariant)),
            ],
          ),
          Text('$bar  $value',
              style: monoStyle(context, color: tint ?? scheme.primary)),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value, {bool subtle = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: monoStyle(context,
                  color: subtle ? scheme.onSurfaceVariant : null)),
        ),
        Text(value,
            style: monoStyle(context,
                weight: subtle ? FontWeight.w400 : FontWeight.w700,
                color: subtle ? scheme.onSurfaceVariant : null)),
      ],
    );
  }
}
