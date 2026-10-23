/// The town scene: ground, trees, the gate, plots, houses and (optionally)
/// strolling villagers. Rebuilt from a [TownView]; it holds no game rules.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../../assets/asset_catalog.dart';
import '../../assets/asset_key.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/town/town_layout.dart';
import '../../domain/town/town_view.dart';
import '../camera_controls.dart';
import '../pack_atlas.dart';
import 'town_components.dart';

/// A dependent or pet who strolls the town, by name.
typedef TownsfolkEntry = ({String name, bool isPet});

class TownGame extends FlameGame {
  TownGame({
    required this.atlas,
    required TownView view,
    this.ambientLife = true,
    this.townsfolk = const [],
    this.catalog = DecorCatalog.empty,
    this.pictures = const {},
  }) : _view = view,
       cameraControls = CameraControls(
         worldWidth: view.layout.columns * kTileSize,
         worldHeight: view.layout.rows * kTileSize,
       );

  final PackAtlas atlas;
  final bool ambientLife;

  /// Names and art of the placed decorations; a placement the catalogue does
  /// not know is not drawn.
  DecorCatalog catalog;

  /// Decoded goal pictures by sha256; a statue whose picture is absent is
  /// drawn as the plain statue.
  Map<String, ui.Image> pictures;

  final List<Villager> _townsfolkVillagers = [];

  /// Dependents and pets who stroll beside the default villagers (only with
  /// [ambientLife]).
  List<TownsfolkEntry> townsfolk;
  final CameraControls cameraControls;
  TownView _view;
  final List<Component> _plotsAndHouses = [];
  final List<Component> _decorations = [];
  GateGlow? _gateGlow;

  /// Every key the scene can draw, for preloading.
  static Iterable<AssetKey> keysFor(TownView view, [DecorCatalog catalog = DecorCatalog.empty]) sync* {
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
      AssetKey('npc', 'pet', 'default'),
    ];
    for (final plot in view.plots) {
      final buildingType = plot.buildingType;
      if (buildingType != null) {
        yield GameAssetKeys.building(buildingType, plot.tier);
      }
    }
    for (final placement in view.townPlacements) {
      final item = catalog.itemFor(placement.itemId);
      if (item != null) yield item.assetKey;
    }
  }

  @override
  Future<void> onLoad() async {
    await atlas.preload(keysFor(_view, catalog));
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
      await _addTownsfolk();
    }
    _addPlotsAndHouses();
    _addDecorations();
    _syncGateGlow();
    _syncCamera();
  }

  /// Lights the gate while the dungeon is open, and puts the light out when
  /// it closes.
  void _syncGateGlow() {
    if (_view.dungeonOpen && _gateGlow == null) {
      final glow = GateGlow(
        position: cellPosition(_view.layout.gate) + Vector2.all(kTileSize / 2),
      );
      _gateGlow = glow;
      unawaited(world.addAll([glow]));
    } else if (!_view.dungeonOpen && _gateGlow != null) {
      _gateGlow!.removeFromParent();
      _gateGlow = null;
    }
  }

  /// One villager per dependent or pet, two tiles apart along the main path
  /// and wrapping back to the start when the path runs out.
  Future<void> _addTownsfolk() async {
    const pathRow = 10;
    const firstColumn = 3;
    const spacingTiles = 2;
    const wanderTiles = 2;
    final stepsOnPath =
        (_view.layout.columns - firstColumn - wanderTiles) ~/ spacingTiles;
    for (var index = 0; index < townsfolk.length; index++) {
      final entry = townsfolk[index];
      final column = firstColumn + (index % stepsOnPath) * spacingTiles;
      final villager = Villager(
        atlas: atlas,
        position: cellPosition(TownCell(column, pathRow)),
        villagerKey: entry.isPet
            ? const AssetKey('npc', 'pet', 'default')
            : const AssetKey('npc', 'villager', 'a'),
        wanderTiles: wanderTiles,
        label: entry.name,
      );
      _townsfolkVillagers.add(villager);
      await world.add(villager);
    }
  }

  /// Replaces the strolling dependents and pets with [townsfolk]; the default
  /// villagers stay. Before the scene has loaded, only the list is stored (the
  /// load draws it).
  Future<void> updateTownsfolk(List<TownsfolkEntry> townsfolk) async {
    this.townsfolk = townsfolk;
    if (!ambientLife || !isLoaded) return;
    for (final villager in _townsfolkVillagers) {
      villager.removeFromParent();
    }
    _townsfolkVillagers.clear();
    await _addTownsfolk();
  }

  /// Replaces the plots, houses and decorations with [view]'s (and the goal
  /// pictures and catalogue with [newPictures] and [newCatalog], when given).
  Future<void> updateView(
    TownView view, {
    Map<String, ui.Image>? newPictures,
    DecorCatalog? newCatalog,
  }) async {
    _view = view;
    if (newPictures != null) pictures = newPictures;
    if (newCatalog != null) catalog = newCatalog;
    await atlas.preload(keysFor(view, catalog));
    for (final component in [..._plotsAndHouses, ..._decorations]) {
      component.removeFromParent();
    }
    _plotsAndHouses.clear();
    _decorations.clear();
    _addPlotsAndHouses();
    _addDecorations();
    _syncGateGlow();
  }

  void _addDecorations() {
    for (final placement in _view.townPlacements) {
      final item = catalog.itemFor(placement.itemId);
      if (item == null) continue;
      final cell = TownCell(placement.column, placement.row);
      final questId = questIdOfTrophy(item.id);
      final picture = questId == null ? null : pictures[_view.goalPictures[questId]];
      _decorations.add(
        picture == null
            ? TownDecorComponent(atlas: atlas, assetKey: item.assetKey, label: item.name, cell: cell)
            : TownStatuePicture(picture: picture, cell: cell),
      );
    }
    unawaited(world.addAll(_decorations));
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
