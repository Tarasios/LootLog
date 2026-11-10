/// The Adventure dress for the budget shell: when an Adventure player opens
/// the Dashboard, Ledger, Goals, Treasury or Trophies from the town, the
/// panes sit inside the game's wood-and-parchment frame instead of Material's
/// app bar, navigation rail and bottom bar.
///
/// Only the chrome changes. The pane widgets are handed in by `AppShell`
/// exactly as Standard builds them (same providers, same numbers), and this
/// file reads no game state: it draws kit widgets around whatever it is given,
/// under the device's art tier (`AdventureSpriteScope`).
///
/// - Header: a wood bar with the pane's name on a ribbon, a "Town" button
///   back to the town, "Divide the spoils" while a ritual is pending, Manage,
///   and "More" (the Adventure / Standard switch).
/// - Tabs (`adventure_shell_tabs.dart`): wood buttons, the open pane's in
///   dark wood. On desktop they sit under the header; on a phone they are
///   the bottom bar.
/// - Desktop pins the activity feed on the right as the "Adventure log".
/// - Quick actions: "Log purchase" (large) and "Scan" as HUD buttons.
library;

import 'package:flutter/material.dart';

import '../../game/assets/game_asset_scope.dart' show AdventureSpriteScope;
import '../../game/ui/kit/kit.dart';
import '../settings/play_mode_switch.dart';
import '../spoils/spoils_screen.dart';
import 'adventure_shell_tabs.dart';

export 'adventure_shell_tabs.dart' show AdventureShellTab, AdventureTabStrip;

/// The width of the pinned Adventure log on desktop (Standard's activity
/// pane is the same width).
const double kAdventureLogWidth = 360;

/// The whole Adventure shell: header, tabs, the pane, the desktop log and the
/// quick actions.
class AdventureShellScaffold extends StatelessWidget {
  const AdventureShellScaffold({
    super.key,
    required this.title,
    required this.wide,
    required this.tabs,
    required this.selectedTab,
    required this.onSelectTab,
    required this.pane,
    required this.onOpenManage,
    required this.onLogPurchase,
    required this.onScanReceipt,
    this.adventureLog,
    this.onOpenTown,
  });

  /// The open pane's name, shown on the header's ribbon.
  final String title;

  /// Desktop layout (tabs under the header, the log pinned on the right).
  final bool wide;
  final List<AdventureShellTab> tabs;

  /// The index into [tabs] of the open pane, or null when the open pane has
  /// no tab of its own (the trophy hall reached from Goals on a phone).
  final int? selectedTab;
  final ValueChanged<int> onSelectTab;

  /// The pane body, built exactly as in Standard.
  final Widget pane;

  /// The activity feed, pinned on the right on desktop. Ignored on phones,
  /// where the feed is a tab.
  final Widget? adventureLog;

  /// Goes back to the town; null hides the Town button.
  final VoidCallback? onOpenTown;
  final VoidCallback onOpenManage;
  final VoidCallback onLogPurchase;
  final VoidCallback onScanReceipt;

  @override
  Widget build(BuildContext context) {
    final header = _AdventureShellHeader(
      title: title,
      onOpenTown: onOpenTown,
      onOpenManage: onOpenManage,
    );
    final tabStrip = AdventureTabStrip(
      tabs: tabs,
      selectedTab: selectedTab,
      onSelectTab: onSelectTab,
      compact: !wide,
    );
    final quickActions = AdventureQuickActions(
      onLogPurchase: onLogPurchase,
      onScanReceipt: onScanReceipt,
    );
    final framedPane = _PanePage(child: pane);
    // The frames follow the device's art tier like every Adventure screen:
    // the UI pack's pixel art, or the drawn fallbacks in text mode.
    return AdventureSpriteScope(
      child: wide
          ? _wideLayout(header, tabStrip, framedPane, quickActions)
          : Scaffold(
              body: Column(
                children: [
                  header,
                  Expanded(child: framedPane),
                ],
              ),
              bottomNavigationBar: WoodPanel(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                child: SafeArea(top: false, child: tabStrip),
              ),
              floatingActionButton: quickActions,
            ),
    );
  }

  /// Desktop: the header, the tabs under it, then the pane beside the log.
  Widget _wideLayout(
    Widget header,
    Widget tabStrip,
    Widget framedPane,
    Widget quickActions,
  ) {
    final adventureLog = this.adventureLog;
    // The quick actions sit in the corner under the log, like the town's HUD,
    // instead of floating over the log's last lines.
    final sideColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (adventureLog != null)
          Expanded(child: AdventureLogPanel(child: adventureLog))
        else
          const Spacer(),
        const SizedBox(height: AdventureTokens.gap),
        Align(alignment: Alignment.centerRight, child: quickActions),
      ],
    );
    return Scaffold(
      body: Column(
        children: [
          header,
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdventureTokens.gapLarge,
              AdventureTokens.gap,
              AdventureTokens.gapLarge,
              0,
            ),
            child: Align(alignment: Alignment.centerLeft, child: tabStrip),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AdventureTokens.gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: framedPane),
                  const SizedBox(width: AdventureTokens.gap),
                  SizedBox(width: kAdventureLogWidth, child: sideColumn),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The wood header: Town, the ribbon title, then the spoils button (while a
/// ritual is pending), Manage and More.
class _AdventureShellHeader extends StatelessWidget {
  const _AdventureShellHeader({
    required this.title,
    required this.onOpenTown,
    required this.onOpenManage,
  });

  final String title;
  final VoidCallback? onOpenTown;
  final VoidCallback onOpenManage;

  @override
  Widget build(BuildContext context) {
    final onOpenTown = this.onOpenTown;
    return GameScreenHeader(
      title: title,
      leading: onOpenTown == null
          ? null
          : Tooltip(
              message: 'Back to town',
              child: HudButton(
                key: const ValueKey('shell-town'),
                label: 'Town',
                icon: Icons.holiday_village,
                onPressed: onOpenTown,
              ),
            ),
      trailing: [
        SpoilsEntryButton(
          builder: (label, onPressed) => WoodButton(
            label: label,
            icon: Icons.auto_awesome,
            onPressed: onPressed,
          ),
        ),
        HudButton(label: 'Manage', icon: Icons.menu, onPressed: onOpenManage),
        PlayModeMenuButton(
          buttonBuilder: (openMenu) => HudButton(
            label: 'More',
            icon: Icons.more_horiz,
            onPressed: openMenu,
          ),
        ),
      ],
    );
  }
}

/// The pane's page: a parchment sheet in a wood outline. The pane draws its
/// own content (the Adventure theme already dresses its cards and buttons).
class _PanePage extends StatelessWidget {
  const _PanePage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ParchmentCard(
    padding: const EdgeInsets.all(6),
    child: _InkSurface(child: child),
  );
}

/// A clipped, transparent Material over a frame's fill, so the pane's list
/// tiles and buttons ink on the frame rather than under it.
class _InkSurface extends StatelessWidget {
  const _InkSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    clipBehavior: Clip.hardEdge,
    child: child,
  );
}

/// The desktop's pinned activity feed: a wood board with its "Adventure log"
/// ribbon over the feed on a parchment page.
class AdventureLogPanel extends StatelessWidget {
  const AdventureLogPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => WoodPanel(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: RibbonTitle('Adventure log')),
        const SizedBox(height: AdventureTokens.gap),
        Expanded(child: _PanePage(child: child)),
      ],
    ),
  );
}

/// The shell's quick actions as HUD buttons: "Scan" a receipt and the large
/// "Log purchase".
class AdventureQuickActions extends StatelessWidget {
  const AdventureQuickActions({
    super.key,
    required this.onLogPurchase,
    required this.onScanReceipt,
  });

  final VoidCallback onLogPurchase;
  final VoidCallback onScanReceipt;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Tooltip(
        message: 'Scan a receipt',
        child: HudButton(
          label: 'Scan',
          icon: Icons.document_scanner_outlined,
          onPressed: onScanReceipt,
        ),
      ),
      const SizedBox(width: AdventureTokens.gap),
      // Flexible, so on a very narrow screen the label ellipsizes rather
      // than overflowing.
      Flexible(
        child: HudButton(
          key: const ValueKey('shell-log-purchase'),
          label: 'Log purchase',
          icon: Icons.add_shopping_cart,
          large: true,
          onPressed: onLogPurchase,
        ),
      ),
    ],
  );
}
