/// Small celebratory Flame effects shared by the scenes: a number that
/// floats up and fades, and a spark that flies to a destination. They only
/// draw what a screen tells them; no money or reward is computed here.
library;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// DawnBringer-16 colours for the effects.
abstract final class EffectColours {
  static const gold = Color(0xFFDAD45E);
  static const grey = Color(0xFF8595A1);
  static const gem = Color(0xFF6DC2CA);
  static const sparkle = Color(0xFFDEEED6);
}

/// A number (or a short word) that floats up and fades.
class FloatingNumber extends TextComponent {
  FloatingNumber({required String text, required Vector2 position, required Color colour})
      : super(
          text: text,
          position: position,
          anchor: Anchor.center,
          priority: 10,
          textRenderer: TextPaint(style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colour)),
        );

  @override
  Future<void> onLoad() async {
    add(MoveByEffect(Vector2(0, -18), EffectController(duration: 0.9)));
    add(RemoveEffect(delay: 1));
  }
}

/// A spark flying from [from] to [destination]: a coin to the war chest in
/// the dungeon, a gem to a house in the town.
class FlyingCoin extends CircleComponent {
  FlyingCoin({
    required Vector2 from,
    required this.destination,
    Color colour = EffectColours.gold,
    double radius = 2,
    this.delay = 0,
  }) : super(
          radius: radius,
          position: from,
          anchor: Anchor.center,
          paint: Paint()..color = colour,
          priority: 11,
        );

  /// Where the spark lands.
  final Vector2 destination;

  /// Seconds before it sets off, so a handful flies in a stream.
  final double delay;

  @override
  Future<void> onLoad() async {
    add(MoveToEffect(destination, EffectController(duration: 0.7, startDelay: delay, curve: Curves.easeIn)));
    add(RemoveEffect(delay: delay + 0.75));
  }
}

/// A twinkle that swells and fades where something good just happened.
class Sparkle extends CircleComponent {
  Sparkle({required Vector2 position, this.delay = 0})
      : super(
          radius: 1.5,
          position: position,
          anchor: Anchor.center,
          paint: Paint()..color = EffectColours.sparkle,
          priority: 11,
        );

  final double delay;

  @override
  Future<void> onLoad() async {
    add(ScaleEffect.to(Vector2.all(2.5), EffectController(duration: 0.4, startDelay: delay, alternate: true)));
    add(RemoveEffect(delay: delay + 0.85));
  }
}
