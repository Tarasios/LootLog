/// Hosts the [TownGame]: drags pan, pinches and the mouse wheel change the
/// whole-number zoom, and taps become [TownTarget]s. On first layout the zoom
/// is the largest whole number that fits the town's height in the window, and
/// the town's tags float over it as Flutter signs that follow the camera.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../assets/asset_registry.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/town/town_layout.dart' show TownCell;
import '../../domain/town/town_scatter.dart';
import '../../domain/town/town_tags.dart';
import '../../domain/town/town_view.dart';
import '../../ui/kit/hud.dart' show FloatingTag;
import '../camera_controls.dart';
import '../pack_atlas.dart';
import '../scene_pictures.dart';
import 'town_game.dart';
import 'town_tag_placement.dart';

export 'town_game.dart' show LogPulse, TownsfolkEntry;

class TownSceneView extends StatefulWidget {
  const TownSceneView({
    super.key,
    required this.view,
    required this.registry,
    required this.onTarget,
    this.ambientLife = true,
    this.townsfolk = const [],
    this.catalog = DecorCatalog.empty,
    this.pictures = const {},
    this.onCellTap,
    this.logPulse,
    this.scatter = const TownScatter(props: [], borderWidth: 0),
    this.tags = const [],
  });

  final TownView view;
  final AssetRegistry registry;
  final void Function(TownTarget target) onTarget;
  final bool ambientLife;

  /// Dependents and pets who stroll the town.
  final List<TownsfolkEntry> townsfolk;

  /// Names and art of the placed decorations.
  final DecorCatalog catalog;

  /// Decoded goal pictures by sha256, for statues.
  final Map<String, ui.Image> pictures;

  /// When set (decorating mode), every tap reports its cell here instead of
  /// resolving to a [TownTarget].
  final void Function(TownCell cell)? onCellTap;

  /// The latest log to celebrate; a new [LogPulse.sequence] plays it once.
  final LogPulse? logPulse;

  /// The forest framing the town; read once, when the scene is built.
  final TownScatter scatter;

  /// The small signs over buildings, the gate and the statues.
  final List<TownTag> tags;

  @override
  State<TownSceneView> createState() => _TownSceneViewState();
}

class _TownSceneViewState extends State<TownSceneView> {
  late ScenePictures _pictures = ScenePictures(widget.pictures);
  late final TownGame _game = TownGame(
    atlas: PackAtlas.shared(widget.registry),
    view: widget.view,
    ambientLife: widget.ambientLife,
    townsfolk: widget.townsfolk,
    catalog: widget.catalog,
    pictures: _pictures.images,
    scatter: widget.scatter,
  );
  int _zoomAtPinchStart = 3;

  /// Whether the zoom has been fitted to the window yet (first layout only,
  /// so a zoom the player chose survives resizes).
  bool _zoomFitted = false;

  CameraControls get _camera => _game.cameraControls;

  /// Changes the camera, then rebuilds so the tags follow it.
  void _moveCamera(void Function(CameraControls camera) change) =>
      setState(() => change(_camera));

  void _fitViewport(BoxConstraints constraints) {
    _camera.setViewport(constraints.maxWidth, constraints.maxHeight);
    if (_zoomFitted) return;
    _zoomFitted = true;
    _camera.zoomTo(
      CameraControls.fitZoom(
        viewportHeight: constraints.maxHeight,
        worldHeight: widget.view.layout.rows * kTileSize,
      ),
    );
  }

  @override
  void didUpdateWidget(TownSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final picturesChanged = !identical(oldWidget.pictures, widget.pictures);
    if (oldWidget.view != widget.view ||
        picturesChanged ||
        !identical(oldWidget.catalog, widget.catalog)) {
      final previous = picturesChanged ? _pictures : null;
      if (picturesChanged) _pictures = ScenePictures(widget.pictures);
      unawaited(
        _game
            .updateView(
              widget.view,
              newPictures: _pictures.images,
              newCatalog: widget.catalog,
            )
            .whenComplete(() => previous?.dispose()),
      );
    }
    if (!listEquals(oldWidget.townsfolk, widget.townsfolk)) {
      unawaited(_game.updateTownsfolk(widget.townsfolk));
    }
    final pulse = widget.logPulse;
    if (pulse != null && pulse.sequence != oldWidget.logPulse?.sequence) {
      _game.celebrateLog(pulse);
    }
  }

  @override
  void dispose() {
    _pictures.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _fitViewport(constraints);
      return Stack(
        children: [
          Positioned.fill(child: _gestures(constraints)),
          // Signs never take taps: the building underneath does.
          for (final placed in placeTownTags(widget.tags, widget.view))
            Positioned.fill(
              child: IgnorePointer(
                child: CustomSingleChildLayout(
                  delegate: _TagLayout(_screenPoint(placed, constraints)),
                  child: FloatingTag(
                    placed.tag.text,
                    urgent: placed.tag.urgent,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Offset _screenPoint(PlacedTownTag placed, BoxConstraints constraints) {
    final point = _camera.worldToScreen(
      placed.worldX,
      placed.worldY,
      constraints.maxWidth,
      constraints.maxHeight,
    );
    return Offset(point.x, point.y);
  }

  Widget _gestures(BoxConstraints constraints) => Listener(
    onPointerSignal: (signal) {
      if (signal is PointerScrollEvent) {
        _moveCamera(
          (camera) => camera.zoomStep(signal.scrollDelta.dy < 0 ? 1 : -1),
        );
      }
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) => _zoomAtPinchStart = _camera.zoom,
      onScaleUpdate: (details) {
        if (details.pointerCount > 1) {
          _moveCamera(
            (camera) =>
                camera.zoomTo((_zoomAtPinchStart * details.scale).round()),
          );
        } else {
          _moveCamera(
            (camera) => camera.panByScreen(
              details.focalPointDelta.dx,
              details.focalPointDelta.dy,
            ),
          );
        }
      },
      onTapUp: (details) {
        final cell = _camera.cellAt(
          details.localPosition.dx,
          details.localPosition.dy,
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final onCellTap = widget.onCellTap;
        if (onCellTap != null) {
          onCellTap(cell);
          return;
        }
        final target = widget.view.targetAt(cell);
        if (target != null) widget.onTarget(target);
      },
      child: GameWidget(game: _game),
    ),
  );
}

/// Hangs a tag with its pointer's tip on [anchor], then nudges it inside the
/// viewport so a sign near an edge is never cut off.
class _TagLayout extends SingleChildLayoutDelegate {
  _TagLayout(this.anchor);

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (anchor.dx - childSize.width / 2).clamp(
      0.0,
      (size.width - childSize.width).clamp(0.0, double.infinity),
    );
    final top = (anchor.dy - childSize.height).clamp(
      0.0,
      (size.height - childSize.height).clamp(0.0, double.infinity),
    );
    return Offset(left.roundToDouble(), top.roundToDouble());
  }

  @override
  bool shouldRelayout(_TagLayout oldDelegate) => oldDelegate.anchor != anchor;
}
