/// The town scene: ground, trees, the gate, plots, houses and (optionally)
/// strolling villagers. Rebuilt from a [TownView]; it holds no game rules.
library;

import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../../assets/asset_catalog.dart';
import '../../assets/asset_key.dart';
import '../../domain/town/town_layout.dart';
import '../../domain/town/town_view.dart';
import '../camera_controls.dart';
import '../pack_atlas.dart';
import 'town_components.dart';

class TownGame extends FlameGame {
  TownGame({
    required this.atlas,
    required TownView view,
    this.ambientLife = true,
  }) : _view = view,
       cameraControls = CameraControls(
         worldWidth: view.layout.columns * kTileSize,
         worldHeight: view.layout.rows * kTileSize,
       );

  final PackAtlas atlas;
  final bool ambientLife;
  final CameraControls cameraControls;
  TownView _view;
  final List<Component> _plotsAndHouses = [];

  /// Every key the scene can draw, for preloading.
  static Iterable<AssetKey> keysFor(TownView view) sync* {
    yield* const [
      AssetKey('town', 'ground', 'grass'),
      AssetKey('town', 'ground', 'path'),
      AssetKey('town', 'ground', 'water'),
      AssetKey('town', 'ground', 'square'),
      AssetKey('town', 'tree'),
      AssetKey('town', 'gate', 'dungeon'),
      AssetKey('town', 'house'),
      AssetKey('town', 'wagon'),
      AssetKey('town', 'scaffold'),
      AssetKey('town', 'plot', 'locked'),
      AssetKey('town', 'plot', 'empty'),
      AssetKey('hero', 'body'),
      AssetKey('npc', 'villager', 'a'),
      AssetKey('npc', 'villager', 'b'),
    ];
    for (final plot in view.plots) {
      final buildingType = plot.buildingType;
      if (buildingType != null) {
        yield GameAssetKeys.building(buildingType, plot.tier);
      }
    }
  }

  @override
  Future<void> onLoad() async {
    await atlas.preload(keysFor(_view));
    final tile = Vector2.all(kTileSize);
    world.add(GroundLayer(atlas, _view.layout));
    for (final cell in _view.layout.treeCells) {
      world.add(
        KeyedSprite(
          atlas: atlas,
          assetKey: const AssetKey('town', 'tree'),
          label: 'Tree',
          position: cellPosition(cell),
          size: tile,
        ),
      );
    }
    world.add(
      KeyedSprite(
        atlas: atlas,
        assetKey: const AssetKey('town', 'gate', 'dungeon'),
        label: 'Gate',
        position: cellPosition(_view.layout.gate),
        size: tile,
        priority: 2,
      ),
    );
    if (ambientLife) {
      world.add(
        Villager(
          atlas: atlas,
          position: cellPosition(const TownCell(1, 10)),
          villagerKey: const AssetKey('npc', 'villager', 'a'),
          wanderTiles: 9,
        ),
      );
      world.add(
        Villager(
          atlas: atlas,
          position: cellPosition(const TownCell(16, 10)),
          villagerKey: const AssetKey('npc', 'villager', 'b'),
          wanderTiles: 8,
        ),
      );
    }
    _addPlotsAndHouses();
    _syncCamera();
  }

  /// Replaces the plots and houses with [view]'s.
  Future<void> updateView(TownView view) async {
    _view = view;
    await atlas.preload(keysFor(view));
    for (final component in _plotsAndHouses) {
      component.removeFromParent();
    }
    _plotsAndHouses.clear();
    _addPlotsAndHouses();
  }

  void _addPlotsAndHouses() {
    _plotsAndHouses
      ..addAll([for (final plot in _view.plots) PlotComponent(atlas, plot)])
      ..addAll([
        for (final resident in _view.residents) HouseComponent(atlas, resident),
      ]);
    unawaited(world.addAll(_plotsAndHouses));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncCamera();
  }

  /// Rounds a world coordinate to a whole screen pixel at the current zoom,
  /// so tiles never straddle pixels (no seams or shimmer while panning).
  double _snapToScreenPixel(double worldCoordinate) {
    final zoom = cameraControls.zoom;
    return (worldCoordinate * zoom).roundToDouble() / zoom;
  }

  void _syncCamera() {
    camera.viewfinder
      ..zoom = cameraControls.zoom.toDouble()
      ..position = Vector2(
        _snapToScreenPixel(cameraControls.centerX),
        _snapToScreenPixel(cameraControls.centerY),
      );
  }
}
