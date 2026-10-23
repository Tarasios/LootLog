/// The pixel-art adventure presentation (tiers 1–2): the dungeon-crawler main
/// screen. Party-member frames with HP bars flank a central floor viewport whose
/// monsters are sized by their budget; a year minimap charts the floors and a
/// scrolling adventure log runs alongside.
///
/// A pure [StatelessWidget]: it renders the [DungeonState] + [LogEntry] list the
/// adapter produced and calls back for the few actions, so it is golden-testable
/// at any size. Sprites resolve through the injected [SpriteResolver]:
///
///   * Tier 1 — a resolver returns art, sprites render as pixels.
///   * Tier 2 — a sprite is missing, so *that* [GameSprite] degrades to its own
///     labelled placeholder while everything around it stays art.
///
/// (Tier 3, text mode, is a separate screen reached by the global text-mode
/// toggle.) Every number here is copied from [DungeonState]; this file adds pixels
/// and layout, never arithmetic.
///
/// This file holds the view, its callbacks and the wide/narrow layouts; each
/// panel (camp banner, party frames, floor viewport, minimap, treasury, log,
/// call-outs) is a part file under `panels/` — its build helpers as a private
/// extension on [PixelAdventureView], next to the tiles only it uses.
library;

import 'package:flutter/material.dart';

import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../adapter.dart' show Sprites;
import '../game_sprite.dart';
import '../dungeon_state.dart';
import '../text_mode/text_widgets.dart' show toneStyle;

part 'panels/adventure_log.dart';
part 'panels/callouts.dart';
part 'panels/camp_banner.dart';
part 'panels/floor_viewport.dart';
part 'panels/minimap.dart';
part 'panels/party_frames.dart';
part 'panels/pixel_chrome.dart';
part 'panels/treasury.dart';

/// The actions the pixel dashboard can trigger; all optional (no-ops in goldens).
class PixelAdventureCallbacks {
  const PixelAdventureCallbacks({
    this.onStrikeMonster,
    this.onOpenSpoils,
    this.onSwitchToText,
    this.onSwitchToClassic,
    this.onSignWrit,
    this.onDeclineWrit,
    this.onSealLoan,
    this.onCancelLoan,
  });

  /// "Strike a monster" — the two-tap quick entry (log a purchase).
  final VoidCallback? onStrikeMonster;

  /// Open the month-close battle (dividing the spoils).
  final VoidCallback? onOpenSpoils;

  /// Drop to the text-adventure tier (the global text-mode toggle).
  final VoidCallback? onSwitchToText;

  /// Drop to the Classic ledger view.
  final VoidCallback? onSwitchToClassic;

  final void Function(String proposalId)? onSignWrit;
  final void Function(String proposalId)? onDeclineWrit;

  /// Seals (approves) another adventurer's guild loan.
  final void Function(String advanceId)? onSealLoan;

  /// Refuses another adventurer's guild loan, or withdraws my own.
  final void Function(String advanceId)? onCancelLoan;
}

/// The width at or above which the screen lays out as three columns (party
/// frames · floor viewport · log); below it the same pieces stack vertically.
const double _wideBreakpoint = 760;

class PixelAdventureView extends StatelessWidget {
  const PixelAdventureView({
    super.key,
    required this.game,
    required this.log,
    this.resolver = const PlaceholderSpriteResolver(),
    this.encouragement,
    this.campAmbience,
    this.spoilsPending = false,
    this.animate = true,
    this.callbacks = const PixelAdventureCallbacks(),
  });

  final DungeonState game;
  final List<LogEntry> log;
  final SpriteResolver resolver;

  /// Whether idle sprites animate. Off makes rendering deterministic (goldens).
  final bool animate;

  /// A supportive line drawn from `assets/game/text/`, shown atop the log.
  final String? encouragement;

  /// A scene-setting ambience line drawn from `assets/game/text/`, spoken at
  /// the campfire. Null hides the line.
  final String? campAmbience;

  /// Whether a month-close battle is waiting to be fought.
  final bool spoilsPending;

  final PixelAdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            return wide ? _wide(context) : _narrow(context);
          }),
        ),
        _strikeBar(context),
      ],
    );
  }

  /// The pinned prime action — quick entry, never scrolled away.
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
    );
  }

  Widget _wide(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _campBanner(context),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 240,
                  child: SingleChildScrollView(child: _partyColumn(context)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: ListView(
                    children: [
                      if (spoilsPending) ...[
                        _spoilsCta(context),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      for (final ransack in game.warChest.ransacks) ...[
                        _ransack(context, ransack),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      for (final debt in game.overbudgets) ...[
                        _overbudget(context, debt),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _floorViewport(context),
                      const SizedBox(height: AppSpacing.md),
                      _minimap(context),
                      const SizedBox(height: AppSpacing.md),
                      _treasury(context),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 280,
                  child: _logPanel(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrow(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _campBanner(context),
        const SizedBox(height: AppSpacing.md),
        if (spoilsPending) ...[
          _spoilsCta(context),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final ransack in game.warChest.ransacks) ...[
          _ransack(context, ransack),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final debt in game.overbudgets) ...[
          _overbudget(context, debt),
          const SizedBox(height: AppSpacing.md),
        ],
        _partyStrip(context),
        const SizedBox(height: AppSpacing.md),
        _floorViewport(context),
        const SizedBox(height: AppSpacing.md),
        _minimap(context),
        const SizedBox(height: AppSpacing.md),
        _treasury(context),
        const SizedBox(height: AppSpacing.md),
        SizedBox(height: 320, child: _logPanel(context)),
      ],
    );
  }
}

// ===========================================================================
// Per-member health reading for a party frame.
// ===========================================================================

