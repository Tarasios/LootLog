/// The celebration of a finished Castle stage: the Castle as it now stands,
/// the stage's own line, and for the banners (the last stage) the title the
/// finished Castle brings. Opened only on entering the town
/// (`town_loop_wiring.dart`), never mid-session or over Log purchase.
library;

import 'package:flutter/material.dart';

import '../../assets/asset_catalog.dart';
import '../../config/balance.dart';
import '../../domain/town/town_growth_lines.dart';
import '../hall_common.dart' show showHallCelebration;
import 'town_loop_view.dart' show fillLine;

/// Celebrates [stagesDone] finished Castle stages (1–5).
Future<void> showCastleStageCelebration(BuildContext context,
    {required int stagesDone, required TownGrowthLines lines}) {
  final spec = Balance.castleStages[stagesDone - 1];
  final complete = stagesDone == Balance.castleStages.length;
  return showHallCelebration(
    context,
    sprite: GameAssetKeys.castleStage(stagesDone),
    title: fillLine(lines.line('castle.stageReached'), {'stage': lines.line(castleStageNameKey(spec.key))}),
    lines: [
      lines.line(castleStageDoneKey(spec.key)),
      if (complete) lines.line('castle.titleEarned'),
    ],
  );
}
