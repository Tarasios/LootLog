/// Visiting a neighbour's town, wired into the town shell: which neighbour is
/// being visited, the signpost (straight to the one town down the road, or a
/// chooser for several), read-only taps while visiting, and the visiting
/// HUD with its gift and cheer. The scene and the district strip are the
/// shell's own, drawn from the neighbour's town; no town command can run
/// from a visit.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/game_state.dart';
import '../../domain/town/districts.dart' show kOutpostDistrictId;
import '../../domain/town/neighbour_lines.dart';
import '../../domain/town/neighbours.dart';
import '../../domain/town/town_growth_lines.dart';
import '../../domain/town/town_view.dart';
import 'gift_dialog.dart';
import 'hud_insets.dart';
import 'neighbour_actions.dart';
import 'neighbour_providers.dart';
import 'neighbour_view.dart';
import 'town_growth_providers.dart';

mixin TownNeighbourWiring<Shell extends ConsumerStatefulWidget> on ConsumerState<Shell> {
  String? _visitingId;

  /// Opens a district of the town on screen (from the district wiring).
  void openDistrict(String districtId);

  /// The neighbour being visited, among [neighbours]; null at home, or once
  /// their town can no longer be visited.
  TownNeighbour? visitingAmong(List<TownNeighbour> neighbours) =>
      neighbours.where((neighbour) => neighbour.canVisit && neighbour.memberId == _visitingId).firstOrNull;

  /// Called as a visit starts, inside its `setState`: the shell ends
  /// anything a visit must not carry (decorating).
  void onVisitStarted() {}

  /// Walks down the road into [neighbour]'s outpost.
  void visitNeighbour(TownNeighbour neighbour) {
    openDistrict(kOutpostDistrictId);
    setState(() {
      onVisitStarted();
      _visitingId = neighbour.memberId;
    });
  }

  /// Back to this adult's own outpost.
  void leaveNeighbour() {
    openDistrict(kOutpostDistrictId);
    setState(() => _visitingId = null);
  }

  /// The signpost: the one town down the road opens at once; several open a
  /// chooser (with the caravan camp noted, never named).
  void openSignpost(List<TownNeighbour> neighbours) {
    final visitable = [
      for (final neighbour in neighbours)
        if (neighbour.canVisit) neighbour,
    ];
    if (visitable.isEmpty) return;
    if (visitable.length == 1) {
      visitNeighbour(visitable.single);
      return;
    }
    final lines = ref.read(neighbourLinesProvider).value ?? NeighbourLines.defaults;
    unawaited(showSignpostChooser(context, neighbours: neighbours, lines: lines, onVisit: visitNeighbour));
  }

  /// A tap in a neighbour's town: a plot opens a read-only note; the gate,
  /// houses and everything else do nothing.
  void openVisitTarget(TownTarget target, TownView view, TownNeighbour visiting) {
    if (target is! PlotTarget) return;
    final plot = view.plots
        .where((plot) => plot.plotIndex == target.plotIndex && plot.districtId == target.districtId)
        .firstOrNull;
    if (plot == null) return;
    unawaited(showNeighbourPlotInfo(
      context,
      plot: plot,
      neighbourName: visiting.name,
      lines: ref.read(neighbourLinesProvider).value ?? NeighbourLines.defaults,
      growthLines: ref.read(townGrowthLinesProvider).value ?? TownGrowthLines.defaults,
    ));
  }

  /// The HUD while visiting [visiting]: Back, Log purchase (for this
  /// device's adult), Send a gift and Cheer (once a day).
  Widget neighbourHud({
    required TownNeighbour visiting,
    required GameState game,
    required String meId,
    required DateTime now,
    required VoidCallback onLogPurchase,
    Widget? districtStrip,
    HudInsets? insets,
  }) {
    final lines = ref.watch(neighbourLinesProvider).value ?? NeighbourLines.defaults;
    final cheered = cheeredToday(game, meId, visiting, now);
    return NeighbourHud(
      header: lines.line('visit.header', {'name': visiting.name}),
      onBack: leaveNeighbour,
      onLogPurchase: onLogPurchase,
      onGift: () => unawaited(showGiftDialog(context, visiting)),
      onCheer: cheered ? null : () => unawaited(cheerNeighbour(context, ref, visiting, lines)),
      cheerLabel: cheered ? lines.line('cheer.done') : 'Cheer',
      districtStrip: districtStrip,
      insets: insets,
    );
  }
}
