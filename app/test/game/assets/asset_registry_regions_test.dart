import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/art_source.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/assets/sprite_region.dart';

const grassRegion = SpriteRegion(sheetPath: 'packs/tiny_town/tilemap_packed.png', column: 0, row: 0);

void main() {
  test('a key with only a region resolves to that region', () {
    const registry = AssetRegistry({}, {'town.ground.grass.idle': grassRegion});
    final art = registry.artFor(const AssetKey('town', 'ground', 'grass'));
    expect(art, isA<ArtRegion>());
    expect((art! as ArtRegion).region, grassRegion);
  });

  test('an artist PNG for the same key overrides the pack region', () {
    const registry = AssetRegistry(
      {'town.ground.grass.idle': 'town.ground.grass.idle_1f.png'},
      {'town.ground.grass.idle': grassRegion},
    );
    final art = registry.artFor(const AssetKey('town', 'ground', 'grass'));
    expect((art! as ArtFile).fileName, 'town.ground.grass.idle_1f.png');
  });

  test('the fallback chain reaches a region on the idle state', () {
    const registry = AssetRegistry({}, {'town.ground.grass.idle': grassRegion});
    expect(registry.hasArt(const AssetKey('town', 'ground', 'grass', 'wet')), isTrue);
  });

  test('merge keeps files and regions from both sides', () {
    const files = AssetRegistry({'chest.gold.closed.idle': 'gold.png'});
    const regions = AssetRegistry({}, {'town.ground.grass.idle': grassRegion});
    final merged = files.merge(regions);
    expect(merged.hasArt(const AssetKey('chest', 'gold', 'closed')), isTrue);
    expect(merged.hasArt(const AssetKey('town', 'ground', 'grass')), isTrue);
  });

  test('fileFor still returns only files (GameSprite strips)', () {
    const registry = AssetRegistry({}, {'town.ground.grass.idle': grassRegion});
    expect(registry.fileFor(const AssetKey('town', 'ground', 'grass')), isNull);
  });
}
