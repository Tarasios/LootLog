/// A Flame sprite for a pack region that spans several cells of a sheet with
/// spacing: it draws cell by cell, skipping the sheet's transparent gaps, so
/// two-cell furniture never shows a seam down the middle.
library;

import 'dart:ui';

import 'package:flame/components.dart';

import '../assets/region_cells.dart';
import '../assets/sprite_region.dart';

class RegionSprite extends Sprite {
  RegionSprite(super.image, this.region)
      : super(
          srcPosition: Vector2(region.left.toDouble(), region.top.toDouble()),
          // The drawn size: the cells packed edge to edge.
          srcSize: Vector2(region.packedWidth.toDouble(), region.packedHeight.toDouble()),
        );

  final SpriteRegion region;

  @override
  void render(
    Canvas canvas, {
    Vector2? position,
    Vector2? size,
    Anchor anchor = Anchor.topLeft,
    Paint? overridePaint,
    double? bleed,
  }) {
    final drawSize = size ?? srcSize;
    final extra = bleed ?? 0;
    final destination = Rect.fromLTWH(
      (position?.x ?? 0) - anchor.x * drawSize.x - extra,
      (position?.y ?? 0) - anchor.y * drawSize.y - extra,
      drawSize.x + extra * 2,
      drawSize.y + extra * 2,
    );
    drawRegionCells(canvas, image, region, destination, overridePaint ?? paint);
  }
}
