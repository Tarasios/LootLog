/// The town's Flame components. They only draw: taps are resolved by the
/// scene view through `TownView.targetAt`.
library;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../assets/asset_catalog.dart';
import '../../assets/asset_key.dart';
import '../../domain/town/districts.dart' show kOutpostDistrictId;
import '../../domain/town/town_layout.dart';
import '../../domain/town/town_scatter.dart';
import '../../domain/town/town_view.dart';
import '../camera_controls.dart';
import '../goal_picture_frame.dart';
import '../pack_atlas.dart';
import 'name_label.dart';

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
TextComponent _nameUnder(Vector2 buildingSize, String text) => ViewportClampedLabel(
  text: text,
  home: Vector2(buildingSize.x / 2, buildingSize.y + 1),
  ownerWidth: buildingSize.x,
  textRenderer: _smallLabelPaint(),
);

/// Every ground tile, drawn in one pass: the map, plus [borderWidth] cells of
/// grass on every side for the forest that frames it.
class GroundLayer extends PositionComponent {
  GroundLayer(this.atlas, this.layout, {this.borderWidth = 0})
    : super(
        size: Vector2(layout.columns * kTileSize, layout.rows * kTileSize),
        priority: 0,
      );

  final PackAtlas atlas;
  final TownLayout layout;
  final int borderWidth;

  bool _onMap(TownCell cell) =>
      cell.column >= 0 &&
      cell.column < layout.columns &&
      cell.row >= 0 &&
      cell.row < layout.rows;

  @override
  void render(Canvas canvas) {
    final tileSize = Vector2.all(kTileSize);
    for (var column = -borderWidth; column < layout.columns + borderWidth; column++) {
      for (var row = -borderWidth; row < layout.rows + borderWidth; row++) {
        final cell = TownCell(column, row);
        final ground = _onMap(cell) ? layout.groundAt(cell) : TownGround.grass;
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
        if (ground == TownGround.water) _drawShore(canvas, cell);
      }
    }
  }

  static final Paint _shorePaint = Paint()..color = const Color(0xFF2F5F9E);

  bool _isWater(TownCell cell) =>
      _onMap(cell) && layout.groundAt(cell) == TownGround.water;

  /// A one-pixel darker bank on each side of a water [cell] that meets land
  /// inside the map (the map's own edge runs on under the forest).
  void _drawShore(Canvas canvas, TownCell cell) {
    final position = cellPosition(cell);
    final left = position.x, top = position.y;
    for (final (columnStep, rowStep, bank) in [
      (-1, 0, Rect.fromLTWH(left, top, 1, kTileSize)),
      (1, 0, Rect.fromLTWH(left + kTileSize - 1, top, 1, kTileSize)),
      (0, -1, Rect.fromLTWH(left, top, kTileSize, 1)),
      (0, 1, Rect.fromLTWH(left, top + kTileSize - 1, kTileSize, 1)),
    ]) {
      final neighbour = TownCell(cell.column + columnStep, cell.row + rowStep);
      if (_onMap(neighbour) && !_isWater(neighbour)) {
        canvas.drawRect(bank, _shorePaint);
      }
    }
  }
}

/// The scattered trees and bushes, drawn in one pass under the buildings. A
/// prop with no art is a plain dark-green blob (never a label: there are
/// hundreds of them).
class ScatterLayer extends PositionComponent {
  ScatterLayer(this.atlas, this.scatter) : super(priority: 1);

  final PackAtlas atlas;
  final TownScatter scatter;

  static const Color _fallbackColour = Color(0xFF346524);

  /// Each prop key's sprite (null: no art), looked up once.
  final Map<String, Sprite?> _sprites = {};

  @override
  void render(Canvas canvas) {
    final tileSize = Vector2.all(kTileSize);
    final fallback = Paint()..color = _fallbackColour;
    for (final prop in scatter.props) {
      final sprite = _sprites.putIfAbsent(
        prop.assetKey,
        () => atlas.spriteFor(AssetKey.parse(prop.assetKey)),
      );
      final position = cellPosition(TownCell(prop.column, prop.row));
      if (sprite != null) {
        sprite.render(canvas, position: position, size: tileSize);
      } else {
        canvas.drawRect(
          Rect.fromLTWH(position.x + 3, position.y + 3, kTileSize - 6, kTileSize - 6),
          fallback,
        );
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
      add(
        SpriteComponent(
          sprite: sprite,
          size: size,
          paint: Paint()..filterQuality = FilterQuality.none,
        ),
      );
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

/// A decoration (bench, lamp post, plain statue) standing on one grass or
/// statue cell, labelled when it has no art.
class TownDecorComponent extends KeyedSprite {
  TownDecorComponent({
    required super.atlas,
    required super.assetKey,
    required super.label,
    required TownCell cell,
  }) : super(
         position: cellPosition(cell),
         size: Vector2.all(kTileSize),
         priority: 2,
       );
}

/// A goal statue showing its goal's own picture in a thin frame.
class TownStatuePicture extends GoalPictureFrame {
  TownStatuePicture({required super.picture, required TownCell cell})
    : super(position: cellPosition(cell), size: Vector2.all(kTileSize));
}

/// The art key of the building on [plot] (an outpost building or a farm
/// building), or null for a locked or empty plot.
AssetKey? plotArtKey(TownPlotView plot) {
  if (plot.buildingType case final type?) return GameAssetKeys.building(type, plot.tier);
  if (plot.farmType case final type?) return GameAssetKeys.farmBuilding(type, plot.tier);
  return null;
}

/// Where art [artWidth] × [artHeight] is drawn on a plot [footprint] wide
/// and tall, relative to the plot's top-left: square art fills the plot;
/// taller art (a tier 3–5 building) keeps the plot's width and stands on its
/// foot, rising into the row above.
Rect plotArtBounds({
  required double artWidth,
  required double artHeight,
  required double footprint,
}) {
  if (artWidth <= 0 || artHeight <= artWidth) {
    return Rect.fromLTWH(0, 0, footprint, footprint);
  }
  final height = footprint * artHeight / artWidth;
  return Rect.fromLTWH(0, footprint - height, footprint, height);
}

/// What stands on one plot (the outpost's hall plots or a district's),
/// plus scaffolding and the ready bubble. The name is always drawn under
/// the building: the bundled art reuses similar cells for some tiers, so the
/// label is what tells buildings apart.
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
    final buildingKey = plotArtKey(plot);
    final AssetKey key;
    final String label;
    if (!plot.unlocked) {
      key = const AssetKey('town', 'plot', 'locked');
      label = 'Locked';
    } else if (buildingKey == null) {
      key = plot.districtId == kOutpostDistrictId ? const AssetKey('town', 'plot', 'empty') : GameAssetKeys.farmPlotEmpty;
      label = 'Build';
    } else {
      key = buildingKey;
      label = key.displayName;
    }
    final art = atlas.spriteFor(key);
    final bounds = plotArtBounds(
      artWidth: art?.srcSize.x ?? 0,
      artHeight: art?.srcSize.y ?? 0,
      footprint: size.x,
    );
    add(
      KeyedSprite(
        atlas: atlas,
        assetKey: key,
        label: label,
        position: Vector2(bounds.left, bounds.top),
        size: Vector2(bounds.width, bounds.height),
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

/// The pulsing yellow glow behind the dungeon gate while a month-end ritual
/// waits below.
class GateGlow extends CircleComponent {
  GateGlow({required Vector2 position})
    : super(
        radius: kTileSize * 0.75,
        position: position,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0x99DAD45E),
        priority: 1,
      );

  @override
  Future<void> onLoad() async {
    add(
      ScaleEffect.to(
        Vector2.all(1.3),
        EffectController(duration: 0.8, alternate: true, infinite: true),
      ),
    );
  }
}

/// A resident's house with their character (Adventure) and their name
/// underneath, or the parked supply wagon (Standard), never named.
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
    // A Standard adult's wagon is never named (design rule 7).
    if (resident.inAdventure) add(_nameUnder(size, resident.name));
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
    super.label = 'Villager',
  }) : super(
         assetKey: villagerKey,
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
