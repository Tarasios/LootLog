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

  /// The Tiny Town grass, for backdrops behind panels.
  static const Color grass = Color(0xFF84C669);

  /// The standard spacing between kit elements, and the larger section gap.
  static const double gap = 8, gapLarge = 16;

  /// Kenney Pixel, declared in pubspec as `LootPixel`.
  static const String pixelFont = 'LootPixel';

  /// Kenney Mini Square, declared in pubspec as `LootPixelMono`.
  static const String pixelMonoFont = 'LootPixelMono';

  /// Screen and panel headings, in the pixel font.
  static TextStyle title(BuildContext context) => _base(context).copyWith(
        fontFamily: pixelFont,
        fontSize: 20,
        height: 1.1,
        color: ink,
      );

  /// Labels, chips and buttons, in the pixel font.
  static TextStyle label(BuildContext context) => _base(context).copyWith(
        fontFamily: pixelFont,
        fontSize: 14,
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
