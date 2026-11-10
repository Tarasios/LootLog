/// The framed look of the pushed hall screens (the vault, the forge,
/// expeditions): a wood board under the kit's screen header with parchment
/// cards on it, wood buttons, pixel meters and choice buttons.
///
/// Every piece here is tier-aware. In the pixel tier it draws with the kit;
/// in the text tier it falls back to what the hall always drew there (an app
/// bar, text panels, a block-character bar, Material buttons), so text mode
/// stays complete and first-class.
library;

import 'package:flutter/material.dart';

import 'hall_common.dart';
import 'kit/kit.dart';

/// Boards at least this wide lay a [FramedGrid] out in two columns.
const double _kTwoColumnWidth = 640;

/// Body text on a parchment card: the hall's body style in ink.
TextStyle framedBodyStyle(BuildContext context, {FontWeight? weight, Color? color}) =>
    hallBodyStyle(
      context,
      weight: weight,
      color: color ?? (hallTextTier(context) ? null : AdventureTokens.ink),
    );

/// Secondary text on a parchment card.
TextStyle framedMutedStyle(BuildContext context) => hallTextTier(context)
    ? hallMutedStyle(context)
    : framedBodyStyle(context, color: AdventureTokens.inkMuted);

/// A hint that something cannot happen yet: plain but noticeable, never red.
TextStyle framedGateStyle(BuildContext context) => hallTextTier(context)
    ? hallBodyStyle(context, color: Theme.of(context).colorScheme.tertiary)
    : framedBodyStyle(context, weight: FontWeight.w700, color: AdventureTokens.woodDark);

/// A pushed hall screen: in the pixel tier the wood [GameScreenHeader] (back
/// button, [title] on a ribbon, [trailing] chips) over a scrolling wood board
/// holding [children]; in the text tier an app bar over a [HallPage].
class FramedHallScreen extends StatelessWidget {
  const FramedHallScreen({
    super.key,
    required this.title,
    required this.children,
    this.trailing = const [],
  });

  final String title;
  final List<Widget> children;

  /// Chips or buttons for the header's right side (pixel tier only).
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    if (hallTextTier(context)) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: HallPage(children: children),
      );
    }
    final narrow = MediaQuery.sizeOf(context).width < AdventureTokens.narrowScreen;
    return Scaffold(
      backgroundColor: AdventureTokens.parchmentDark,
      body: DefaultTextStyle.merge(
        style: const TextStyle(color: AdventureTokens.ink),
        child: Column(
          children: [
            GameScreenHeader(title: title, trailing: trailing),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(narrow ? AdventureTokens.gap : AdventureTokens.gapLarge),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AdventureTokens.boardMaxWidth),
                    child: WoodPanel(
                      key: const ValueKey('hall-board'),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, child) in children.indexed) ...[
                            if (index > 0) const SizedBox(height: AdventureTokens.gapLarge - 4),
                            child,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One titled block of a framed screen: a [ParchmentCard] with the title in
/// the pixel font (and a small [icon]) above its [child]; in the text tier a
/// [HallSection].
class FramedSection extends StatelessWidget {
  const FramedSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (hallTextTier(context)) {
      return HallSection(title: title, icon: icon, child: child);
    }
    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AdventureTokens.woodDark),
                const SizedBox(width: AdventureTokens.gap),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AdventureTokens.label(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AdventureTokens.gap),
          child,
        ],
      ),
    );
  }
}

/// [children] in rows of equal-height cards: two across on a wide board, one
/// on a narrow one (a plain column in the text tier).
class FramedGrid extends StatelessWidget {
  const FramedGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const spacing = AdventureTokens.gapLarge - 4;
    if (hallTextTier(context)) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= _kTwoColumnWidth ? 2 : 1;
        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          final rowChildren = children.skip(start).take(columns).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: spacing),
                    Expanded(
                      child: column < rowChildren.length
                          ? rowChildren[column]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, row) in rows.indexed) ...[
              if (index > 0) const SizedBox(height: spacing),
              row,
            ],
          ],
        );
      },
    );
  }
}

/// An action: a [WoodButton] in the pixel tier (parchment when [secondary]),
/// a Material button in the text tier. [label] is the whole button text, so
/// there is no icon.
class FramedButton extends StatelessWidget {
  const FramedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    if (hallTextTier(context)) {
      final button = secondary
          ? OutlinedButton(onPressed: onPressed, child: Text(label))
          : FilledButton.tonal(onPressed: onPressed, child: Text(label));
      return expand ? SizedBox(width: double.infinity, child: button) : button;
    }
    return WoodButton(
      label: label,
      onPressed: onPressed,
      tone: secondary ? WoodButtonTone.secondary : WoodButtonTone.primary,
      expand: expand,
    );
  }
}

/// One option of a pick-one row: a [ChoiceChip] in the text tier, a wood
/// button (parchment when not [selected]) in the pixel tier.
class FramedChoice extends StatelessWidget {
  const FramedChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    if (hallTextTier(context)) {
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onSelected(),
      );
    }
    return Semantics(
      selected: selected,
      child: WoodButton(
        label: label,
        onPressed: onSelected,
        tone: selected ? WoodButtonTone.primary : WoodButtonTone.secondary,
      ),
    );
  }
}

/// A progress bar: a [MeterBar] in the pixel tier, the block-character bar
/// in the text tier.
class FramedMeter extends StatelessWidget {
  const FramedMeter(
    this.fraction, {
    super.key,
    this.color = AdventureTokens.hpGreen,
    this.semanticsLabel,
    this.textWidth = 12,
  });

  final double fraction;

  /// How many characters wide the text tier's block bar is.
  final int textWidth;
  final Color color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => hallTextTier(context)
      ? HallBar(fraction, width: textWidth)
      : MeterBar(fraction: fraction, color: color, height: 14, semanticsLabel: semanticsLabel);
}
