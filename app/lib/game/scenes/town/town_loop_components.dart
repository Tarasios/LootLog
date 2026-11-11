/// The town loop in the scene: the day's visitor standing by the square,
/// and on a festival weekend bunting strung across the square with villagers
/// gathered around it. [TownLoopLayer] holds them and swaps them as the day
/// changes. Drawing only: the scene view turns a tap on the visitor's cell
/// into the visitor's dialog.
library;

import 'dart:ui' show Canvas;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show Offset;

import '../../assets/asset_key.dart';
import '../../domain/game_values.dart';
import '../../domain/town/town_layout.dart';
import '../camera_controls.dart';
import '../pack_atlas.dart';
import 'pennant_painter.dart';
import 'town_components.dart';

/// Where the day's visitor stands: on the square's east side, in view at a
/// phone's default zoom (the camera starts centred on the square).
const TownCell kVisitorCell = TownCell(15, 9);

/// Where villagers gather on a festival day, the first two for a market
/// day, one more per bigger festival.
const List<TownCell> _kGatheringCells = [
  TownCell(11, 10),
  TownCell(16, 10),
  TownCell(13, 12),
  TownCell(14, 7),
];

/// What the loop puts in the scene: the visitor's art and name (none when no
/// visitor waits) and today's festival (none on a weekday).
class TownLoopScene {
  const TownLoopScene({this.visitorKey, this.visitorLabel = '', this.festival});

  static const TownLoopScene none = TownLoopScene();

  final AssetKey? visitorKey;
  final String visitorLabel;
  final FestivalTier? festival;

  @override
  bool operator ==(Object other) =>
      other is TownLoopScene &&
      other.visitorKey == visitorKey &&
      other.visitorLabel == visitorLabel &&
      other.festival == festival;

  @override
  int get hashCode => Object.hash(visitorKey, visitorLabel, festival);
}

/// Holds the loop's components and replaces them on [show].
class TownLoopLayer extends Component {
  TownLoopLayer(this.atlas);

  final PackAtlas atlas;
  TownLoopScene _scene = TownLoopScene.none;

  /// Draws [scene], replacing what was there.
  Future<void> show(TownLoopScene scene) async {
    _scene = scene;
    final keys = [
      ?scene.visitorKey,
      const AssetKey('npc', 'villager', 'a'),
      const AssetKey('npc', 'villager', 'b'),
    ];
    await atlas.preload(keys);
    // A newer scene arrived while the art loaded: it draws instead.
    if (!identical(_scene, scene)) return;
    removeAll(children.toList());
    final visitorKey = scene.visitorKey;
    if (visitorKey != null) {
      add(
        KeyedSprite(
          atlas: atlas,
          assetKey: visitorKey,
          label: scene.visitorLabel,
          position: cellPosition(kVisitorCell),
          size: Vector2.all(kTileSize),
          priority: 3,
        ),
      );
    }
    final festival = scene.festival;
    if (festival != null) {
      add(FestivalBunting(strings: 2 + festival.index));
      for (final (index, cell) in _kGatheringCells.take(2 + festival.index).indexed) {
        add(
          KeyedSprite(
            atlas: atlas,
            assetKey: AssetKey('npc', 'villager', index.isEven ? 'a' : 'b'),
            label: 'Villager',
            position: cellPosition(cell),
            size: Vector2.all(kTileSize),
            priority: 3,
          ),
        );
      }
    }
  }
}

/// Strings of flags across the square: its top and bottom edges, then its
/// diagonals for a bigger festival.
class FestivalBunting extends PositionComponent {
  FestivalBunting({required this.strings}) : super(priority: 5);

  /// How many strings hang (2 to 4).
  final int strings;

  static const double _left = 12 * kTileSize;
  static const double _right = 16 * kTileSize;
  static const double _top = 8 * kTileSize + 2;
  static const double _bottom = 12 * kTileSize - 6;

  static const List<(Offset, Offset)> _lines = [
    (Offset(_left, _top), Offset(_right, _top)),
    (Offset(_left, _bottom), Offset(_right, _bottom)),
    (Offset(_left, _top), Offset(_right, _bottom)),
    (Offset(_right, _top), Offset(_left, _bottom)),
  ];

  @override
  void render(Canvas canvas) {
    for (final (index, (start, end)) in _lines.take(strings).indexed) {
      paintPennants(canvas, start, end, sag: 4, colourOffset: index * 2);
    }
  }
}
