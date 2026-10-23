import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';

const sampleJson = {
  'starterSet': ['bed_simple', 'rug_round'],
  'items': [
    {'id': 'bed_simple', 'name': 'Simple bed', 'kind': 'furniture', 'rarity': 'common', 'price': 12, 'asset': 'furniture.bed.default.idle', 'footprint': [1, 2]},
    {'id': 'rug_round', 'name': 'Round rug', 'kind': 'furniture', 'rarity': 'common', 'price': 8, 'asset': 'furniture.rug.default.idle'},
    {'id': 'crown_lamp', 'name': 'Crown lamp', 'kind': 'furniture', 'rarity': 'rare', 'asset': 'furniture.lamp.crown.idle'},
    {'id': 'knight_outfit', 'name': 'Knight', 'kind': 'outfit', 'rarity': 'uncommon', 'price': 40, 'asset': 'hero.body.knight.idle'},
    {'id': 'flame_badge', 'name': 'Week of flame', 'kind': 'title', 'rarity': 'rare', 'asset': 'title.week_of_flame.default.idle', 'exclusive': true},
    {'id': 'lamp_post', 'name': 'Lamp post', 'kind': 'townDecor', 'rarity': 'common', 'price': 15, 'asset': 'town_decor.lamp_post.default.idle'},
  ],
};

void main() {
  final catalog = DecorCatalog.fromJson(sampleJson);

  test('parses items, footprints and the starter set', () {
    expect(catalog.itemFor('bed_simple')!.footprintRows, 2);
    expect(catalog.itemFor('bed_simple')!.priceGems, 12);
    expect(catalog.starterSet.map((item) => item.id), ['bed_simple', 'rug_round']);
  });

  test('the shop never sells rares, exclusives or unpriced items', () {
    expect(catalog.shopPool.map((item) => item.id), ['bed_simple', 'rug_round', 'knight_outfit', 'lamp_post']);
  });

  test('chest pools hold non-exclusive items of that rarity', () {
    expect(catalog.chestPool(DecorRarity.rare).map((item) => item.id), ['crown_lamp']);
    expect(catalog.chestPool(DecorRarity.common).map((item) => item.id), ['bed_simple', 'rug_round', 'lamp_post']);
  });

  test('where each kind can go', () {
    expect(catalog.itemFor('bed_simple')!.placeableInRoom, isTrue);
    expect(catalog.itemFor('lamp_post')!.placeableInTown, isTrue);
    expect(catalog.itemFor('lamp_post')!.placeableInRoom, isFalse);
    expect(catalog.itemFor('knight_outfit')!.equippable, isTrue);
    expect(catalog.itemFor('flame_badge')!.equippable, isTrue);
  });

  test('trophies and statues are synthesized from the quest id', () {
    final trophy = catalog.itemFor(trophyItemId('canoe'))!;
    expect(trophy.kind, DecorKind.trophy);
    expect(trophy.placeableInRoom, isTrue);
    expect(questIdOfTrophy(trophy.id), 'canoe');
    final statue = catalog.itemFor(statueItemId('house'))!;
    expect(statue.kind, DecorKind.statue);
    expect(statue.placeableInTown, isTrue);
  });

  test('unknown ids and malformed entries are skipped', () {
    final partial = DecorCatalog.fromJson({
      'items': [
        {'id': 'ok', 'name': 'Ok', 'kind': 'furniture', 'rarity': 'common', 'price': 5, 'asset': 'furniture.plant.default.idle'},
        {'id': 'bad_kind', 'name': 'Bad', 'kind': 'spaceship', 'rarity': 'common', 'asset': 'furniture.plant.default.idle'},
        {'id': 'bad_asset', 'name': 'Bad', 'kind': 'furniture', 'rarity': 'common', 'asset': 'not a key'},
      ],
    });
    expect(partial.itemFor('ok'), isNotNull);
    expect(partial.itemFor('bad_kind'), isNull);
    expect(partial.itemFor('bad_asset'), isNull);
    expect(partial.itemFor('missing'), isNull);
  });
}
