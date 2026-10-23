import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/painting.dart' show FilterQuality;
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/assets/sprite_region.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/scenes/town/town_components.dart';
import 'package:lootlog/game/scenes/town/town_game.dart';

import 'town_game_test.dart' show sampleView;

const _grass = AssetKey('town', 'ground', 'grass');

/// Every town ground key points at an image that does not exist.
AssetRegistry registryWithMissingSheet() => AssetRegistry({}, {
  for (final key in TownGame.keysFor(sampleView()))
    key.value: const SpriteRegion(
      sheetPath: 'packs/missing/not_there.png',
      column: 0,
      row: 0,
    ),
});

PackAtlas atlasFor(AssetRegistry registry) =>
    PackAtlas(registry, Images(prefix: 'assets/game/'));

void main() {
  testWidgets('a missing sheet preloads quietly and yields no sprite', (
    tester,
  ) async {
    final atlas = atlasFor(registryWithMissingSheet());
    await atlas.preload([_grass]);
    expect(atlas.spriteFor(_grass), isNull);
    expect(atlas.images.containsKey('packs/missing/not_there.png'), isFalse);
  });

  testWidgets('a real bundled sheet loads into pixel-crisp, cached sprites', (
    tester,
  ) async {
    final registry = AssetRegistry({}, {
      _grass.value: const SpriteRegion(
        sheetPath: 'packs/tiny_town/tilemap_packed.png',
        column: 0,
        row: 0,
      ),
    });
    final atlas = atlasFor(registry);
    await tester.runAsync(() => atlas.preload([_grass]));
    final sprite = atlas.spriteFor(_grass);
    expect(sprite, isNotNull);
    expect(sprite!.paint.filterQuality, FilterQuality.none);
    expect(identical(atlas.spriteFor(_grass), sprite), isTrue);

    final component = KeyedSprite(
      atlas: atlas,
      assetKey: _grass,
      label: 'Grass',
      position: Vector2.zero(),
      size: Vector2.all(16),
    );
    final game = FlameGame();
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();
    game.world.add(component);
    await tester.pump();
    await tester.pump();
    final drawn = component.children.whereType<SpriteComponent>().single;
    expect(drawn.paint.filterQuality, FilterQuality.none);
  });

  testWithGame<TownGame>(
    'a scene whose art is missing still loads with labelled placeholders',
    () => TownGame(
      atlas: atlasFor(registryWithMissingSheet()),
      view: sampleView(),
      ambientLife: false,
    ),
    (game) async {
      await game.ready();
      expect(game.world.children.whereType<PlotComponent>(), hasLength(11));
      expect(game.world.children.whereType<HouseComponent>(), hasLength(2));
      final firstPlot = game.world.children.whereType<PlotComponent>().first;
      final placeholder = firstPlot.children.whereType<KeyedSprite>().first;
      expect(placeholder.hasArt, isFalse);
      expect(placeholder.children.whereType<TextComponent>(), isNotEmpty);
    },
  );
}
