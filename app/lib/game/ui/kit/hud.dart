/// The Adventure kit's HUD pieces: the parchment [HudChip] (gems, streak,
/// gold in the town's corners), the pixel [MeterBar] (quest and OVERBUDGET HP),
/// and the [FloatingTag] sign that hangs over a building.
///
/// The meter and the tag are drawn with plain boxes — the UI pack has no bar
/// or sign cells — in the kit's palette, square-cornered so they sit with the
/// pixel art.
library;

import 'package:flutter/material.dart';

import 'adventure_tokens.dart';
import 'buttons.dart';
import 'pixel_frame.dart';

/// Kenney Pixel's native size: it renders crisp at whole multiples of 16 and
/// soft in between, so kit controls use 16 (and 32 for the big HUD button).
const double _kPixelFontSize = 16;

/// The outline every drawn HUD piece wears.
const Color _kOutline = AdventureTokens.woodDark;

/// The empty part of a meter.
const Color _kMeterBack = AdventureTokens.ink;

/// A meter laid out with no width limit (inside a shrink-wrapping row) is
/// this wide.
const double _kMeterUnboundedWidth = 96;

/// A compact parchment chip: [icon] (tinted [color]) and [value], with an
/// optional caption [label]. [valueKey] goes on the value's [Text], so a test
/// or a reward animation can find the number. With [onTap] it is a button.
class HudChip extends StatelessWidget {
  const HudChip({
    super.key,
    required this.icon,
    required this.value,
    this.label,
    this.color,
    this.onTap,
    this.valueKey,
  });

  final IconData icon;
  final String value;
  final String? label;
  final Color? color;
  final VoidCallback? onTap;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    final chip = PixelFrame(
      assetKey: KitKeys.parchment,
      scale: 1,
      fallbackFill: AdventureTokens.parchment,
      fallbackBorder: _kOutline,
      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color ?? AdventureTokens.ink),
          const SizedBox(width: 5),
          Text(value, key: valueKey, maxLines: 1, style: AdventureTokens.amount(context)),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              style: AdventureTokens.label(
                context,
              ).copyWith(color: AdventureTokens.inkMuted, fontSize: _kPixelFontSize),
            ),
          ],
        ],
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) return chip;
    return KitPressable(
      onPressed: onTap,
      builder: (context, pressed) => Transform.translate(offset: Offset(0, pressed ? 1 : 0), child: chip),
    );
  }
}

/// A pixel progress bar: a dark trough with a 1 px outline and a square fill
/// of [color] covering [fraction] (clamped to 0..1) of it, announced to screen
/// readers as a whole percent.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.fraction,
    this.color = AdventureTokens.hpRed,
    this.height = 10,
    this.semanticsLabel,
  });

  final double fraction;
  final Color color;
  final double height;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label: semanticsLabel,
      value: '${(clamped * 100).round()}%',
      // Fills the width it is given; a fixed width only where none is set.
      child: LimitedBox(
        maxWidth: _kMeterUnboundedWidth,
        child: CustomPaint(
          size: Size(double.infinity, height),
          painter: _MeterPainter(fraction: clamped, color: color),
        ),
      ),
    );
  }
}

/// Paints a [MeterBar]: outline, trough, then the fill on whole pixels with a
/// one-pixel lighter highlight along its top.
class _MeterPainter extends CustomPainter {
  _MeterPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    canvas.drawRect(Offset.zero & size, paint..color = _kOutline);
    final trough = Rect.fromLTRB(1, 1, size.width - 1, size.height - 1);
    if (trough.isEmpty) return;
    canvas.drawRect(trough, paint..color = _kMeterBack);
    final fillWidth = (trough.width * fraction).floorToDouble();
    if (fillWidth <= 0) return;
    final fill = Rect.fromLTWH(trough.left, trough.top, fillWidth, trough.height);
    canvas.drawRect(fill, paint..color = color);
    if (fill.height > 2) {
      canvas.drawRect(
        Rect.fromLTWH(fill.left, fill.top, fill.width, 1),
        paint..color = Color.lerp(color, Colors.white, 0.35)!,
      );
    }
  }

  @override
  bool shouldRepaint(_MeterPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}

/// A small sign hung over a building ("Ready", "3 quests", "Enraged!"): a
/// parchment plate with a 1 px outline and a little pointer underneath, with
/// an optional leading [icon]. [urgent] paints it ribbon red with light text.
class FloatingTag extends StatelessWidget {
  const FloatingTag(this.text, {super.key, this.icon, this.urgent = false});

  final String text;
  final IconData? icon;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final fill = urgent ? AdventureTokens.ribbon : AdventureTokens.parchment;
    final foreground = urgent ? AdventureTokens.parchment : AdventureTokens.ink;
    final icon = this.icon;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: _kOutline),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(5, 2, 5, 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 14, color: foreground), const SizedBox(width: 3)],
                Text(
                  text,
                  maxLines: 1,
                  style: AdventureTokens.label(
                    context,
                  ).copyWith(color: foreground, fontSize: _kPixelFontSize),
                ),
              ],
            ),
          ),
        ),
        // Overlap the plate's bottom outline so the pointer reads as one shape.
        Transform.translate(
          offset: const Offset(0, -1),
          child: CustomPaint(size: _TagPointerPainter.size, painter: _TagPointerPainter(fill)),
        ),
      ],
    );
  }
}

/// The stepped downward pointer under a [FloatingTag]: three 2 px rows,
/// each narrower, outlined 1 px.
class _TagPointerPainter extends CustomPainter {
  _TagPointerPainter(this.fill);

  final Color fill;

  /// Half-widths of the filled rows, top to bottom.
  static const List<double> _rowHalfWidths = [5, 3, 1];
  static const double _rowHeight = 2;
  static const Size size = Size(12, 7);

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()..isAntiAlias = false;
    final centre = canvasSize.width / 2;
    final rows = [
      for (final (index, halfWidth) in _rowHalfWidths.indexed)
        Rect.fromLTRB(centre - halfWidth, index * _rowHeight, centre + halfWidth, (index + 1) * _rowHeight),
    ];
    paint.color = _kOutline;
    for (final row in rows) {
      canvas.drawRect(Rect.fromLTRB(row.left - 1, row.top, row.right + 1, row.bottom + 1), paint);
    }
    paint.color = fill;
    for (final row in rows) {
      canvas.drawRect(row, paint);
    }
  }

  @override
  bool shouldRepaint(_TagPointerPainter oldDelegate) => oldDelegate.fill != fill;
}
