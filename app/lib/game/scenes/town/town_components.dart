/// The town's Flame components. They only draw: taps are resolved by the
/// scene view through `TownView.targetAt`.
library;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../assets/asset_catalog.dart';
import '../../assets/asset_key.dart';
import '../../domain/town/town_layout.dart';
import '../../domain/town/town_view.dart';
import '../camera_controls.dart';
import '../pack_atlas.dart';

Vector2 cellPosition(TownCell cell) =>
    Vector2(cell.column * kTileSize, cell.row * kTileSize);

const _groundKeys = {
  TownGround.grass: AssetKey('town', 'ground', 'grass'),
  TownGround.path: AssetKey('town', 'ground', 'path'),
  TownGround.water: AssetKey('town', 'ground', 'water'),
  TownGround.square: AssetKey('town', 'ground', 'square'),
};

/// DawnBringer-16 fallback colours when a ground tile has no art.
const _groundColours = {
  TownGround.grass: Color(0xFF6DAA2C),
  TownGround.path: Color(0xFFD2AA99),
  TownGround.water: Color(0xFF597DCE),
  TownGround.square: Color(0xFF8595A1),
};

/// The small pixel font used for every label in the town.
TextPaint _smallLabelPaint({Color colour = const Color(0xFF140C1C)}) =>
    TextPaint(style: TextStyle(fontSize: 5, color: colour));

/// A name centred just under a 2x2-tile building or house.
TextComponent _nameUnder(Vector2 buildingSize, String text) => TextComponent(
  text: text,
  position: Vector2(buildingSize.x / 2, buildingSize.y + 1),
  anchor: Anchor.topCenter,
  textRenderer: _smallLabelPaint(),
);

/// Every ground tile, drawn in one pass.
class GroundLayer extends PositionComponent {
  GroundLayer(this.atlas, this.layout)
    : super(
        size: Vector2(layout.columns * kTileSize, layout.rows * kTileSize),
        priority: 0,
      );

  final PackAtlas atlas;
  final TownLayout layout;

  @override
  void render(Canvas canvas) {
    final tileSize = Vector2.all(kTileSize);
    for (var column = 0; column < layout.columns; column++) {
      for (var row = 0; row < layout.rows; row++) {
        final cell = TownCell(column, row);
        final ground = layout.groundAt(cell);
        final position = cellPosition(cell);
        final sprite = atlas.spriteFor(_groundKeys[ground]!);
        if (sprite != null) {
          sprite.render(canvas, position: position, size: tileSize);
        } else {
          canvas.drawRect(
            Rect.fromLTWH(position.x, position.y, kTileSize, kTileSize),
            Paint()..color = _groundColours[ground]!,
          );
        }
      }
    }
  }
}

/// A sprite for [assetKey], or a labelled placeholder card when it has no art.
class KeyedSprite extends PositionComponent {
  KeyedSprite({
    required this.atlas,
    required this.assetKey,
    required this.label,
    required Vector2 position,
    required Vector2 size,
    int priority = 1,
  }) : super(position: position, size: size, priority: priority);

  final PackAtlas atlas;
  final AssetKey assetKey;
  final String label;

  bool get hasArt => atlas.spriteFor(assetKey) != null;

  @override
  Future<void> onLoad() async {
    final sprite = atlas.spriteFor(assetKey);
    if (sprite != null) {
      add(SpriteComponent(sprite: sprite, size: size));
      return;
    }
    add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = const Color(0xCC30346D),
      ),
    );
    add(
      TextComponent(
        text: label,
        position: size / 2,
        anchor: Anchor.center,
        textRenderer: _smallLabelPaint(colour: const Color(0xFFDEEED6)),
      ),
    );
  }
}

/// What stands on one hall plot, plus scaffolding and the ready bubble. The
/// name is always drawn under the building: the bundled art reuses similar
/// cells for higher tiers, so the label is what tells buildings apart.
class PlotComponent extends PositionComponent {
  PlotComponent(this.atlas, this.plot)
    : super(
        position: cellPosition(plot.origin),
        size: Vector2.all(TownLayout.footprint * kTileSize),
        priority: 2,
      );

  final PackAtlas atlas;
  final TownPlotView plot;

  @override
  Future<void> onLoad() async {
    final buildingType = plot.buildingType;
    final AssetKey key;
    final String label;
    if (!plot.unlocked) {
      key = const AssetKey('town', 'plot', 'locked');
      label = 'Locked';
    } else if (buildingType == null) {
      key = const AssetKey('town', 'plot', 'empty');
      label = 'Build';
    } else {
      key = GameAssetKeys.building(buildingType, plot.tier);
      label = key.displayName;
    }
    add(
      KeyedSprite(
        atlas: atlas,
        assetKey: key,
        label: label,
        position: Vector2.zero(),
        size: size,
      ),
    );
    if (plot.underConstruction) {
      add(
        KeyedSprite(
          atlas: atlas,
          assetKey: const AssetKey('town', 'scaffold'),
          label: 'Building',
          position: Vector2.zero(),
          size: size,
          priority: 3,
        ),
      );
    }
    add(_nameUnder(size, label));
    if (plot.readyToCollect) {
      add(ReadyBubble(position: Vector2(size.x - 4, -2)));
    }
  }
}

/// The bobbing "ready to collect" marker.
class ReadyBubble extends CircleComponent {
  ReadyBubble({required Vector2 position})
    : super(
        radius: 4,
        position: position,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFFDAD45E),
        priority: 4,
      );

  @override
  Future<void> onLoad() async {
    add(
      MoveByEffect(
        Vector2(0, -2),
        EffectController(duration: 0.6, alternate: true, infinite: true),
      ),
    );
  }
}

/// A resident's house with their character (Adventure) or the parked supply
/// wagon (Standard) beside it, and their name underneath.
class HouseComponent extends PositionComponent {
  HouseComponent(this.atlas, this.resident)
    : super(
        position: cellPosition(resident.houseOrigin),
        size: Vector2.all(TownLayout.footprint * kTileSize),
        priority: 2,
      );

  final PackAtlas atlas;
  final TownResident resident;

  @override
  Future<void> onLoad() async {
    add(
      KeyedSprite(
        atlas: atlas,
        assetKey: const AssetKey('town', 'house'),
        label: 'Home',
        position: Vector2.zero(),
        size: size,
      ),
    );
    add(
      KeyedSprite(
        atlas: atlas,
        assetKey: resident.inAdventure
            ? const AssetKey('hero', 'body')
            : const AssetKey('town', 'wagon'),
        label: resident.inAdventure ? resident.name : 'Supplies',
        position: Vector2(size.x, size.y - kTileSize),
        size: Vector2.all(kTileSize),
        priority: 3,
      ),
    );
    add(_nameUnder(size, resident.name));
  }
}

/// A villager strolling back and forth along the main path. Cosmetic motion
/// only; switched off for tests and goldens.
class Villager extends KeyedSprite {
  Villager({
    required super.atlas,
    required super.position,
    required AssetKey villagerKey,
    required this.wanderTiles,
  }) : super(
         assetKey: villagerKey,
         label: 'Villager',
         size: Vector2.all(kTileSize),
         priority: 3,
       );

  final int wanderTiles;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      MoveByEffect(
        Vector2(wanderTiles * kTileSize, 0),
        EffectController(
          duration: wanderTiles.toDouble(),
          alternate: true,
          infinite: true,
        ),
      ),
    );
  }
}
