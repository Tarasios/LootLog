import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_catalog.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/assets/text_sprite.dart';
import 'package:lootlog/game/domain/game_values.dart';

bool _isPrintableAscii(String s) =>
    s.codeUnits.every((c) => c >= 0x20 && c <= 0x7E);

void main() {
  test('every catalogued key has small, printable-ASCII art and a title', () {
    for (final key in GameAssetKeys.all) {
      final t = textSpriteFor(key);
      expect(t.art, isNotEmpty, reason: key.value);
      expect(t.art.length, lessThanOrEqualTo(kTextSpriteMaxLines),
          reason: key.value);
      for (final line in t.art) {
        expect(_isPrintableAscii(line), isTrue, reason: '${key.value}: $line');
        expect(line.length, lessThanOrEqualTo(kTextSpriteMaxWidth),
            reason: '${key.value}: "$line"');
      }
      expect(t.title.trim(), isNotEmpty, reason: key.value);
      expect(_isPrintableAscii(t.title), isTrue, reason: key.value);
    }
  });

  test('art lines within one sprite share a width so the block aligns', () {
    for (final key in GameAssetKeys.all) {
      final widths = textSpriteFor(key).art.map((l) => l.length).toSet();
      expect(widths, hasLength(1), reason: key.value);
    }
  });

  test('titles read as names, with the category noun where it helps', () {
    expect(textSpriteFor(GameAssetKeys.building(BuildingType.scribesDesk, 2))
        .title, "Scribe's Desk");
    expect(textSpriteFor(GameAssetKeys.chest(ChestType.gold)).title,
        'Gold Chest');
    expect(textSpriteFor(GameAssetKeys.material(MaterialKind.herbs)).title,
        'Herbs');
    expect(
        textSpriteFor(GameAssetKeys.region(ExpeditionRegion.theWilds)).title,
        'The Wilds');
    expect(textSpriteFor(GameAssetKeys.heroPortrait).title, 'Hero');
    expect(textSpriteFor(GameAssetKeys.supplyCaravan).title, 'Supply Caravan');
    expect(textSpriteFor(GameAssetKeys.gear('weapon', tier: 2)).title,
        'Weapon');
  });

  test('badges carry the variant / state that distinguishes a key', () {
    expect(textSpriteFor(GameAssetKeys.building(BuildingType.forge, 3)).badge,
        'T3');
    expect(textSpriteFor(GameAssetKeys.chest(ChestType.iron)).badge, isNull);
    expect(textSpriteFor(GameAssetKeys.chest(ChestType.iron, open: true)).badge,
        'OPEN');
    expect(textSpriteFor(GameAssetKeys.material(MaterialKind.ore)).badge,
        isNull);
    expect(
        textSpriteFor(
                GameAssetKeys.building(BuildingType.mine, 2, state: 'constructing'))
            .badge,
        'T2 CONSTRUCTING');
    expect(textSpriteFor(GameAssetKeys.dungeonMonsterEnraged).badge, 'ENRAGED');
  });

  test('open and closed chests draw differently', () {
    expect(textSpriteFor(GameAssetKeys.chest(ChestType.wood)).art,
        isNot(textSpriteFor(GameAssetKeys.chest(ChestType.wood, open: true)).art));
  });

  test('an unknown category still gets intentional generic art', () {
    final t = textSpriteFor(AssetKey.parse('banner.victory.default.idle'));
    expect(t.art, isNotEmpty);
    expect(t.title, 'Victory');
  });

  test('a label override replaces the title only', () {
    final t = textSpriteFor(GameAssetKeys.heroPortrait, label: 'Ayla');
    expect(t.title, 'Ayla');
    expect(t.art, textSpriteFor(GameAssetKeys.heroPortrait).art);
  });

  test('labelTextSprite gives a key-less sprite a generic emblem', () {
    final t = labelTextSprite('Mochi');
    expect(t.title, 'Mochi');
    expect(t.art, isNotEmpty);
    expect(t.badge, isNull);
  });
}
