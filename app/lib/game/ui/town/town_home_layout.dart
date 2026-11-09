/// The town home's frame: the scene fills the window with the HUD floating
/// over it, and on a wide window (at least [kWideTownWidth]) the quest board
/// docks on the right — foldable, remembered per device. On a narrow window,
/// or with the board folded, a Quests button brings it back (as a sheet
/// sliding in from the right on a narrow window).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../decor/goal_pictures.dart';
import 'quest_board.dart';
import 'quest_board_prefs.dart';
import 'town_ledger_provider.dart';

/// Windows at least this wide dock the quest board beside the town.
const double kWideTownWidth = 1100;

/// Builds the HUD; [onQuests] shows the board when it is not docked.
typedef TownHudBuilder = Widget Function(VoidCallback? onQuests);

class TownHomeLayout extends ConsumerWidget {
  const TownHomeLayout({
    super.key,
    required this.scene,
    required this.buildHud,
    required this.onOpenGoals,
    required this.onOpenLedger,
  });

  /// The town scene (or its loading backdrop).
  final Widget scene;
  final TownHudBuilder buildHud;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenLedger;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= kWideTownWidth;
      final collapsed = ref.watch(questBoardCollapsedProvider);
      final collapse = ref.read(questBoardCollapsedProvider.notifier);
      final docked = wide && !collapsed;
      final VoidCallback onQuests = wide
          ? () => unawaited(collapse.select(false))
          : () => unawaited(
              showQuestBoardSheet(
                context,
                build: (sheetContext, close) => LiveQuestBoard(
                  onOpenGoals: () {
                    close();
                    onOpenGoals();
                  },
                  onOpenLedger: () {
                    close();
                    onOpenLedger();
                  },
                  onCollapse: close,
                ),
              ),
            );
      final town = Stack(
        children: [
          Positioned.fill(child: scene),
          Positioned.fill(child: buildHud(docked ? null : onQuests)),
        ],
      );
      // Always a row, so folding the board never rebuilds the scene.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: town),
          if (docked)
            SizedBox(
              width: kQuestBoardWidth,
              child: LiveQuestBoard(
                onOpenGoals: onOpenGoals,
                onOpenLedger: onOpenLedger,
                onCollapse: () => unawaited(collapse.select(true)),
              ),
            ),
        ],
      );
    },
  );
}

/// The quest board over the live ledger figures and goal pictures, so a
/// docked board or an open sheet updates as purchases land.
class LiveQuestBoard extends ConsumerWidget {
  const LiveQuestBoard({
    super.key,
    required this.onOpenGoals,
    required this.onOpenLedger,
    this.onCollapse,
  });

  final VoidCallback onOpenGoals;
  final VoidCallback onOpenLedger;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) => QuestBoard(
    board: ref.watch(townLedgerProvider).board,
    goalPictures: ref.watch(goalPictureImagesProvider).unwrapPrevious().value ?? const {},
    onOpenGoals: onOpenGoals,
    onOpenLedger: onOpenLedger,
    onCollapse: onCollapse,
  );
}
