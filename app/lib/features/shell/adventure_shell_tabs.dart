/// The Adventure budget shell's tabs: Dashboard, Ledger, Goals, Treasury and
/// Trophies (plus Activity on a phone) as wood buttons. The open pane's tab is
/// dark wood with a gold marker under it; the rest are parchment. On desktop
/// the strip sits under the header with icons; on a phone it is the bottom
/// bar: labels only, dense buttons, spread across the width.
library;

import 'package:flutter/material.dart';

import '../../game/ui/kit/kit.dart';

/// The least gap between the phone's bottom tabs.
const double _kCompactTabGap = 4;

/// The gold marker under the selected tab.
const double _kSelectedMarkerWidth = 32, _kSelectedMarkerHeight = 4;

/// One tab of the shell's tab strip.
class AdventureShellTab {
  const AdventureShellTab({required this.label, required this.icon, this.key});

  final String label;
  final IconData icon;

  /// Put on the tab's button, so tests and tours can find it.
  final Key? key;
}

/// The shell's tabs as a scrollable row of wood buttons; the open pane's tab
/// is dark wood, the rest parchment.
class AdventureTabStrip extends StatelessWidget {
  const AdventureTabStrip({
    super.key,
    required this.tabs,
    required this.selectedTab,
    required this.onSelectTab,
    this.compact = false,
  });

  final List<AdventureShellTab> tabs;
  final int? selectedTab;
  final ValueChanged<int> onSelectTab;

  /// The phone's bottom strip: icons spread across the width, with only the
  /// open pane's tab spelling out its name, so all five tabs fit on a phone.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      for (final (index, tab) in tabs.indexed)
        _ShellTabButton(
          tab: tab,
          compact: compact,
          selected: index == selectedTab,
          onPressed: () => onSelectTab(index),
        ),
    ];
    // Scrolls sideways only when the tabs do not fit (a very narrow window).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: compact ? constraints.maxWidth : 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: compact ? _kCompactTabGap : AdventureTokens.gap,
            children: buttons,
          ),
        ),
      ),
    );
  }
}

/// One tab: a wood button (dark wood when [selected], parchment otherwise)
/// over a gold marker that only the selected tab shows.
class _ShellTabButton extends StatelessWidget {
  const _ShellTabButton({
    required this.tab,
    required this.compact,
    required this.selected,
    required this.onPressed,
  });

  final AdventureShellTab tab;
  final bool compact;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      selected: selected,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: tab.label,
            child: WoodButton(
              key: tab.key,
              label: compact && !selected ? '' : tab.label,
              semanticsLabel: tab.label,
              icon: tab.icon,
              dense: compact,
              tone:
                  selected ? WoodButtonTone.primary : WoodButtonTone.secondary,
              onPressed: onPressed,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: _kSelectedMarkerWidth,
            height: _kSelectedMarkerHeight,
            color: selected ? AdventureTokens.gold : Colors.transparent,
          ),
        ],
      ),
    ),
  );
}
