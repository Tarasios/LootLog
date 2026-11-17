/// The stage-3 districts as scenes: each quarter draws its plots and its
/// own scenery, a civic building is named under its plot, a farm resting
/// for want of guards wears its sleep bubble (and no ready marker), and
/// Castle Hill draws the Castle at its stage with scaffolding while a stage
/// rises.
library;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_catalog.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';
import 'package:lootlog/game/domain/town/town_view.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/scenes/town/castle_component.dart';
import 'package:lootlog/game/scenes/town/town_components.dart';
import 'package:lootlog/game/scenes/town/town_game.dart';

import '../domain/game_fixtures.dart';
import '../domain/town/growth_fixtures.dart';

const _adults = [TownAdult(memberId: robin, name: 'Robin', inAdventure: true)];

TownGame _sceneOf(List<GameEvent> events, String districtId, {DateTime? now}) => TownGame(
      atlas: PackAtlas(AssetRegistry.empty, Images(prefix: 'assets/game/')),
      view: TownView.from(projectGameState(events), robin, _adults, now ?? at(5), districtId: districtId),
      ambientLife: false,
    );

List<String> _labels(TownGame game) =>
    game.world.children.whereType<KeyedSprite>().map((sprite) => sprite.label).toList();

void main() {
  for (final (districtId, scenery) in [
    (kGuardPostDistrictId, 'Tower'),
    (kResidentialDistrictId, 'Garden'),
    (kParkDistrictId, 'Bench'),
    (kMarketRowDistrictId, 'Stall'),
  ]) {
    testWithGame<TownGame>('the $districtId draws its plots and its own scenery',
        () => _sceneOf([...tierWith(TownTier.town), districtPurchased('buy', districtId, when: at(0))], districtId),
        (game) async {
      await game.ready();
      expect(game.world.children.whereType<PlotComponent>(), hasLength(districtById(districtId)!.plotCount));
      expect(game.world.children.whereType<HouseComponent>(), isEmpty);
      expect(game.world.children.whereType<CastleComponent>(), isEmpty);
      expect(_labels(game), contains(scenery));
    });
  }

  testWithGame<TownGame>(
      'a civic building is named under its plot',
      () => _sceneOf([
            ...tierWith(TownTier.village),
            districtPurchased('buy', kGuardPostDistrictId, when: at(0)),
            civicBuilt('tower', kGuardPostDistrictId, 0, CivicBuildingType.watchtower, when: at(1)),
          ], kGuardPostDistrictId), (game) async {
    await game.ready();
    final plot = game.world.children.whereType<PlotComponent>().first;
    expect(plot.children.whereType<TextComponent>().map((label) => label.text), ['Watchtower']);
  });

  testWithGame<TownGame>(
      'a farm resting for want of guards wears a sleep bubble, not a ready marker',
      () => _sceneOf([
            ...tierWith(TownTier.town),
            districtPurchased('farmland', kFarmlandDistrictId, when: at(0)),
            farmBuilt('edge', 6, FarmBuildingType.farm, when: at(1)),
          ], kFarmlandDistrictId, now: at(600)), (game) async {
    await game.ready();
    final plot = game.world.children.whereType<PlotComponent>().elementAt(6);
    final signs = plot.children.whereType<KeyedSprite>().where((sprite) => sprite.assetKey == GameAssetKeys.farmResting);
    expect(signs, hasLength(1));
    expect(plot.children.whereType<ReadyBubble>(), isEmpty);
  });

  testWithGame<TownGame>('Castle Hill shows the surveyed hilltop before the first stage',
      () => _sceneOf(tierWith(TownTier.city), kCastleHillDistrictId), (game) async {
    await game.ready();
    final castle = game.world.children.whereType<CastleComponent>().single;
    expect(castle.stagesDone, 0);
    expect(castle.building, isFalse);
    expect(castle.position, cellPosition(TownLayout.castleHill.castleOrigin!));
    expect(_labels(game), contains('Hill'));
    expect(game.world.children.whereType<PlotComponent>(), isEmpty);
  });

  testWithGame<TownGame>(
      'a Castle stage under way wears scaffolding',
      () => _sceneOf([...tierWith(TownTier.city), castleStageStarted('foundation', 1, when: at(0))],
          kCastleHillDistrictId, now: onDay(1)), (game) async {
    await game.ready();
    final castle = game.world.children.whereType<CastleComponent>().single;
    expect(castle.building, isTrue);
    final sprites = castle.children.whereType<KeyedSprite>().map((sprite) => sprite.assetKey).toList();
    expect(sprites, [GameAssetKeys.castleStage(0), GameAssetKeys.castleScaffold]);
  });
}
