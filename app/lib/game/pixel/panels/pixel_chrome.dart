part of '../pixel_adventure_view.dart';

/// A blocky, segmented HP/progress bar — the pixel tier's take on the text-mode
/// block bar. [fraction] is clamped to 0..1.
class _PixelHpBar extends StatelessWidget {
  const _PixelHpBar({
    required this.fraction,
    required this.color,
  });

  final double fraction;
  final Color color;

  /// Number of blocky cells in the bar.
  static const int cells = 10;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    final filled = (clamped * cells).round();
    return Row(
      children: [
        for (var i = 0; i < cells; i++)
          Expanded(
            child: Container(
              height: 6,
              margin: EdgeInsets.only(right: i == cells - 1 ? 0 : 1),
              color: i < filled ? color : scheme.surfaceContainerLow,
            ),
          ),
      ],
    );
  }
}

/// A titled panel — the pixel tier's recurring frame. Where a 9-slice panel PNG
/// would sit (see `docs/art-assets.md`), a themed rounded box stands in, so a
/// missing panel asset is graceful, never a gap.
class _PixelPanel extends StatelessWidget {
  const _PixelPanel({
    required this.child,
    this.title,
    this.accent,
    this.fill = false,
  });

  final Widget child;
  final String? title;
  final Color? accent;

  /// When true the child is given the panel's full height (for the log's
  /// internal scroll view).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = accent ?? scheme.primary;
    final body = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: tint, width: 3)),
              ),
              child: Text(
                title!.toUpperCase(),
                style: AppText.sectionLabel(context)
                    .copyWith(color: tint, letterSpacing: 1),
              ),
            ),
          fill ? Expanded(child: body) : body,
        ],
      ),
    );
  }
}

// ===========================================================================
// Small shared pill.
// ===========================================================================

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: AppRadii.chip),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: onColor),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: onColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
