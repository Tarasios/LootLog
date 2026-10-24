import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/art_source.dart';
import 'package:lootlog/game/assets/asset_catalog.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/game_sprite.dart';
import 'package:lootlog/game/skin_prefs.dart';

class _FixedTier extends AdventureTierNotifier {
  _FixedTier(this.tier);
  final AdventureTier tier;

  @override
  AdventureTier build() => tier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadGameAssetRegistry includes the bundled dungeon art', () async {
    final registry = await loadGameAssetRegistry();
    expect(registry.fileFor(GameAssetKeys.dungeonMonster),
        'monster_idle_4f.png');
  });

  test('loadGameAssetRegistry loads the regions of every bundled pack', () async {
    final registry = await loadGameAssetRegistry();
    final grass = registry.artFor(const AssetKey('town', 'ground', 'grass'));
    expect(grass, isA<ArtRegion>());
    expect((grass! as ArtRegion).region.sheetPath,
        'packs/tiny_town/tilemap_packed.png');
  });

  testWidgets('AdventureSpriteScope passes the device tier and registry down',
      (tester) async {
    const registry = AssetRegistry({'chest.wood.closed.idle': 'w_1f.png'});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        adventureTierProvider.overrideWith(() => _FixedTier(AdventureTier.text)),
        gameAssetRegistryProvider.overrideWith((ref) async => registry),
      ],
      child: MaterialApp(
        home: AdventureSpriteScope(
          child: Builder(builder: (context) {
            final scope = GameSpriteScope.maybeOf(context)!;
            return Text('${scope.tier.name} '
                '${scope.registry.fileFor(GameAssetKeys.chest(ChestType.wood))}');
          }),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('text w_1f.png'), findsOneWidget);
  });
}
