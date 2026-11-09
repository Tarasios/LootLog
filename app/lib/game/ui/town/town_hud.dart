/// The town's heads-up display, floating over the scene like a village
/// builder's: the date, streak and freeze tokens top-left; gems, the gold
/// pouch and the war chest top-right; "Log purchase" (with the no-spend
/// check-in above it) bottom-left; Shop, Inbox, Ledger and Menu bottom-right.
/// A narrow window stacks the corners and lays the buttons in one row along
/// the bottom. Each top corner is held to half the width, its chips
/// ellipsizing, so the corners never collide. While decorating, the
/// decoration tray replaces the buttons (Log purchase stays, and the Menu,
/// to finish).
///
/// Only empty space between the pieces lets taps through to the town.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/money.dart';
import '../../../ui/format.dart';
import '../hall_status.dart';
import '../kit/kit.dart';

/// Below this width the HUD stacks its corners and lines the buttons up.
const double kTownHudCompactWidth = 640;

/// Keeps the HUD clear of the window edge.
const double _kEdge = 12;

/// The figures the HUD shows. Money is null until the ledger loads.
class TownHudFigures {
  const TownHudFigures({
    required this.dateLabel,
    required this.streak,
    required this.freezeTokens,
    required this.gems,
    required this.inboxCount,
    this.goldPouch,
    this.warChest,
  });

  /// "Oct · day 3".
  final String dateLabel;
  final LiveStreak streak;
  final int freezeTokens;
  final int gems;

  /// Unopened chests plus unclaimed rewards.
  final int inboxCount;
  final Money? goldPouch;
  final Money? warChest;
}

class TownHud extends StatelessWidget {
  const TownHud({
    super.key,
    required this.figures,
    required this.noSpendCheckIn,
    required this.onLogPurchase,
    required this.onShop,
    required this.onInbox,
    required this.onLedger,
    required this.onMenu,
    this.onQuests,
    this.decoratePanel,
  });

  final TownHudFigures figures;

  /// The "No spend today" chip, built by the shell.
  final Widget noSpendCheckIn;
  final VoidCallback onLogPurchase;
  final VoidCallback onShop;
  final VoidCallback onInbox;
  final VoidCallback onLedger;
  final VoidCallback onMenu;

  /// Shows the quest board when it is not docked; no button when null.
  final VoidCallback? onQuests;

  /// The decoration tray, while decorating; it replaces the buttons.
  final Widget? decoratePanel;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < kTownHudCompactWidth;
        // Each top corner gets at most half the width between the edges (less
        // a gap), so a long streak and a huge war chest can never collide.
        final cornerWidth = math.max(
          0.0,
          (constraints.maxWidth - 2 * _kEdge - AdventureTokens.gap) / 2,
        );
        final decoratePanel = this.decoratePanel;
        return Stack(
          children: [
            Positioned(
              top: _kEdge,
              left: _kEdge,
              child: _corner(
                key: const ValueKey('town-hud-time'),
                compact: compact,
                width: cornerWidth,
                alignEnd: false,
                chips: _timeChips(cornerWidth),
              ),
            ),
            Positioned(
              top: _kEdge,
              right: _kEdge,
              child: _corner(
                key: const ValueKey('town-hud-treasure'),
                compact: compact,
                width: cornerWidth,
                alignEnd: true,
                chips: _treasureChips(compact, cornerWidth),
              ),
            ),
            if (decoratePanel != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logging a purchase stays one tap away while decorating.
                    Padding(
                      padding: const EdgeInsets.all(_kEdge),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(child: _logButton()),
                          const Spacer(),
                          _menuButton(),
                        ],
                      ),
                    ),
                    decoratePanel,
                  ],
                ),
              )
            else if (compact)
              Positioned(left: _kEdge, right: _kEdge, bottom: _kEdge, child: _compactBottom())
            else ...[
              Positioned(left: _kEdge, bottom: _kEdge, child: _logColumn()),
              Positioned(
                right: _kEdge,
                bottom: _kEdge,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _spaced(_cornerButtons()),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );

  /// One top corner, at most [width] wide: chips stacked on a narrow window,
  /// side by side (wrapping when they run out of room) on a wide one.
  Widget _corner({
    required Key key,
    required bool compact,
    required double width,
    required bool alignEnd,
    required List<Widget> chips,
  }) => ConstrainedBox(
    key: key,
    constraints: BoxConstraints(maxWidth: width),
    child: compact
        ? Column(
            crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: _spaced(chips, vertical: true),
          )
        : Wrap(
            alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
            spacing: AdventureTokens.gap,
            runSpacing: 6,
            children: chips,
          ),
  );

  List<Widget> _timeChips(double maxWidth) => [
    HudChip(icon: Icons.calendar_today, value: figures.dateLabel, maxWidth: maxWidth),
    HudChip(
      icon: Icons.local_fire_department,
      color: AdventureTokens.hpRed,
      value: figures.streak.isEmpty ? 'Start a streak' : '${figures.streak.days}-day streak',
      valueKey: const ValueKey('town-streak'),
      maxWidth: maxWidth,
    ),
    HudChip(
      icon: Icons.ac_unit,
      color: AdventureTokens.gem,
      value: '${figures.freezeTokens}',
      valueKey: const ValueKey('town-freeze-tokens'),
      maxWidth: maxWidth,
    ),
  ];

  List<Widget> _treasureChips(bool compact, double maxWidth) {
    final goldPouch = figures.goldPouch;
    final warChest = figures.warChest;
    return [
      HudChip(
        icon: Icons.diamond,
        color: AdventureTokens.gem,
        value: '${figures.gems}',
        valueKey: const ValueKey('town-gems'),
        maxWidth: maxWidth,
      ),
      if (goldPouch != null)
        HudChip(
          icon: Icons.savings,
          color: AdventureTokens.gold,
          value: money(goldPouch.cents),
          label: compact ? null : 'gold pouch',
          valueKey: const ValueKey('town-gold-pouch'),
          maxWidth: maxWidth,
        ),
      if (warChest != null)
        HudChip(
          icon: Icons.account_balance,
          color: AdventureTokens.chest,
          value: money(warChest.cents),
          label: compact ? null : 'war chest',
          valueKey: const ValueKey('town-war-chest'),
          maxWidth: maxWidth,
        ),
    ];
  }

  Widget _logButton() => HudButton(
    label: 'Log purchase',
    icon: Icons.add_shopping_cart,
    large: true,
    onPressed: onLogPurchase,
  );

  Widget _logColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      noSpendCheckIn,
      const SizedBox(height: AdventureTokens.gap),
      _logButton(),
    ],
  );

  Widget _menuButton() => HudButton(
    key: const ValueKey('town-menu'),
    label: 'Menu',
    icon: Icons.menu,
    onPressed: onMenu,
  );

  List<Widget> _cornerButtons() {
    final onQuests = this.onQuests;
    return [
      HudButton(label: 'Shop', icon: Icons.storefront, onPressed: onShop),
      HudButton(
        label: 'Inbox',
        icon: Icons.inventory_2,
        onPressed: onInbox,
        badge: figures.inboxCount > 0 ? '${figures.inboxCount}' : null,
      ),
      if (onQuests != null) HudButton(label: 'Quests', icon: Icons.flag, onPressed: onQuests),
      HudButton(label: 'Ledger', icon: Icons.menu_book, onPressed: onLedger),
      _menuButton(),
    ];
  }

  /// The phone's bottom: the check-in and Log purchase, then every button
  /// spread along one row.
  Widget _compactBottom() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(alignment: Alignment.centerLeft, child: _logColumn()),
      const SizedBox(height: AdventureTokens.gap),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        // Each button may shrink (its label ellipsizes) to share the row.
        children: [for (final button in _cornerButtons()) Flexible(child: button)],
      ),
    ],
  );

  /// [widgets] with a gap between each pair.
  static List<Widget> _spaced(List<Widget> widgets, {bool vertical = false}) => [
    for (final (index, widget) in widgets.indexed) ...[
      if (index > 0)
        vertical ? const SizedBox(height: 6) : const SizedBox(width: AdventureTokens.gap),
      widget,
    ],
  ];
}
