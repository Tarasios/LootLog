/// The room's Flame components: floor and walls, placed items, the character.
library;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../assets/asset_key.dart';
import '../../domain/decor/room_grid.dart';
import '../camera_controls.dart';
import '../goal_picture_frame.dart';
import '../pack_atlas.dart';
import '../town/town_components.dart' show KeyedSprite;
import 'room_game.dart';

/// Tiles across and down the room including its one-tile wall border.
const int kRoomTileColumns = RoomGrid.columns + 2;
const int kRoomTileRows = RoomGrid.rows + 2;

/// Floor tiles inside a one-tile wall border.
class RoomFloor extends PositionComponent {
  RoomFloor(this.atlas)
    : super(
        size: Vector2(kRoomTileColumns * kTileSize, kRoomTileRows * kTileSize),
        priority: 0,
      );

  final PackAtlas atlas;

  @override
  void render(Canvas canvas) {
    final floor = atlas.spriteFor(const AssetKey('room', 'floor', 'wood'));
    final wall = atlas.spriteFor(const AssetKey('room', 'wall'));
    final tile = Vector2.all(kTileSize);
    for (var column = 0; column < kRoomTileColumns; column++) {
      for (var row = 0; row < kRoomTileRows; row++) {
        final isWall =
            column == 0 ||
            row == 0 ||
            column == kRoomTileColumns - 1 ||
            row == kRoomTileRows - 1;
        final position = Vector2(column * kTileSize, row * kTileSize);
        final sprite = isWall ? wall : floor;
        if (sprite != null) {
          sprite.render(canvas, position: position, size: tile);
        } else {
          canvas.drawRect(
            Rect.fromLTWH(position.x, position.y, kTileSize, kTileSize),
            Paint()
              ..color = isWall
                  ? const Color(0xFF442434)
                  : const Color(0xFF854C30),
          );
        }
      }
    }
  }
}

/// One placed item, offset by the wall border.
class RoomItemComponent extends KeyedSprite {
  RoomItemComponent({required super.atlas, required this.itemView})
    : super(
        assetKey: itemView.item.assetKey,
        label: itemView.item.name,
        position: Vector2(
          (itemView.placement.column + 1) * kTileSize,
          (itemView.placement.row + 1) * kTileSize,
        ),
        size: Vector2(
          _width(itemView) * kTileSize,
          _height(itemView) * kTileSize,
        ),
        priority: 2,
      );

  final RoomItemView itemView;

  static bool _turned(RoomItemView view) => view.placement.rotation.isOdd;
  static int _width(RoomItemView view) =>
      _turned(view) ? view.item.footprintRows : view.item.footprintColumns;
  static int _height(RoomItemView view) =>
      _turned(view) ? view.item.footprintColumns : view.item.footprintRows;
}

/// A custom trophy: the goal's own picture in a thin frame, offset by the
/// wall border like any placed item.
class RoomTrophyPicture extends GoalPictureFrame {
  RoomTrophyPicture({required super.picture, required this.itemView})
    : super(
        position: Vector2(
          (itemView.placement.column + 1) * kTileSize,
          (itemView.placement.row + 1) * kTileSize,
        ),
        size: Vector2.all(kTileSize),
      );

  final RoomItemView itemView;
}

/// The room owner's character in their worn outfit, standing near the door.
class RoomCharacter extends KeyedSprite {
  RoomCharacter({
    required super.atlas,
    required AssetKey characterKey,
    required String ownerName,
  }) : super(
         assetKey: characterKey,
         label: ownerName,
         position: Vector2(
           (RoomGrid.columns / 2) * kTileSize,
           RoomGrid.rows * kTileSize,
         ),
         size: Vector2.all(kTileSize),
         priority: 3,
       );
}
