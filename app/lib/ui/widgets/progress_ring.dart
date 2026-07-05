/// A compact circular progress ring used for per-slice budget consumption on
/// the dashboard. Draws a track, a filled arc for the consumed fraction, and an
/// optional centered label. Overspend is signalled by an [overColor] arc that
/// wraps past full.
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: fraction.clamp(0.0, 1.0),
          color: overspent ? (overColor ?? color) : color,
          trackColor: trackColor,
          strokeWidth: strokeWidth,
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
