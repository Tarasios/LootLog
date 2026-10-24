/// A reached goal's picture in a one-pixel dark frame: the custom trophy in a
/// room and the statue in the town square both draw it. Draws only; the
/// picture is already decoded.
library;

import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'dungeon/reveal.dart';

class GoalPictureFrame extends PositionComponent {
  GoalPictureFrame({
    required this.picture,
    required Vector2 position,
    required Vector2 size,
    int priority = 2,
  }) : super(position: position, size: size, priority: priority);

  static const double frameThickness = 1;
  static const Color frameColour = Color(0xFF140C1C);

  final ui.Image picture;

  @override
  Future<void> onLoad() async {
    await addAll([
      RectangleComponent(size: size, paint: Paint()..color = frameColour),
      RevealedPicture(
        picture: picture,
        fraction: 1,
        position: Vector2.all(frameThickness),
        size: size - Vector2.all(frameThickness * 2),
      ),
    ]);
  }
}
