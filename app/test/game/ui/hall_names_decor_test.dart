import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/ui/hall_names.dart';

DecorItem item(String name, DecorKind kind) => DecorItem(
      id: 'id',
      name: name,
      kind: kind,
      rarity: DecorRarity.common,
      assetKey: const AssetKey('furniture', 'rug'),
    );

void main() {
  test('a furniture drop names the item and says it is for the home', () {
    expect(HallNames.decorFound(item('Round rug', DecorKind.furniture)),
        '…and a Round rug for your home!');
  });

  test('a vowel gets "an"; town decor is for the town', () {
    expect(HallNames.decorFound(item('Old well', DecorKind.townDecor)),
        '…and an Old well for the town!');
  });

  test('a title is announced as a title', () {
    expect(HallNames.decorFound(item('Steady Hand', DecorKind.title)),
        '…and the title Steady Hand!');
  });
}
