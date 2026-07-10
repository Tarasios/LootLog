/// The LootLog design system.
///
/// One seed color drives a Material 3 palette in both light and dark. Every
/// screen builds from [AppTheme.light] / [AppTheme.dark] and reaches for the
/// shared [AppSpacing], [AppRadii], and [AppDurations] constants rather than
/// hand-rolling paddings or corner radii, so the whole app reads as one system.
library;

import 'package:flutter/material.dart';

/// The single brand seed. The Material 3 algorithm derives every role color
/// (primary, secondary, surfaces, error, …) from this one hue for both themes.
const Color kSeedColor = Color(0xFF2E7D5B); // deep emerald — coin & ledger green

/// Spacing scale, in logical pixels. A small, memorable step scale keeps rhythm
/// consistent: pad and gap with these, never magic numbers.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

/// Corner radii. Chips and small controls use [sm]; cards and sheets use [lg];
/// the big amount surface uses [xl].
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 28;

  static const BorderRadius chip = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(xl));
}

/// Motion durations. Quick, uniform, never fussy — this is a sub-5-second flow.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
}

/// Named type roles layered on top of the Material text theme. The amount
/// display wants a large tabular-feeling numeric style; everything else uses the
/// stock M3 roles so the app inherits accessible defaults.
abstract final class AppText {
  /// The giant amount readout on the entry keypad and OCR confirm screen.
  static TextStyle amount(BuildContext context) =>
      Theme.of(context).textTheme.displayMedium!.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: -1,
          );

  /// The hero figure on the month card — large, tight, tabular.
  static TextStyle heroAmount(BuildContext context) =>
      Theme.of(context).textTheme.displaySmall!.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: -1.5,
          );

  /// A secondary metric value (income / spent figures, net-worth total).
  static TextStyle metricValue(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          );

  /// The small uppercase-ish label sitting above a metric value.
  static TextStyle metricLabel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme.of(context).textTheme.labelSmall!.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        );
  }

  /// The label above a grouped section of charge chips, and card titles.
  static TextStyle sectionLabel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme.of(context).textTheme.labelLarge!.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        );
  }
}

/// Builds the light and dark [ThemeData] for the app from [kSeedColor].
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
          textStyle: base.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
        showDragHandle: true,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.chip),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: const OutlineInputBorder(
          borderRadius: AppRadii.card,
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: AppSpacing.lg,
      ),
    );
  }
}
