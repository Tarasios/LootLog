/// Main-category colour → a harmonised, theme-aware set of tones.
///
/// Every budget category rolls up to a [MainCategory] whose single `colorArgb`
/// drives reports. This module turns that one seed into an accessible little
/// palette — an accent, a soft container fill, a readable on-container text
/// colour, and a ring track — tuned separately for light and dark so the same
/// category reads as "the orange one" in both themes without ever clashing with
/// the surface it sits on. Pure and Flutter-only (no Material dependency beyond
/// [Color]/[HSLColor]), so it is trivially golden-testable.
library;

import 'package:flutter/material.dart';

/// A category's derived tones for one brightness.
@immutable
class CategoryColors {
  const CategoryColors({
    required this.accent,
    required this.container,
    required this.onContainer,
    required this.track,
  });

  /// The vivid colour for ring arcs, accent bars, and dots.
  final Color accent;

  /// A soft tinted fill for a category tile's background.
  final Color container;

  /// Text/icon colour that stays legible on [container].
  final Color onContainer;

  /// The unfilled portion of a progress ring on [container].
  final Color track;
}

/// Derives [CategoryColors] from a main-category [colorArgb] for [brightness].
///
/// When [colorArgb] is null (an unassigned category), [fallback] — normally a
/// neutral scheme role — is used as the accent so the tile still reads as one of
/// the set rather than defaulting to bare Material blue.
CategoryColors categoryColorsFor(
  int? colorArgb,
  Brightness brightness, {
  required Color fallback,
}) {
  final seed = colorArgb == null ? fallback : Color(colorArgb);
  final hsl = HSLColor.fromColor(seed);
  final h = hsl.hue;
  final s = hsl.saturation.clamp(0.0, 1.0);

  Color at(double sat, double light) =>
      HSLColor.fromAHSL(1, h, sat.clamp(0.0, 1.0), light.clamp(0.0, 1.0))
          .toColor();

  if (brightness == Brightness.dark) {
    return CategoryColors(
      // Pull the accent up in lightness so it pops off dark surfaces.
      accent: at(s * 0.85 + 0.1, 0.66),
      container: at(s * 0.55, 0.20),
      onContainer: at(s * 0.45 + 0.15, 0.90),
      track: at(s * 0.35, 0.30),
    );
  }
  return CategoryColors(
    // Slightly deepen very-light seeds so the accent never washes out on white.
    accent: at(s, hsl.lightness > 0.58 ? 0.5 : hsl.lightness.clamp(0.35, 0.55)),
    container: at(s * 0.55 + 0.1, 0.94),
    onContainer: at(s * 0.7, 0.28),
    track: at(s * 0.3, 0.88),
  );
}
