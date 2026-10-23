/// Hosts the [TownGame]: drags pan, pinches and the mouse wheel change the
/// whole-number zoom, and taps become [TownTarget]s.
library;

import 'dart:async';

import 'package:flame/cache.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../assets/asset_registry.dart';
import '../../domain/town/town_view.dart';
import '../pack_atlas.dart';
import 'town_game.dart';

export 'town_game.dart' show TownsfolkEntry;

class TownSceneView extends StatefulWidget {
  const TownSceneView({
    super.key,
    required this.view,
    required this.registry,
    required this.onTarget,
    this.ambientLife = true,
    this.townsfolk = const [],
  });

  final TownView view;
  final AssetRegistry registry;
  final void Function(TownTarget target) onTarget;
  final bool ambientLife;

  /// Dependents and pets who stroll the town.
  final List<TownsfolkEntry> townsfolk;

  @override
  State<TownSceneView> createState() => _TownSceneViewState();
}

class _TownSceneViewState extends State<TownSceneView> {
  late final TownGame _game = TownGame(
    atlas: PackAtlas(widget.registry, Images(prefix: 'assets/game/')),
    view: widget.view,
    ambientLife: widget.ambientLife,
    townsfolk: widget.townsfolk,
  );
  int _zoomAtPinchStart = 3;

  @override
  void didUpdateWidget(TownSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view != widget.view) {
      unawaited(_game.updateView(widget.view));
    }
    if (!listEquals(oldWidget.townsfolk, widget.townsfolk)) {
      unawaited(_game.updateTownsfolk(widget.townsfolk));
    }
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
          final target = widget.view.targetAt(cell);
          if (target != null) widget.onTarget(target);
        },
        child: GameWidget(game: _game),
      ),
    ),
  );
}
