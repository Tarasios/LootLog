/// The Adventure kit's design tokens: the palette, spacing, pixel font
/// families and text styles every kit widget draws with, plus the asset keys
/// of the kit's frames (the Kenney "UI Pack – Pixel Adventure" sheet, see
/// `docs/art-assets.md` §11).
///
/// The colours are sampled from that sheet (parchment cream, wood brown, the
/// dark frame outline, the ribbon red, the slate blue) and from the Tiny Town
/// grass, so the drawn fallbacks sit comfortably beside the pixel art.
library;

import 'package:flutter/material.dart';

import '../../assets/asset_key.dart';

abstract final class AdventureTokens {
  /// The cream fill of the parchment panel.
  static const Color parchment = Color(0xFFFFF1D2);

  /// A shaded parchment, for inset wells and pressed states.
  static const Color parchmentDark = Color(0xFFE8D0AC);

  /// The body of the wood panel.
  static const Color wood = Color(0xFFA3703A);

  /// The dark outline every frame on the sheet is drawn with.
  static const Color woodDark = Color(0xFF6D4B27);

  /// Body text on parchment: darker than the outline, for legibility.
  static const Color ink = Color(0xFF3E2A16);

  /// Secondary text (helper lines, captions).
  static const Color inkMuted = Color(0xFF6D4B27);

  /// The ribbon banner red.
  static const Color ribbon = Color(0xFFE2665B);

  /// Gems (the sheet's bright blue).
  static const Color gem = Color(0xFF5CA2E0);

  /// Gold coins and the gold chest.
  static const Color gold = Color(0xFFE8B04B);

  /// Chest wood (the sheet's light frame brown).
  static const Color chest = Color(0xFFC58747);

  /// HP-bar fills: enraged / healthy / mana-blue progress.
  static const Color hpRed = Color(0xFFCF5E53);
  static const Color hpGreen = Color(0xFF72B84E);
  static const Color hpBlue = Color(0xFF63AFF3);

  /// Gains (money in, a rising balance) as text and lines on parchment: the
  /// healthy-HP green darkened to about 4.6:1 against [parchment].
  static const Color gainInk = Color(0xFF3F7A2A);

  /// The Tiny Town grass, for backdrops behind panels.
  static const Color grass = Color(0xFF84C669);

  /// The standard spacing between kit elements, and the larger section gap.
  static const double gap = 8, gapLarge = 16;

  /// Windows at least this wide get the side-by-side layouts (the hall's two
  /// columns, the dungeon's three). The same width as Standard's
  /// `kWideBreakpoint`, so both modes switch layout together.
  static const double wideBreakpoint = 840;

  /// Below this screen width (a phone) pages tighten their margins, boards
  /// run edge to edge, and headers with several controls use two rows.
  static const double narrowScreen = 600;

  /// The widest a framed board (the hall's screens) gets on a big screen.
  static const double boardMaxWidth = 880;

  /// The widest the shop counter gets, so its slots stay card-sized.
  static const double counterMaxWidth = 960;

  /// The pixel font's native size: the LootPixel family is drawn on an 8 px
  /// grid, so it renders crisp only at whole multiples of this (16, 24, …)
  /// and soft in between. Every pixel text size in the kit is a multiple of
  /// it, and never below 16 (at 8 it is too small to read).
  static const double pixelFontStep = 8;

  /// Kenney Mini (a bold, wide pixel face that stays legible at 16 px),
  /// declared in pubspec as `LootPixel`.
  static const String pixelFont = 'LootPixel';

  /// Kenney Mini Square, declared in pubspec as `LootPixelMono`.
  static const String pixelMonoFont = 'LootPixelMono';

  /// Screen and panel headings, in the pixel font.
  static TextStyle title(BuildContext context) => _base(context).copyWith(
        fontFamily: pixelFont,
        fontSize: pixelFontStep * 3,
        height: 1.1,
        color: ink,
      );

  /// Labels, chips and buttons, in the pixel font.
  static TextStyle label(BuildContext context) => _base(context).copyWith(
        fontFamily: pixelFont,
        fontSize: pixelFontStep * 2,
        height: 1.1,
        color: ink,
      );

  /// Money and counts: the app's default face (legible digits), bold, with
  /// tabular figures so columns of amounts line up.
  static TextStyle amount(BuildContext context) => _base(context).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: ink,
      );

  static TextStyle _base(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
}

/// The asset keys of the kit's frames. An artist overrides any one by dropping
/// a PNG named after the key into `app/assets/game/`.
abstract final class KitKeys {
  static const AssetKey parchment = AssetKey('ui', 'panel', 'parchment');
  static const AssetKey wood = AssetKey('ui', 'panel', 'wood');
  static const AssetKey slate = AssetKey('ui', 'panel', 'slate');
  static const AssetKey ornate = AssetKey('ui', 'panel', 'ornate');
  static const AssetKey inset = AssetKey('ui', 'panel', 'inset');
  static const AssetKey ribbon = AssetKey('ui', 'banner', 'ribbon');
  static const AssetKey bannerPlain = AssetKey('ui', 'banner', 'plain');
  static const AssetKey roundButton = AssetKey('ui', 'button', 'round');
}
