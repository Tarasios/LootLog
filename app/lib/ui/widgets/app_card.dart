/// Shared card, section-header, and empty-state building blocks for the classic
/// UI. Centralising these keeps every dashboard and feature surface on the same
/// rounded, softly-outlined card language instead of hand-rolling containers.
library;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The app's standard rounded surface. A hairline outline in light mode gives
/// cards definition on a same-tone background; dark mode leans on the tonal
/// surface instead. An optional [accent] paints a slim colour bar down the
/// leading edge, tying a card to its category/theme colour.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.accent,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final Color? color;
  final Color? accent;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
    final bg = color ?? scheme.surfaceContainerLow;

    Widget content = Padding(padding: padding, child: child);
    if (accent != null) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: accent),
          Expanded(child: content),
        ],
      );
    }

    return Material(
      color: bg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.card,
        side: light
            ? BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))
            : BorderSide.none,
      ),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// A card's heading row: optional leading [icon], a [title] in the section-label
/// style, and an optional [trailing] widget (a value, button, or badge).
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.md),
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: iconColor ?? scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: Text(title, style: AppText.sectionLabel(context))),
          ?trailing,
        ],
      ),
    );
  }
}

/// The uniform "nothing here yet" state: a muted icon over one or two lines of
/// guidance. Used everywhere a card can be empty so blank sections feel
/// intentional rather than broken.
class AppEmptyHint extends StatelessWidget {
  const AppEmptyHint({
    super.key,
    required this.icon,
    required this.message,
    this.compact = false,
  });

  final IconData icon;
  final String message;

  /// A tighter, left-aligned inline variant for small cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    if (compact) {
      return Row(
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: muted),
            ),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Icon(icon, size: 32, color: muted.withValues(alpha: 0.7)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
