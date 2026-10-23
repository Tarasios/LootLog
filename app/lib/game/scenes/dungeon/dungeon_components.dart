/// The month-end dungeon's Flame components. They only draw what the battle
/// screen tells them; no money is computed here.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../assets/asset_key.dart';
import '../camera_controls.dart';
import '../pack_atlas.dart';
import '../town/town_components.dart' show KeyedSprite;
import 'reveal.dart';

/// DawnBringer-16 colours used by the dungeon when a tile has no art, and
/// for the HP bars, numbers and coins.
abstract final class DungeonColours {
  static const wall = Color(0xFF30346D);
  static const floor = Color(0xFF4E4A4E);
  static const barBack = Color(0xFF140C1C);
  static const hp = Color(0xFFD04648);
  static const label = Color(0xFFDEEED6);
  static const damage = Color(0xFFDAD45E);
  static const tax = Color(0xFF8595A1);
}

/// The dungeon backdrop: a wall row over floor tiles.
class DungeonBackdrop extends PositionComponent {
  DungeonBackdrop(this.atlas, {required int columns, required int rows})
      : super(size: Vector2(columns * kTileSize, rows * kTileSize), priority: 0);

  final PackAtlas atlas;

  @override
  void render(Canvas canvas) {
    final floor = atlas.spriteFor(const AssetKey('dungeon', 'floor'));
    final wall = atlas.spriteFor(const AssetKey('dungeon', 'wall'));
    final tile = Vector2.all(kTileSize);
    final columns = (size.x / kTileSize).round();
    final rows = (size.y / kTileSize).round();
    for (var column = 0; column < columns; column++) {
      for (var row = 0; row < rows; row++) {
        final position = Vector2(column * kTileSize, row * kTileSize);
        final sprite = row == 0 ? wall : floor;
        if (sprite != null) {
          sprite.render(canvas, position: position, size: tile);
        } else {
          canvas.drawRect(
            Rect.fromLTWH(position.x, position.y, kTileSize, kTileSize),
            Paint()..color = row == 0 ? DungeonColours.wall : DungeonColours.floor,
          );
        }
      }
    }
  }
}

/// A goal boss or debt monster: its sprite, the goal picture rising behind
/// it, its name, and an HP bar.
class TargetComponent extends PositionComponent {
  TargetComponent({
    required this.atlas,
    required this.targetId,
    required this.spriteKey,
    required this.label,
    required this.remainingFraction,
    this.picture,
    this.revealFraction = 0,
    required Vector2 position,
  }) : super(position: position, size: Vector2.all(3 * kTileSize), priority: 2);

  static const double _barHeight = 3;

  final PackAtlas atlas;
  final String targetId;
  final AssetKey spriteKey;
  final String label;

  /// The share of HP left (0..1): what is still to save or still owed.
  double remainingFraction;
  final ui.Image? picture;

  /// The share of the goal picture shown (0..1).
  double revealFraction;
  RectangleComponent? _hpFill;
  RevealedPicture? _reveal;

  Vector2 _hpSize(double remaining) => Vector2(size.x * remaining.clamp(0.0, 1.0), _barHeight);

  @override
  Future<void> onLoad() async {
    final image = picture;
    if (image != null) {
      final reveal = RevealedPicture(picture: image, fraction: revealFraction, position: Vector2.zero(), size: size);
      _reveal = reveal;
      add(reveal);
    }
    add(KeyedSprite(atlas: atlas, assetKey: spriteKey, label: label, position: Vector2.zero(), size: size, priority: 2));
    add(RectangleComponent(
      position: Vector2(0, size.y + 2),
      size: Vector2(size.x, _barHeight),
      paint: Paint()..color = DungeonColours.barBack,
      priority: 3,
    ));
    final hpFill = RectangleComponent(
      position: Vector2(0, size.y + 2),
      size: _hpSize(remainingFraction),
      paint: Paint()..color = DungeonColours.hp,
      priority: 4,
    );
    _hpFill = hpFill;
    add(hpFill);
    add(TextComponent(
      text: label,
      position: Vector2(size.x / 2, size.y + 7),
      anchor: Anchor.topCenter,
      priority: 4,
      textRenderer: TextPaint(style: const TextStyle(fontSize: 5, color: DungeonColours.label)),
    ));
  }

  /// Shows the target's new HP and reveal, with a small shake when hit.
  void setProgress({required double remaining, required double reveal}) {
    if (remaining == remainingFraction && reveal == revealFraction) return;
    remainingFraction = remaining;
    revealFraction = reveal;
    _hpFill?.size = _hpSize(remaining);
    _reveal?.fraction = reveal;
    unawaited(addAll([
      SequenceEffect([
        MoveByEffect(Vector2(2, 0), EffectController(duration: 0.05)),
        MoveByEffect(Vector2(-4, 0), EffectController(duration: 0.05)),
        MoveByEffect(Vector2(2, 0), EffectController(duration: 0.05)),
      ]),
    ]));
  }
}

/// A number that floats up and fades: what landed in yellow, the tax in grey.
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

/// A coin flying from the hit to the war chest.
class FlyingCoin extends CircleComponent {
  FlyingCoin({required Vector2 from, required this.destination})
      : super(
          radius: 2,
          position: from,
          anchor: Anchor.center,
          paint: Paint()..color = DungeonColours.damage,
          priority: 11,
        );

  /// Where the coin lands (the war chest).
  final Vector2 destination;

  @override
  Future<void> onLoad() async {
    add(MoveToEffect(destination, EffectController(duration: 0.7, curve: Curves.easeIn)));
    add(RemoveEffect(delay: 0.75));
  }
}
