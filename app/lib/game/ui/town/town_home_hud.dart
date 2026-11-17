/// The town HUD at home, assembled from the game state, the town's ledger
/// figures and the loop's notes: the date, streak, gems, gold pouch and war
/// chest; the "No spend today" chip; Log purchase and the corner buttons;
/// the district strip; and, while decorating, the decoration tray. The
/// visiting HUD is `NeighbourHud` (`neighbour_view.dart`).
library;

import 'package:flutter/material.dart';

import '../../../ui/format.dart';
import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/town/town_ledger.dart';
import '../habit_actions.dart';
import '../hall_common.dart';
import '../hall_home_sections.dart' show HallHomeData;
import '../hall_ledger_view.dart';
import '../hall_status.dart';
import '../hall_voice.dart';
import '../kit/kit.dart' show HudChip;
import 'hud_insets.dart';
import 'town_hud.dart';
import 'town_loop_wiring.dart' show TownLoopParts;

class TownHomeHud extends StatelessWidget {
  const TownHomeHud({
    super.key,
    required this.game,
    required this.ledgerView,
    required this.voice,
    required this.now,
    required this.ledger,
    required this.loop,
    required this.links,
    required this.onOpenLedger,
    required this.onLogPurchase,
    required this.onShop,
    required this.onInbox,
    required this.onMenu,
    required this.onDate,
    this.onQuests,
    this.districtStrip,
    this.decoratePanel,
    this.insets,
  });

  final GameState game;
  final HallLedgerView ledgerView;
  final HallVoice voice;
  final DateTime now;
  final TownLedger ledger;
  final TownLoopParts loop;
  final HallLinks links;
  final VoidCallback onOpenLedger;
  final VoidCallback onLogPurchase;
  final VoidCallback onShop;
  final VoidCallback onInbox;
  final VoidCallback onMenu;
  final VoidCallback onDate;
  final VoidCallback? onQuests;
  final Widget? districtStrip;
  final Widget? decoratePanel;
  final HudInsets? insets;

  @override
  Widget build(BuildContext context) {
    final today = GameDay.fromInstant(now);
    final me = game.person(ledgerView.meId ?? '');
    return TownHud(
      figures: TownHudFigures(
        dateLabel: '${monthAbbreviation(today.month)} · day ${today.day}',
        streak: liveStreak(me.streak, today, tokens: me.freezeTokens),
        freezeTokens: me.freezeTokens,
        gems: me.gems,
        inboxCount: me.unopenedChests.length + me.unclaimedRewards.length,
        goldPouch: ledger.goldPouch,
        warChest: ledger.warChest,
      ),
      onQuests: onQuests,
      spiritBar: loop.spiritBar,
      logNotes: loop.logNotes,
      noSpendCheckIn: NoSpendCheckIn(
        key: const ValueKey('town-no-spend'),
        explainWhenUnavailable: true,
        data: HallHomeData(
          game: game,
          view: ledgerView,
          voice: voice,
          now: now,
          onOpenLedger: onOpenLedger,
          links: links,
        ),
        builder: (context, action) =>
            // Never wider than a narrow phone's corner (it ellipsizes).
            HudChip(
              icon: action.icon,
              value: action.shortLabel,
              onTap: action.onPressed,
              maxWidth: MediaQuery.sizeOf(context).width - 24,
              prose: true,
            ),
      ),
      onLogPurchase: onLogPurchase,
      onShop: onShop,
      onInbox: onInbox,
      onLedger: onOpenLedger,
      onMenu: onMenu,
      onDate: onDate,
      districtStrip: districtStrip,
      decoratePanel: decoratePanel,
      insets: insets,
    );
  }
}
