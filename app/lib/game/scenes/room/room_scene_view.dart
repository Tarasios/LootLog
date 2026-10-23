/// Hosts the [RoomGame] at the largest whole zoom that fits the whole room,
/// and turns taps and drops into room grid cells.
library;

import 'dart:async';

import 'package:flame/cache.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import '../../assets/asset_registry.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/decor/room_grid.dart';
import '../camera_controls.dart';
import '../pack_atlas.dart';
import 'room_components.dart';
import 'room_game.dart';

class RoomSceneView extends StatefulWidget {
  const RoomSceneView({
    super.key,
    required this.view,
    required this.registry,
    required this.onCellTap,
    required this.onDrop,
  });

  final RoomView view;
  final AssetRegistry registry;
  final void Function(int column, int row) onCellTap;
  final void Function(DecorItem item, int column, int row) onDrop;

  /// The largest whole zoom at which the whole room (walls included) fits a
  /// [viewport], never below the camera's minimum.
  static int fitZoom(Size viewport) {
    final fitsWide = viewport.width ~/ (kRoomTileColumns * kTileSize);
    final fitsTall = viewport.height ~/ (kRoomTileRows * kTileSize);
    final fit = fitsWide < fitsTall ? fitsWide : fitsTall;
    return fit.clamp(CameraControls.minZoom, CameraControls.maxZoom);
  }

  @override
  State<RoomSceneView> createState() => _RoomSceneViewState();
}

class _RoomSceneViewState extends State<RoomSceneView> {
  late final RoomGame _game = RoomGame(
    atlas: PackAtlas(widget.registry, Images(prefix: 'assets/game/')),
    view: widget.view,
  );

  @override
  void didUpdateWidget(RoomSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.view, widget.view)) {
      unawaited(_game.updateView(widget.view));
    }
  }

  /// The room cell under [local] (inside the wall border), or null for the
  /// walls and anything outside the room.
  (int, int)? _gridCell(Offset local, Size viewport) {
    final cell = _game.cameraControls.cellAt(
      local.dx,
      local.dy,
      viewport.width,
      viewport.height,
    );
    final column = cell.column - 1;
    final row = cell.row - 1;
    if (column < 0 ||
        row < 0 ||
        column >= RoomGrid.columns ||
        row >= RoomGrid.rows) {
      return null;
    }
    return (column, row);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = Size(constraints.maxWidth, constraints.maxHeight);
      _game.cameraControls.zoomTo(RoomSceneView.fitZoom(viewport));
      final halfCell = _game.cameraControls.zoom * kTileSize / 2;
      return DragTarget<DecorItem>(
        onAcceptWithDetails: (details) {
          final box = context.findRenderObject()! as RenderBox;
          // The drop offset is the dragged sprite's top-left corner, and an
          // item is placed by its top-left cell.
          final corner = box.globalToLocal(details.offset);
          final cell = _gridCell(
            corner.translate(halfCell, halfCell),
            viewport,
          );
          if (cell != null) widget.onDrop(details.data, cell.$1, cell.$2);
        },
        builder: (context, candidates, rejected) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final cell = _gridCell(details.localPosition, viewport);
            if (cell != null) widget.onCellTap(cell.$1, cell.$2);
          },
          child: GameWidget(game: _game),
        ),
      );
    },
  );
}
