import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/assets/pack_sprite.dart';
import 'package:lootlog/game/assets/sprite_region.dart';
import 'package:lootlog/game/game_sprite.dart';
import 'package:lootlog/game/skin_prefs.dart';

const bedKey = AssetKey('furniture', 'bed');

Widget host(AdventureTier tier, AssetRegistry registry) => MaterialApp(
      home: GameSpriteScope(
        tier: tier,
        registry: registry,
        child: const Center(child: PackSprite(assetKey: bedKey, label: 'Bed')),
      ),
    );

void main() {
  const withRegion = AssetRegistry({}, {
    'furniture.bed.default.idle':
        SpriteRegion(sheetPath: 'packs/roguelike_indoors/roguelikeIndoor_transparent.png', column: 0, row: 0),
  });

  testWidgets('pixel tier with a region paints the region at the scale', (tester) async {
    await tester.pumpWidget(host(AdventureTier.pixel, withRegion));
    final box = tester.getSize(find.byType(PackSprite));
    expect(box, const Size(32, 32));
    expect(find.byKey(const ValueKey('pack-sprite-region')), findsOneWidget);
  });

  testWidgets('text tier shows the text card even when art exists', (tester) async {
    await tester.pumpWidget(host(AdventureTier.text, withRegion));
    expect(find.byKey(const ValueKey('pack-sprite-text')), findsOneWidget);
  });

  testWidgets('no art shows the text card', (tester) async {
    await tester.pumpWidget(host(AdventureTier.pixel, AssetRegistry.empty));
    expect(find.byKey(const ValueKey('pack-sprite-text')), findsOneWidget);
  });
}
