/// Hosts the [TownGame]: drags pan, pinches and the mouse wheel change the
/// whole-number zoom, and taps become [TownTarget]s.
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
import '../../domain/town/town_view.dart';
import '../pack_atlas.dart';
import '../scene_pictures.dart';
import 'town_game.dart';

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
  );
  int _zoomAtPinchStart = 3;

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
    builder: (context, constraints) => Listener(
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent) {
          _game.cameraControls.zoomStep(signal.scrollDelta.dy < 0 ? 1 : -1);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (details) =>
            _zoomAtPinchStart = _game.cameraControls.zoom,
        onScaleUpdate: (details) {
          if (details.pointerCount > 1) {
            _game.cameraControls.zoomTo(
              (_zoomAtPinchStart * details.scale).round(),
            );
          } else {
            _game.cameraControls.panByScreen(
              details.focalPointDelta.dx,
              details.focalPointDelta.dy,
            );
          }
        },
        onTapUp: (details) {
          final cell = _game.cameraControls.cellAt(
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
    ),
  );
}
