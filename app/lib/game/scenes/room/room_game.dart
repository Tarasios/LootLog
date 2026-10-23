/// A person's room: its read model ([RoomView]) and its Flame scene.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../../assets/asset_key.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/decor/decor_state.dart';
import '../../domain/decor/room_grid.dart';
import '../../domain/game_state.dart';
import '../camera_controls.dart';
import '../pack_atlas.dart';
import 'room_components.dart';

/// One placed item with the cells it covers.
class RoomItemView {
  const RoomItemView({
    required this.placement,
    required this.item,
    required this.cells,
    this.pictureSha256,
  });

  final Placement placement;
  final DecorItem item;
  final Set<(int, int)> cells;

  /// The picture of the goal this trophy celebrates, when it has one.
  final String? pictureSha256;
}

/// Everything the room scene and screen need to show one person's room.
class RoomView {
  const RoomView({
    required this.personId,
    required this.ownerName,
    required this.items,
    required this.characterKey,
    required this.editable,
    this.titleName,
  });

  final String personId;
  final String ownerName;
  final List<RoomItemView> items;
  final AssetKey characterKey;
  final bool editable;
  final String? titleName;

  static const AssetKey defaultCharacter = AssetKey('hero', 'body');

  static RoomView from(
    GameState game,
    DecorCatalog catalog, {
    required String personId,
    required String ownerName,
    required String viewerId,
    Map<String, String> goalPictures = const {},
  }) {
    final items = <RoomItemView>[
      for (final placement in game.decor.placementsInRoom(personId))
        if (catalog.itemFor(placement.itemId) case final DecorItem item)
          RoomItemView(
            placement: placement,
            item: item,
            cells: RoomGrid.cellsOf(
              item,
              placement.column,
              placement.row,
              placement.rotation,
            ),
            pictureSha256: _goalPictureOf(item, goalPictures),
          ),
    ];
    final outfitId = game.decor.outfitOf(personId);
    final titleId = game.decor.titleOf(personId);
    return RoomView(
      personId: personId,
      ownerName: ownerName,
      items: List.unmodifiable(items),
      characterKey:
          (outfitId == null ? null : catalog.itemFor(outfitId)?.assetKey) ??
          defaultCharacter,
      editable: viewerId == personId,
      titleName: titleId == null ? null : catalog.itemFor(titleId)?.name,
    );
  }

  /// [goalPictures] (questId → sha256) is the picture of a custom trophy's
  /// goal; plain trophies and other furniture have none.
  static String? _goalPictureOf(DecorItem item, Map<String, String> goalPictures) {
    final questId = questIdOfTrophy(item.id);
    return questId == null ? null : goalPictures[questId];
  }

  /// The placed item covering ([column], [row]), if any.
  RoomItemView? itemAt(int column, int row) {
    for (final itemView in items) {
      if (itemView.cells.contains((column, row))) return itemView;
    }
    return null;
  }
}

class RoomGame extends FlameGame {
  RoomGame({
    required this.atlas,
    required this.view,
    this.pictures = const {},
  }) : cameraControls = CameraControls(
        worldWidth: kRoomTileColumns * kTileSize,
        worldHeight: kRoomTileRows * kTileSize,
      );

  final PackAtlas atlas;
  final CameraControls cameraControls;

  /// The room currently drawn.
  RoomView view;

  /// Decoded goal pictures by sha256; a trophy whose picture is absent is
  /// drawn on its stand.
  Map<String, ui.Image> pictures;
  final List<Component> _contents = [];

  Iterable<AssetKey> _keys(RoomView view) => [
    const AssetKey('room', 'floor', 'wood'),
    const AssetKey('room', 'wall'),
    view.characterKey,
    for (final itemView in view.items) itemView.item.assetKey,
  ];

  @override
  Future<void> onLoad() async {
    await atlas.preload(_keys(view));
    world.add(RoomFloor(atlas));
    _addContents();
    _syncCamera();
  }

  /// Swaps the placed items and character for those of [newView], with the
  /// goal [newPictures] when given.
  Future<void> updateView(RoomView newView, {Map<String, ui.Image>? newPictures}) async {
    view = newView;
    if (newPictures != null) pictures = newPictures;
    await atlas.preload(_keys(newView));
    for (final component in _contents) {
      component.removeFromParent();
    }
    _contents.clear();
    _addContents();
  }

  void _addContents() {
    _contents
      ..addAll([
        for (final itemView in view.items) _componentFor(itemView),
      ])
      ..add(
        RoomCharacter(
          atlas: atlas,
          characterKey: view.characterKey,
          ownerName: view.ownerName,
        ),
      );
    unawaited(world.addAll(_contents));
  }

  PositionComponent _componentFor(RoomItemView itemView) {
    final picture = pictures[itemView.pictureSha256];
    return picture == null
        ? RoomItemComponent(atlas: atlas, itemView: itemView)
        : RoomTrophyPicture(picture: picture, itemView: itemView);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncCamera();
  }

  void _syncCamera() {
    camera.viewfinder
      ..zoom = cameraControls.zoom.toDouble()
      ..position = Vector2(cameraControls.centerX, cameraControls.centerY);
  }
}
