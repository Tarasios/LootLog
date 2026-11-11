/// The town loop wired into the town shell: what the HUD and the scene show
/// (the spirit bar, the "Log today" note, the day's visitor, the festival
/// bunting), and the once-a-day / once-a-weekend pop-ups — "while you were
/// away" first, then the festival celebration. A pop-up only opens while
/// the town itself is on top (never over the log-purchase screen), and
/// logging stays one tap away behind it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/asset_registry.dart';
import '../../data/game_providers.dart';
import '../../domain/game_state.dart';
import '../../domain/town/town_event_lines.dart';
import '../../scenes/town/town_scene_view.dart' show TownLoopScene;
import 'away_summary_dialog.dart';
import 'daily_event_dialog.dart';
import 'festival_dialog.dart';
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
  Widget? logHint,
});

/// The town loop for the shell's state.
mixin TownLoopWiring<Shell extends ConsumerStatefulWidget> on ConsumerState<Shell> {
  /// A loop pop-up is open (or about to be): no second one stacks on it.
  bool _loopPopupOpen = false;

  /// The loop's parts for [meId] as of [now], and any pop-up now due. Call
  /// once per build of the pixel town, with the builder's [watchRef].
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
    if (meId.isNotEmpty && ref.read(gameStateProvider).hasValue) _schedulePopups(view, shown, lines);
    final offer = view.offer;
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
      logHint: view.dayOpened || meId.isEmpty ? null : TownLogHint(lines.line('tag.openTown')),
    );
  }

  void _schedulePopups(TownLoopView view, TownLoopShown shown, TownEventLines lines) {
    if (_loopPopupOpen || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final memory = ref.read(townLoopShownProvider.notifier);
    final today = view.today;
    final festival = view.festival;
    Future<void> Function()? open;
    if (shown.awayDue(today) && !view.away.isEmpty) {
      open = () {
        memory.markAwayShown(today);
        return showAwaySummary(context, ref, summary: view.away, lines: lines);
      };
    } else if (festival != null && shown.festivalDue(today)) {
      open = () {
        memory.markFestivalShown(today);
        return showFestivalDialog(context, ref, tier: festival, rewards: view.festivalRewards, lines: lines);
      };
    }
    if (open == null) return;
    final popup = open;
    // Marked and opened after this frame: never while building.
    _loopPopupOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await popup();
      _loopPopupOpen = false;
      // Look again: the festival may be waiting behind the summary.
      if (mounted) setState(() {});
    });
  }
}
