/// The wood header bar of the full-screen decoration screens (the shop, a
/// room): a back button when there is somewhere to go back to, the screen's
/// name on a ribbon, and the screen's own buttons or chips on the right.
///
/// On a narrow screen with more than one trailing control, the controls drop
/// to a second row so the ribbon keeps room for its title.
library;

import 'package:flutter/material.dart';

import '../kit/kit.dart';

/// Below this width a header with several trailing controls uses two rows.
const double _kTwoRowBreakpoint = 600;

class DecorScreenHeader extends StatelessWidget {
  const DecorScreenHeader({
    super.key,
    required this.title,
    this.trailing = const [],
  });

  /// The screen's name, shown on the ribbon.
  final String title;

  /// Buttons or chips on the right, in reading order.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();
    // The tooltip matches Material's back button, so the platform's "back"
    // lookups (and widget tests' pageBack) find it.
    final backButton = canGoBack
        ? Tooltip(
            message: MaterialLocalizations.of(context).backButtonTooltip,
            child: HudButton(
              key: const ValueKey('decor-back'),
              label: 'Back',
              icon: Icons.arrow_back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          )
        : null;
    final ribbon = Expanded(child: Center(child: RibbonTitle(title)));
    final trailingRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, control) in trailing.indexed) ...[
          if (index > 0) const SizedBox(width: AdventureTokens.gap),
          control,
        ],
      ],
    );
    return WoodPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoRows = trailing.length > 1 && constraints.maxWidth < _kTwoRowBreakpoint;
            final titleRow = Row(
              children: [
                ?backButton,
                if (backButton != null) const SizedBox(width: AdventureTokens.gap),
                ribbon,
                if (!twoRows && trailing.isNotEmpty) ...[
                  const SizedBox(width: AdventureTokens.gap),
                  trailingRow,
                ],
              ],
            );
            if (!twoRows) return titleRow;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                titleRow,
                const SizedBox(height: AdventureTokens.gap),
                trailingRow,
              ],
            );
          },
        ),
      ),
    );
  }
}
