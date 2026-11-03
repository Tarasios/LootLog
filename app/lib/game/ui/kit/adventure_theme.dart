/// The Material theme an Adventure player's app runs under: wood bars,
/// parchment surfaces and cards, ribbon-red accents, square-ish frames, and
/// the pixel font for headlines, titles and labels — always at a whole
/// multiple of [AdventureTokens.pixelFontStep] so it stays crisp. Body text
/// and every role money is drawn in keeps the default face, so amounts stay
/// legible and never get a synthetic pixel bold.
///
/// Imports only Flutter and the kit tokens, so the app root can choose it
/// without pulling in any game state.
library;

import 'package:flutter/material.dart';

import 'adventure_tokens.dart';

/// Corner radius of themed buttons, cards, dialogs and sheets: square-ish, to
/// sit beside the pixel frames.
const double _kCornerRadius = 4;

/// The outline width of themed buttons, cards and dialogs.
const double _kOutlineWidth = 2;

/// Pixel text line height: 1.25 lands a 16 px (or 32 px) line on whole pixels.
const double _kPixelLineHeight = 1.25;

/// The smallest a themed button gets — finite, so a button in app-bar actions
/// or a row never inherits the Standard theme's full-width minimum.
const Size _kButtonMinimum = Size(64, 44);

abstract final class AdventureTheme {
  /// The Adventure theme. One look for light and dark: parchment is the game.
  static ThemeData build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AdventureTokens.wood,
      brightness: Brightness.light,
    ).copyWith(
      primary: AdventureTokens.ribbon,
      onPrimary: AdventureTokens.parchment,
      surface: AdventureTokens.parchment,
      onSurface: AdventureTokens.ink,
      onSurfaceVariant: AdventureTokens.inkMuted,
      outline: AdventureTokens.woodDark,
      surfaceTint: Colors.transparent,
    );
    final textTheme = _textTheme(ThemeData(colorScheme: colorScheme).textTheme);
    const outline = BorderSide(color: AdventureTokens.woodDark, width: _kOutlineWidth);
    const squareOutlined = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(_kCornerRadius)),
      side: outline,
    );
    final buttonLabel = textTheme.labelLarge;
    final pixelTitle = textTheme.titleLarge!;

    return ThemeData(
      colorScheme: colorScheme,
      textTheme: textTheme,
      // Plain screens sit on shaded parchment; full-screen game routes (the
      // town, the dungeon) paint their own backdrops.
      scaffoldBackgroundColor: AdventureTokens.parchmentDark,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AdventureTokens.wood,
          foregroundColor: AdventureTokens.parchment,
          minimumSize: _kButtonMinimum,
          shape: squareOutlined,
          textStyle: buttonLabel,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdventureTokens.parchment,
          foregroundColor: AdventureTokens.ink,
          elevation: 0,
          minimumSize: _kButtonMinimum,
          shape: squareOutlined,
          textStyle: buttonLabel,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdventureTokens.ink,
          minimumSize: _kButtonMinimum,
          side: outline,
          shape: squareOutlined,
          textStyle: buttonLabel,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdventureTokens.woodDark,
          minimumSize: _kButtonMinimum,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(_kCornerRadius)),
          ),
          textStyle: buttonLabel,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AdventureTokens.parchment,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: squareOutlined,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AdventureTokens.parchment,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_kCornerRadius)),
          side: BorderSide(color: AdventureTokens.woodDark, width: _kOutlineWidth * 2),
        ),
        titleTextStyle: pixelTitle,
        contentTextStyle: textTheme.bodyMedium,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AdventureTokens.wood,
        foregroundColor: AdventureTokens.parchment,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: pixelTitle.copyWith(color: AdventureTokens.parchment),
        iconTheme: const IconThemeData(color: AdventureTokens.parchment),
        actionsIconTheme: const IconThemeData(color: AdventureTokens.parchment),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AdventureTokens.wood,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AdventureTokens.parchmentDark,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AdventureTokens.ink
                  : AdventureTokens.parchment,
            )),
        labelTextStyle: WidgetStatePropertyAll(
            textTheme.labelMedium!.copyWith(color: AdventureTokens.parchment)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AdventureTokens.wood,
        indicatorColor: AdventureTokens.parchmentDark,
        selectedIconTheme: const IconThemeData(color: AdventureTokens.ink),
        unselectedIconTheme: const IconThemeData(color: AdventureTokens.parchment),
        selectedLabelTextStyle:
            textTheme.labelMedium!.copyWith(color: AdventureTokens.parchment),
        unselectedLabelTextStyle:
            textTheme.labelMedium!.copyWith(color: AdventureTokens.parchment),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AdventureTokens.woodDark,
        contentTextStyle: textTheme.bodyMedium!.copyWith(color: AdventureTokens.parchment),
        actionTextColor: AdventureTokens.gold,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_kCornerRadius)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AdventureTokens.parchment,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AdventureTokens.woodDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_kCornerRadius)),
          side: outline,
        ),
      ),
    );
  }

  /// [base] in ink, with the pixel font on the headline, large and small
  /// title, and label roles at a crisp size. The display roles and
  /// `titleMedium` carry money (`AppText.amount`, `heroAmount`, `metricValue`
  /// build on them, bold), so they keep the default face, as body roles do.
  static TextTheme _textTheme(TextTheme base) {
    const step = AdventureTokens.pixelFontStep;
    TextStyle? pixel(TextStyle? style, double size) => style?.copyWith(
          fontFamily: AdventureTokens.pixelFont,
          fontSize: size,
          height: _kPixelLineHeight,
          letterSpacing: 0,
        );
    return base
        .copyWith(
          headlineLarge: pixel(base.headlineLarge, step * 2),
          headlineMedium: pixel(base.headlineMedium, step * 2),
          headlineSmall: pixel(base.headlineSmall, step * 2),
          titleLarge: pixel(base.titleLarge, step * 2),
          titleSmall: pixel(base.titleSmall, step),
          labelLarge: pixel(base.labelLarge, step),
          labelMedium: pixel(base.labelMedium, step),
          labelSmall: pixel(base.labelSmall, step),
        )
        .apply(bodyColor: AdventureTokens.ink, displayColor: AdventureTokens.ink);
  }
}
