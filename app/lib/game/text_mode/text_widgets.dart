/// Shared building blocks for the text-adventure tier (tier 3): styled text
/// panels and the block-character HP bar. This is a first-class presentation,
/// not an error state — the whole app is complete and playable here, before a
/// single sprite exists. Everything reads from the game read-model; nothing
/// computes money.
library;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../game_state.dart';

/// A block-character progress bar, e.g. `████████░░░░`. [fraction] is clamped to
/// 0..1; [width] is the number of cells.
String textBar(double fraction, {int width = 12}) {
  final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
  final filled = (f * width).round();
  return '█' * filled + '░' * (width - filled);
}

/// The monospace-leaning style that gives text mode its terminal feel, with
/// tabular figures so numbers and bars line up column-for-column.
TextStyle monoStyle(BuildContext context, {Color? color, FontWeight? weight}) {
  final base = Theme.of(context).textTheme.bodyMedium!;
  return base.copyWith(
    fontFamily: 'monospace',
    fontFamilyFallback: const ['Menlo', 'Consolas', 'Courier New', 'monospace'],
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color,
    fontWeight: weight,
    height: 1.35,
  );
}

/// A bordered, titled text panel — the recurring frame of every text-mode
/// screen. The [accent] tints the title and the left rule.
class TextPanel extends StatelessWidget {
  const TextPanel({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.accent,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Color? accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = accent ?? scheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: tint, width: 3)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: tint),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: monoStyle(context, weight: FontWeight.w800)
                        .copyWith(color: tint, letterSpacing: 1),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// The icon + tint for a log line's [LogTone].
({IconData icon, Color color}) toneStyle(BuildContext context, LogTone tone) {
  final scheme = Theme.of(context).colorScheme;
  return switch (tone) {
    LogTone.strike => (icon: Icons.sports_martial_arts, color: scheme.primary),
    LogTone.supplies => (icon: Icons.inventory_2_outlined, color: scheme.tertiary),
    LogTone.treasure => (icon: Icons.diamond_outlined, color: scheme.tertiary),
    LogTone.quest => (icon: Icons.flag_outlined, color: scheme.secondary),
    LogTone.ritual => (icon: Icons.auto_awesome, color: scheme.primary),
    LogTone.chest => (icon: Icons.savings_outlined, color: scheme.tertiary),
    LogTone.writ => (icon: Icons.draw_outlined, color: scheme.secondary),
    LogTone.ransack => (icon: Icons.local_fire_department, color: scheme.error),
    LogTone.muster => (icon: Icons.group_add_outlined, color: scheme.secondary),
  };
}
