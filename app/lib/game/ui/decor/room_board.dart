/// The wood board a room sits on: a [PixelFrame] of [KitKeys.wood] filling the
/// space it is given, with the room scene centred on it at exactly the room's
/// size, at the largest whole zoom that fits inside the frame. Only when the
/// frame would shrink the room to the smallest zoom (a phone's width) does the
/// room take the zoom the whole board allows, its walls covering the frame's
/// edge — a readable room matters more than a visible frame.
///
/// In the text tier (or before the scene can start) the board holds the
/// [fallback] instead — the room as a list on parchment, or nothing.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../scenes/camera_controls.dart';
import '../../scenes/room/room_components.dart';
import '../../scenes/room/room_scene_view.dart';
import '../kit/kit.dart';

/// The room's size in world pixels, walls included.
const Size _kRoomWorldSize = Size(kRoomTileColumns * kTileSize, kRoomTileRows * kTileSize);

/// How far in from the board's edge the room keeps, clear of the frame.
const double _kFrameInset = 14;

/// Content inside the board (the text-tier list) keeps clear of the frame.
const EdgeInsets _kBoardPadding = EdgeInsets.all(_kFrameInset);

class RoomBoard extends StatelessWidget {
  const RoomBoard({super.key, this.scene, this.fallback});

  /// The pixel scene (a [RoomSceneView]); it is laid out at the room's exact
  /// size, so its own fit lands on the same zoom.
  final Widget? scene;

  /// Shown on parchment inside the frame when there is no [scene].
  final Widget? fallback;

  /// The scene's size for a board of [space]: the room at the largest whole
  /// zoom that fits inside the frame (or, when that is the smallest zoom, the
  /// whole board), never larger than the board.
  static Size sceneSizeFor(Size space) {
    final insideFrame = RoomSceneView.fitZoom(Size(
      math.max(0, space.width - _kFrameInset * 2),
      math.max(0, space.height - _kFrameInset * 2),
    ));
    final zoom =
        insideFrame > CameraControls.minZoom ? insideFrame : RoomSceneView.fitZoom(space);
    return Size(
      math.min(_kRoomWorldSize.width * zoom, space.width),
      math.min(_kRoomWorldSize.height * zoom, space.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scene = this.scene;
    final fallback = this.fallback;
    if (scene == null) {
      return PixelFrame(
        key: const ValueKey('room-board'),
        assetKey: KitKeys.wood,
        fallbackFill: AdventureTokens.wood,
        fallbackBorder: AdventureTokens.woodDark,
        padding: _kBoardPadding,
        child: fallback == null
            ? const SizedBox.expand()
            : ColoredBox(color: AdventureTokens.parchment, child: fallback),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final sceneSize = sceneSizeFor(constraints.biggest);
        return Stack(
          key: const ValueKey('room-board'),
          children: [
            const Positioned.fill(
              child: PixelFrame(
                assetKey: KitKeys.wood,
                fallbackFill: AdventureTokens.wood,
                fallbackBorder: AdventureTokens.woodDark,
                padding: EdgeInsets.zero,
                child: SizedBox.expand(),
              ),
            ),
            Center(child: SizedBox.fromSize(size: sceneSize, child: scene)),
          ],
        );
      },
    );
  }
}
