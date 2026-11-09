/// The town's heads-up display, floating over the scene like a village
/// builder's: the date, streak and freeze tokens top-left; gems, the gold
/// pouch and the war chest top-right; "Log purchase" (with the no-spend
/// check-in above it) bottom-left; Shop, Inbox, Ledger and Menu bottom-right.
/// A narrow window stacks the corners and lays the buttons in one row along
/// the bottom. While decorating, the decoration tray replaces the buttons
/// (the Menu stays, to finish).
///
/// Only empty space between the pieces lets taps through to the town.
library;

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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < kTownHudCompactWidth;
      final decoratePanel = this.decoratePanel;
      return SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: _kEdge,
              left: _kEdge,
              child: _corner(compact, CrossAxisAlignment.start, _timeChips()),
            ),
            Positioned(
              top: _kEdge,
              right: _kEdge,
              child: _corner(compact, CrossAxisAlignment.end, _treasureChips(compact)),
            ),
            if (decoratePanel != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(padding: const EdgeInsets.all(_kEdge), child: _menuButton()),
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
        ),
      );
    },
  );

  /// Chips side by side on a wide window, stacked on a narrow one.
  Widget _corner(bool compact, CrossAxisAlignment alignment, List<Widget> chips) => compact
      ? Column(crossAxisAlignment: alignment, children: _spaced(chips, vertical: true))
      : Row(children: _spaced(chips));

  List<Widget> _timeChips() => [
    HudChip(icon: Icons.calendar_today, value: figures.dateLabel),
    HudChip(
      icon: Icons.local_fire_department,
      color: AdventureTokens.hpRed,
      value: figures.streak.isEmpty ? 'Start a streak' : '${figures.streak.days}-day streak',
      valueKey: const ValueKey('town-streak'),
    ),
    HudChip(
      icon: Icons.ac_unit,
      color: AdventureTokens.gem,
      value: '${figures.freezeTokens}',
      valueKey: const ValueKey('town-freeze-tokens'),
    ),
  ];

  List<Widget> _treasureChips(bool compact) {
    final goldPouch = figures.goldPouch;
    final warChest = figures.warChest;
    return [
      HudChip(
        icon: Icons.diamond,
        color: AdventureTokens.gem,
        value: '${figures.gems}',
        valueKey: const ValueKey('town-gems'),
      ),
      if (goldPouch != null)
        HudChip(
          icon: Icons.savings,
          color: AdventureTokens.gold,
          value: money(goldPouch.cents),
          label: compact ? null : 'gold pouch',
          valueKey: const ValueKey('town-gold-pouch'),
        ),
      if (warChest != null)
        HudChip(
          icon: Icons.account_balance,
          color: AdventureTokens.chest,
          value: money(warChest.cents),
          label: compact ? null : 'war chest',
          valueKey: const ValueKey('town-war-chest'),
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
    children: [noSpendCheckIn, const SizedBox(height: AdventureTokens.gap), _logButton()],
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
        children: [
          for (final button in _cornerButtons()) Flexible(child: button),
        ],
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
