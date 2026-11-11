import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';
import 'package:lootlog/game/domain/town/town_view.dart';
import 'package:lootlog/game/scenes/camera_controls.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/scenes/town/town_components.dart';
import 'package:lootlog/game/scenes/town/town_game.dart';

import '../domain/game_fixtures.dart';
import '../domain/town/growth_fixtures.dart';

const _adults = [TownAdult(memberId: robin, name: 'Robin', inAdventure: true)];

TownView _farmlandView() {
  final game = projectGameState([
    ...hamletWith(),
    districtPurchased('buy', kFarmlandDistrictId, when: at(0)),
    farmBuilt('orchard', 0, FarmBuildingType.orchard, when: at(1)),
  ]);
  return TownView.from(game, robin, _adults, at(5), districtId: kFarmlandDistrictId);
}

TownGame _buildFarmland() => TownGame(
  atlas: PackAtlas(AssetRegistry.empty, Images(prefix: 'assets/game/')),
  view: _farmlandView(),
  ambientLife: false,
);

Iterable<String> _labels(Component component) =>
    component.children.whereType<TextComponent>().map((label) => label.text);

void main() {
  testWithGame<TownGame>('the farmland draws its six fields, its landmarks and no gate or houses', _buildFarmland, (
    game,
  ) async {
    await game.ready();
    final plots = game.world.children.whereType<PlotComponent>().toList();
    expect(plots, hasLength(6));
    expect(game.world.children.whereType<HouseComponent>(), isEmpty);
    final labels = game.world.children.whereType<KeyedSprite>().map((sprite) => sprite.label).toList();
    expect(labels, isNot(contains('Gate')));
    expect(labels, contains('Barn'));
    expect(labels.where((label) => label == 'Hedge').length, TownLayout.farmland.landmarks.where((l) => l.label == 'Hedge').length);
  });

  testWithGame<TownGame>('a farm building is named under its field; an empty field invites a build', _buildFarmland, (
    game,
  ) async {
    await game.ready();
    final plots = game.world.children.whereType<PlotComponent>().toList();
    expect(_labels(plots[0]), ['Orchard']);
    expect(_labels(plots[1]), ['Build']);
  });

  testWithGame<TownGame>('the camera fits the narrower farmland map', _buildFarmland, (game) async {
    await game.ready();
    expect(game.cameraControls.worldWidth, TownLayout.farmland.columns * kTileSize);
  });

  group('tall art', () {
    test('art taller than wide rises from the plot\'s foot into the row above', () {
      final bounds = plotArtBounds(artWidth: 32, artHeight: 48, footprint: 32);
      expect(bounds.top, -16);
      expect(bounds.height, 48);
      expect(bounds.width, 32);
    });

    test('square art fills the plot', () {
      final bounds = plotArtBounds(artWidth: 32, artHeight: 32, footprint: 32);
      expect(bounds.top, 0);
      expect(bounds.height, 32);
    });
  });
}
