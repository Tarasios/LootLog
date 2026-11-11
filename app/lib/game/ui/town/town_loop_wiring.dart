/// The town loop wired into the town shell: what the HUD and the scene show
/// (the spirit bar, the "crews made" chip, the "Log today" note, the day's
/// visitor, the festival bunting), and the celebrations on entering: a new
/// town tier first, otherwise the weekend festival (one per entry).
///
/// Logging is never blocked or delayed: what the crews made waits behind a
/// small chip that opens the summary only when tapped, and the festival
/// celebration opens by itself only on entering the town (the shell's first
/// build, or the app coming back to the front) while the town is on top —
/// never from the ticker or a game-state change mid-session, and never over
/// the log-purchase screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/asset_registry.dart';
import '../../data/game_providers.dart';
import '../../domain/game_state.dart';
import '../../domain/game_values.dart' show TownTier;
import '../../domain/town/town_event_lines.dart';
import '../../domain/town/town_growth_lines.dart';
import '../../scenes/town/town_scene_view.dart' show TownLoopScene;
import '../kit/kit.dart' show HudChip, AdventureTokens;
import 'away_summary_dialog.dart';
import 'daily_event_dialog.dart';
import 'festival_dialog.dart';
import 'tier_up_dialog.dart';
import 'town_book_screen.dart';
import 'town_growth_providers.dart';
import 'town_log_hint.dart';
import 'town_loop_providers.dart';
import 'town_loop_view.dart';
import 'town_spirit_bar.dart';

/// What the shell hands the HUD and the scene.
typedef TownLoopParts = ({
  TownLoopScene scene,
  String? visitorTag,
  VoidCallback? onVisitorTap,
  Widget spiritBar,
  List<Widget> logNotes,
});

/// The town loop for the shell's state.
mixin TownLoopWiring<Shell extends ConsumerStatefulWidget> on ConsumerState<Shell> {
  /// Set on entering the town; the festival may open once while it holds.
  bool _enteringTown = true;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _enteringTown = true;
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  /// The loop's parts for [meId] as of [now]. Call once per build of the
  /// pixel town, with the builder's [watchRef].
  TownLoopParts townLoopParts(
    WidgetRef watchRef, {
    required GameState game,
    required String meId,
    required DateTime now,
    required AssetRegistry registry,
  }) {
    final lines = watchRef.watch(townEventLinesProvider).value ?? TownEventLines.defaults;
    final shown = watchRef.watch(townLoopShownProvider);
    final view = TownLoopView.from(game, meId, now);
    _maybeCelebrateOnEntry(
      view,
      shown,
      lines,
      tierDue: shown.tierDue(game.person(meId), now),
      ready: meId.isNotEmpty && ref.read(gameStateProvider).hasValue,
    );
    final offer = view.offer;
    final away = view.away;
    final madeCount = [
      for (final row in away.producers) ...row.fits.amounts.values,
    ].fold(0, (sum, amount) => sum + amount);
    final notes = <Widget>[
      if (madeCount > 0)
        HudChip(
          key: const ValueKey('town-away-chip'),
          icon: Icons.inventory_2,
          color: AdventureTokens.gainInk,
          value: fillLine(lines.line('away.chip'), {'count': '$madeCount'}),
          maxWidth: MediaQuery.sizeOf(context).width - 24,
          prose: true,
          onTap: () => unawaited(showAwaySummary(context, ref, summary: away, lines: lines)),
        ),
      if (!view.dayOpened && meId.isNotEmpty) TownLogHint(lines.line('tag.openTown')),
    ];
    return (
      scene: TownLoopScene(
        visitorKey: offer == null ? null : visitorAssetKey(offer.kind, registry),
        visitorLabel: offer == null ? '' : visitorLabel(offer.kind),
        festival: view.festival,
      ),
      visitorTag: offer == null ? null : lines.visitorTag(offer, view.offerBuilding),
      onVisitorTap: offer == null
          ? null
          : () => unawaited(
              showDailyEventDialog(context, ref, offer: offer, building: view.offerBuilding, lines: lines),
            ),
      spiritBar: TownSpiritBar(
        key: const ValueKey('town-spirit'),
        days: view.spiritDays,
        weekend: view.weekend,
        onTap: () => unawaited(showTownSpiritDialog(context, view, lines)),
      ),
      logNotes: notes,
    );
  }

  /// On entering the town, opens a new tier's celebration, or else this
  /// weekend's festival, once (per device), after the frame and only if the
  /// town is still on top then.
  void _maybeCelebrateOnEntry(
    TownLoopView view,
    TownLoopShown shown,
    TownEventLines lines, {
    required TownTier? tierDue,
    required bool ready,
  }) {
    if (!_enteringTown || !ready || !shown.loaded) return;
    // Entering is decided now: a later tick or state change is mid-session.
    _enteringTown = false;
    if (tierDue != null) {
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
        ref.read(townLoopShownProvider.notifier).markTierShown(tierDue);
        unawaited(
          showTierUpDialog(
            context,
            tier: tierDue,
            lines: ref.read(townGrowthLinesProvider).value ?? TownGrowthLines.defaults,
            openBook: () => unawaited(TownBookScreen.open(context)),
          ),
        );
      });
      return;
    }
    final festival = view.festival;
    if (festival == null || !shown.festivalDue(view.today)) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Something (the log-purchase screen) may have covered the town since.
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      ref.read(townLoopShownProvider.notifier).markFestivalShown(view.today);
      unawaited(
        showFestivalDialog(context, ref, tier: festival, rewards: view.festivalRewards, lines: lines),
      );
    });
  }
}
