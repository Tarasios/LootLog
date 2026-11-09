/// The town's quest board: a wood board docked beside the town on a wide
/// window (or slid in from the right on a phone) that keeps goals front and
/// centre — the savings-goal bosses, any OVERBUDGET to clear, writs waiting
/// for a signature, this month's category monsters and the latest loot.
///
/// A goal opens the Goals pane; anything else opens the ledger.
/// [showQuestBoardSheet] is the phone's right-side sheet.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../assets/game_asset_scope.dart';
import '../../domain/town/quest_board_view.dart';
import '../kit/kit.dart';
import 'quest_board_rows.dart';

/// The docked board's width on a wide window.
const double kQuestBoardWidth = 340;

/// The sheet is at most this wide (and never past 90% of the screen).
const double _kSheetMaxWidth = 360;

class QuestBoard extends StatelessWidget {
  const QuestBoard({
    super.key,
    required this.board,
    required this.onOpenGoals,
    required this.onOpenLedger,
    this.goalPictures = const {},
    this.onCollapse,
  });

  final QuestBoardView board;

  /// Decoded goal pictures by sha256; a goal without one shows the boss.
  final Map<String, ui.Image> goalPictures;

  final VoidCallback onOpenGoals;
  final VoidCallback onOpenLedger;

  /// Folds the board away (docked) or closes it (sheet); no chevron if null.
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final onCollapse = this.onCollapse;
    return WoodPanel(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Center(child: RibbonTitle('Quest board'))),
              if (onCollapse != null)
                KitPressable(
                  key: const ValueKey('quest-board-collapse'),
                  onPressed: onCollapse,
                  semanticsLabel: 'Fold the quest board away',
                  minHitSize: const Size(44, 44),
                  builder: (context, pressed) => const Icon(
                    Icons.chevron_right,
                    size: 28,
                    color: AdventureTokens.parchment,
                  ),
                ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4),
              children: _sections(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sections() => [
    const QuestBoardHeading('Goals'),
    if (board.goals.isEmpty)
      NoteRow(
        text: 'Set a savings goal to chase',
        icon: Icons.flag,
        onTap: onOpenGoals,
      ),
    for (final goal in board.goals)
      GoalRow(
        goal: goal,
        picture: goalPictures[goal.pictureSha256],
        onTap: onOpenGoals,
      ),
    if (board.debts.isNotEmpty) ...[
      const QuestBoardHeading('OVERBUDGET'),
      for (final debt in board.debts) DebtRow(debt: debt, onTap: onOpenLedger),
    ],
    if (board.pendingWrits > 0)
      NoteRow(
        text: 'Writs to sign: ${board.pendingWrits}',
        icon: Icons.history_edu,
        onTap: onOpenLedger,
      ),
    if (board.monsters.isNotEmpty) ...[
      const QuestBoardHeading('This month'),
      for (final monster in board.monsters)
        MonsterRow(monster: monster, onTap: onOpenLedger),
    ],
    if (board.recent.isNotEmpty) ...[
      const QuestBoardHeading('Recent loot'),
      RecentLootCard(entries: board.recent),
    ],
  ];
}

/// Slides the quest board in from the right as a sheet, min(360, 90%) wide.
/// [build] builds the board with a close callback, so it stays live with the
/// town's providers (wrap it in a consumer to rebuild).
Future<void> showQuestBoardSheet(
  BuildContext context, {
  required Widget Function(BuildContext context, VoidCallback close) build,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close the quest board',
  barrierColor: const Color(0x66000000),
  transitionDuration: const Duration(milliseconds: 200),
  pageBuilder: (dialogContext, animation, secondaryAnimation) {
    final width = MediaQuery.sizeOf(dialogContext).width;
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: width * 0.9 < _kSheetMaxWidth ? width * 0.9 : _kSheetMaxWidth,
        height: double.infinity,
        child: SafeArea(
          left: false,
          child: Material(
            type: MaterialType.transparency,
            // The sheet is its own route, above the town's sprite scope.
            child: AdventureSpriteScope(
              child: build(dialogContext, () => Navigator.of(dialogContext).pop()),
            ),
          ),
        ),
      ),
    );
  },
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
      SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
);
