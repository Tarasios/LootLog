/// The goal picture behind a boss, revealed from the bottom up in
/// proportion to how much of the goal is saved.
library;

import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// The part of an [imageWidth] x [imageHeight] picture to show when
/// [fraction] of the goal is saved: its bottom [fraction] (clamped to 0..1),
/// so the goal "rises" into view.
Rect revealedSourceRect(double imageWidth, double imageHeight, double fraction) {
  final clamped = fraction.clamp(0.0, 1.0);
  final visibleHeight = imageHeight * clamped;
  return Rect.fromLTWH(0, imageHeight - visibleHeight, imageWidth, visibleHeight);
}

/// Draws [picture] revealed up to [fraction], bottom-aligned in its box.
class RevealedPicture extends PositionComponent {
  RevealedPicture({
    required this.picture,
    required this.fraction,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size, priority: 1);

  final ui.Image picture;
  double fraction;

  @override
  void render(Canvas canvas) {
    final source = revealedSourceRect(picture.width.toDouble(), picture.height.toDouble(), fraction);
    if (source.height <= 0) return;
    final shown = fraction.clamp(0.0, 1.0);
    final destination = Rect.fromLTWH(0, size.y * (1 - shown), size.x, size.y * shown);
    canvas.drawImageRect(picture, source, destination, Paint()..filterQuality = FilterQuality.none);
  }
}
