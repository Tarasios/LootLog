/// A compact circular progress ring used for per-slice budget consumption on
/// the dashboard. Draws a track, a filled arc for the consumed fraction, and an
/// optional centered label. Overspend is signalled by an [overColor] arc that
/// wraps past full.
///
/// The arc animates from empty to its target on first paint and eases between
/// values on rebuild, so a dashboard full of rings "fills in" when it appears.
/// Animation settles under `pumpAndSettle`, keeping goldens deterministic; pass
/// [duration] `Duration.zero` to opt out.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.fraction,
    required this.color,
    required this.trackColor,
    this.overColor,
    this.overspent = false,
    this.size = 64,
    this.strokeWidth = 7,
    this.center,
    this.duration = const Duration(milliseconds: 700),
  });

  /// Consumed fraction (0..1 for normal, clamped visually; overspend is shown
  /// via [overspent] rather than a fraction > 1).
  final double fraction;
  final Color color;
  final Color trackColor;
  final Color? overColor;
  final bool overspent;
  final double size;
  final double strokeWidth;
  final Widget? center;

  /// Fill-in animation length; [Duration.zero] paints the target immediately.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final arcColor = overspent ? (overColor ?? color) : color;
    final target = fraction.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(
            fraction: value,
            color: arcColor,
            trackColor: trackColor,
            strokeWidth: strokeWidth,
          ),
          child: child,
        ),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, track);
    if (fraction <= 0) {
      return;
    }
    const start = -math.pi / 2;
    final sweep = 2 * math.pi * fraction;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
