/// The wood header bar of the Adventure full-screen pages (the shop, a room,
/// the vault, the forge, expeditions, the budget screens): a back button when
/// there is somewhere to go back to (or the screen's own [GameScreenHeader.leading]
/// control in its place), the screen's name on a ribbon, and the screen's own
/// buttons or chips on the right.
///
/// On a narrow screen with more than one trailing control, the controls drop
/// to a second row so the ribbon keeps room for its title.
library;

import 'package:flutter/material.dart';

import 'adventure_tokens.dart';
import 'buttons.dart';
import 'panels.dart';

class GameScreenHeader extends StatelessWidget {
  const GameScreenHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing = const [],
  });

  /// The screen's name, shown on the ribbon.
  final String title;

  /// Replaces the back button: a screen whose way out is not a plain pop
  /// (the budget screens' "Town") puts its own control here.
  final Widget? leading;

  /// Buttons or chips on the right, in reading order.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();
    // The tooltip matches Material's back button, so the platform's "back"
    // lookups (and widget tests' pageBack) find it.
    final leadingControl = leading ?? (canGoBack
        ? Tooltip(
            message: MaterialLocalizations.of(context).backButtonTooltip,
            child: HudButton(
              key: const ValueKey('game-back'),
              label: 'Back',
              icon: Icons.arrow_back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          )
        : null);
    // On a phone the title is plain pixel lettering on the wood: the ribbon
    // is as tall as two rows of text, and a phone has no height to spare.
    final compact =
        MediaQuery.sizeOf(context).width < AdventureTokens.narrowScreen;
    final ribbon = Expanded(
      child: Center(
        child: compact
            ? Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdventureTokens.title(context)
                    .copyWith(color: AdventureTokens.parchment),
              )
            : RibbonTitle(title),
      ),
    );
    // A wrap, so a screen with many chips (the forge's materials) flows onto
    // more lines instead of overflowing.
    final trailingRow = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AdventureTokens.gap,
      runSpacing: AdventureTokens.gap,
      children: trailing,
    );
    return WoodPanel(
      padding: compact
          ? const EdgeInsets.fromLTRB(8, 6, 8, 6)
          : const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoRows = trailing.length > 1 && constraints.maxWidth < AdventureTokens.narrowScreen;
            final titleRow = Row(
              children: [
                ?leadingControl,
                if (leadingControl != null) const SizedBox(width: AdventureTokens.gap),
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
