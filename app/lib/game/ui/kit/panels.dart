/// The Adventure kit's panels: the wood board, the parchment card, the inset
/// well and the ribbon title, each a [PixelFrame] / [PixelSliceBox] over one
/// key of the Kenney UI sheet with a drawn fallback in the matching colours.
library;

import 'package:flutter/material.dart';

import 'adventure_tokens.dart';
import 'pixel_frame.dart';

/// The default content padding of a panel, clear of its 10 px drawn frame.
const EdgeInsets _kPanelPadding = EdgeInsets.all(12);

/// The source width of a banner's fixed end caps (one 32 px cell each; the
/// middle cell is uniform, so stretching it never smears a fold).
const double _kBannerCapSource = 32;

/// The banner's source height (one cell).
const int _kBannerSourceHeight = 32;

/// Banners draw at twice their source size: room for a 32 px pixel title.
const int _kBannerScale = 2;

/// A brown wood board: the backdrop for a screen section or a sheet.
class WoodPanel extends StatelessWidget {
  const WoodPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => PixelFrame(
        assetKey: KitKeys.wood,
        fallbackFill: AdventureTokens.wood,
        fallbackBorder: AdventureTokens.woodDark,
        padding: padding ?? _kPanelPadding,
        child: child,
      );
}

/// A cream parchment card: one readable item (a quest, a log line, a shop
/// entry). With [onTap] the whole card is a button — no ink splash over the
/// pixel art, but focusable, keyboard-activatable and announced as a button.
class ParchmentCard extends StatelessWidget {
  const ParchmentCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = PixelFrame(
      assetKey: KitKeys.parchment,
      fallbackFill: AdventureTokens.parchment,
      fallbackBorder: AdventureTokens.woodDark,
      padding: padding ?? _kPanelPadding,
      child: child,
    );
    final onTap = this.onTap;
    if (onTap == null) return card;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: card,
      ),
    );
  }
}

/// A sunken well inside a panel: a list, an amount readout, an input area.
class InsetWell extends StatelessWidget {
  const InsetWell({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  // The bundled pack has no clean recessed cell (its worn parchment
  // stretches into stray notches), so the well is drawn unless an artist
  // supplies `ui.panel.inset.idle`.
  @override
  Widget build(BuildContext context) => PixelFrame(
        assetKey: KitKeys.inset,
        fallbackFill: AdventureTokens.parchment,
        fallbackBorder: AdventureTokens.woodDark,
        padding: padding ?? _kPanelPadding,
        child: child,
      );
}

/// A red ribbon banner carrying a screen or section title. Sliced
/// horizontally only (fixed end caps, stretched middle, fixed height), and as
/// wide as its text needs.
class RibbonTitle extends StatelessWidget {
  const RibbonTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    const capWidth = _kBannerCapSource * _kBannerScale;
    return Semantics(
      header: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: capWidth * 2),
        child: SizedBox(
          height: (_kBannerSourceHeight * _kBannerScale).toDouble(),
          child: PixelSliceBox(
            assetKey: KitKeys.ribbon,
            sourceInsets: const EdgeInsets.symmetric(horizontal: _kBannerCapSource),
            scale: _kBannerScale,
            fallback: kitFallbackDecoration(
                fill: AdventureTokens.ribbon, border: AdventureTokens.woodDark),
            // The ribbon's body sits a little below the cell's middle; the
            // text keeps clear of the folds in the end caps.
            padding: const EdgeInsets.fromLTRB(capWidth * 0.625, 4, capWidth * 0.625, 0),
            child: Center(
              widthFactor: 1,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AdventureTokens.title(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
