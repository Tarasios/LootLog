/// The Castle on Castle Hill as a scene component: the Castle at its
/// stage (the surveyed hilltop before the first) and the builders'
/// scaffolding while the next stage rises. It only draws; a tap on its
/// cells is resolved by the scene view through `TownView.targetAt`.
library;

import 'package:flame/components.dart';

import '../../assets/asset_catalog.dart';
import '../../domain/town/town_layout.dart';
import '../camera_controls.dart';
import '../pack_atlas.dart';
import 'town_components.dart';

/// The Castle on Castle Hill at its stage (the surveyed hilltop before the
/// first), with the builders' scaffolding while the next stage rises.
class CastleComponent extends PositionComponent {
  CastleComponent(this.atlas, {required TownCell origin, required int columns, required int rows, required this.stagesDone, required this.building})
    : super(
        position: cellPosition(origin),
        size: Vector2(columns * kTileSize, rows * kTileSize),
        priority: 2,
      );

  final PackAtlas atlas;
  final int stagesDone;
  final bool building;

  @override
  Future<void> onLoad() async {
    add(
      KeyedSprite(
        atlas: atlas,
        assetKey: GameAssetKeys.castleStage(stagesDone),
        label: stagesDone == 0 ? 'Castle site' : 'Castle',
        position: Vector2.zero(),
        size: size,
      ),
    );
    if (building) {
      add(
        KeyedSprite(
          atlas: atlas,
          assetKey: GameAssetKeys.castleScaffold,
          label: 'Building',
          position: Vector2.zero(),
          size: size,
          priority: 3,
        ),
      );
    }
  }
}
