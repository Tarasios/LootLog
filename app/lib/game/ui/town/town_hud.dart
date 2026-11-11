/// The town's heads-up display, floating over the scene like a village
/// builder's: the date, streak and freeze tokens top-left; gems, the gold
/// pouch and the war chest top-right; "Log purchase" (with the no-spend
/// check-in above it) bottom-left; Shop, Inbox, Ledger and Menu bottom-right.
/// The district strip sits at the top centre under the chips. A narrow
/// window stacks the corners and lays the buttons in one row along the
/// bottom, with the district strip just above Log purchase (in thumb reach,
/// never over it). Tapping the date opens the town book. Each top corner is
/// held to half the width, its chips ellipsizing, so the corners never
/// collide. While decorating, the
/// decoration tray replaces the buttons (Log purchase stays, and the Menu,
/// to finish).
///
/// Only empty space between the pieces lets taps through to the town.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../kit/kit.dart';
import 'town_hud_chips.dart';

export 'town_hud_chips.dart' show TownHudFigures;

/// Below this width the HUD stacks its corners and lines the buttons up.
const double kTownHudCompactWidth = 640;

/// Keeps the HUD clear of the window edge.
const double _kEdge = 12;

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
    this.spiritBar,
    this.logHint,
    this.districtStrip,
    this.onDate,
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

  /// The week's town spirit, under the date chip.
  final Widget? spiritBar;

  /// Notes over the check-in: what the crews made, "Log today to open the
  /// town".
  final Widget? logHint;

  /// The strip of districts; hidden while decorating.
  final Widget? districtStrip;

  /// Opens the town book from the date chip.
  final VoidCallback? onDate;

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
        final timeCorner = _corner(
          key: const ValueKey('town-hud-time'),
          compact: compact,
          width: cornerWidth,
          alignEnd: false,
          chips: _timeChips(cornerWidth),
        );
        final treasureCorner = _corner(
          key: const ValueKey('town-hud-treasure'),
          compact: compact,
          width: cornerWidth,
          alignEnd: true,
          chips: _treasureChips(compact, cornerWidth),
        );
        final topStrip = compact || decoratePanel != null ? null : districtStrip;
        return Stack(
          children: [
            if (topStrip == null) ...[
              Positioned(top: _kEdge, left: _kEdge, child: timeCorner),
              Positioned(top: _kEdge, right: _kEdge, child: treasureCorner),
            ] else
              // The strip hangs under the taller corner, centred.
              Positioned(
                top: _kEdge,
                left: _kEdge,
                right: _kEdge,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [timeCorner, const Spacer(), treasureCorner],
                    ),
                    const SizedBox(height: AdventureTokens.gap),
                    topStrip,
                  ],
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

  List<Widget> _timeChips(double maxWidth) =>
      townTimeChips(figures, maxWidth: maxWidth, spiritBar: spiritBar, onDate: onDate);

  List<Widget> _treasureChips(bool compact, double maxWidth) =>
      townTreasureChips(figures, compact: compact, maxWidth: maxWidth);

  Widget _logButton() => HudButton(
    label: 'Log purchase',
    icon: Icons.add_shopping_cart,
    large: true,
    onPressed: onLogPurchase,
  );

  /// The notes, the check-in and Log purchase, with [strip] (the phone's
  /// district strip) just above Log purchase.
  Widget _logColumn({Widget? strip}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (logHint case final hint?) ...[hint, const SizedBox(height: AdventureTokens.gap)],
      noSpendCheckIn,
      const SizedBox(height: AdventureTokens.gap),
      if (strip != null) ...[strip, const SizedBox(height: AdventureTokens.gap)],
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
      Align(alignment: Alignment.centerLeft, child: _logColumn(strip: districtStrip)),
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
