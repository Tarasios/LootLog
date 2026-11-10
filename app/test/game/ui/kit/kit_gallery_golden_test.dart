/// Goldens of the whole kit under the Adventure theme, phone and desktop:
/// once with the bundled UI pack decoded (the pixel look) and once with no
/// art at all (every frame's drawn fallback). The game dialog sits inline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/art_source.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/game_sprite.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/kit/kit.dart';

/// Every frame key the kit draws.
const _kitKeys = [
  KitKeys.parchment, KitKeys.wood, KitKeys.slate, KitKeys.ornate,
  KitKeys.inset, KitKeys.ribbon, KitKeys.bannerPlain, KitKeys.roundButton,
];

/// Decodes every image [registry] holds for the kit's frames, so they paint
/// on the next frames of the test clock.
Future<void> _decodeKitArt(WidgetTester tester, AssetRegistry registry) async {
  final paths = {
    for (final key in _kitKeys)
      switch (registry.artFor(key)) {
        ArtRegion(:final region) => '${AssetRegistry.assetDir}${region.sheetPath}',
        ArtFile(:final fileName) => '${AssetRegistry.assetDir}$fileName',
        null => null,
      },
  }.nonNulls;
  await tester.runAsync(() async {
    final element = tester.element(find.byType(Scaffold));
    for (final path in paths) {
      await precacheImage(AssetImage(path), element).timeout(const Duration(seconds: 30));
    }
  });
  for (var frame = 0; frame < 3; frame++) {
    await tester.pump();
  }
}

/// The game dialog first (so the phone shows it whole), then every other kit
/// piece, flowing to fit the width.
class _KitGallery extends StatelessWidget {
  const _KitGallery();

  @override
  Widget build(BuildContext context) {
    final dialog = GameDialog(
      title: 'Treasure',
      onClose: () {},
      maxWidth: 420,
      scene: const ColoredBox(
        color: AdventureTokens.grass,
        child: Center(child: Icon(Icons.inventory_2, size: 48, color: AdventureTokens.chest)),
      ),
      body: const Text('A wood chest for your streak!'),
      actions: [
        WoodButton(label: 'Later', tone: WoodButtonTone.secondary, onPressed: () {}),
        WoodButton(label: 'Open', onPressed: () {}),
      ],
    );
    final specimens = <Widget>[
      SizedBox(width: 420, child: dialog),
      const RibbonTitle('Quests'),
      const WoodPanel(child: Text('Wood')),
      const ParchmentCard(child: Text('Card')),
      const InsetWell(child: Text('Well')),
      Wrap(spacing: 8, runSpacing: 8, children: [
        WoodButton(label: 'Log', icon: Icons.add, onPressed: () {}),
        WoodButton(label: 'Back', tone: WoodButtonTone.secondary, onPressed: () {}),
        const WoodButton(label: 'Off', onPressed: null),
      ]),
      Wrap(spacing: 12, runSpacing: 8, children: [
        HudButton(label: 'Quests', icon: Icons.flag, badge: '3', onPressed: () {}),
        HudButton(label: 'Log', icon: Icons.add_shopping_cart, large: true, onPressed: () {}),
      ]),
      const Wrap(spacing: 8, runSpacing: 8, children: [
        HudChip(icon: Icons.diamond, value: '120', color: AdventureTokens.gem),
        HudChip(icon: Icons.local_fire_department, value: '7', label: 'days', color: AdventureTokens.hpRed),
      ]),
      const SizedBox(
        width: 160,
        child: Column(children: [
          MeterBar(fraction: 0),
          SizedBox(height: 6),
          MeterBar(fraction: 0.4, color: AdventureTokens.hpGreen),
          SizedBox(height: 6),
          MeterBar(fraction: 1, color: AdventureTokens.hpBlue),
        ]),
      ),
      const Wrap(spacing: 12, children: [
        FloatingTag('Ready', icon: Icons.check),
        FloatingTag('Enraged!', urgent: true),
      ]),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Wrap(spacing: 24, runSpacing: 8, children: specimens),
    );
  }
}

void main() {
  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1280, 800)),
  ]) {
    for (final withArt in [true, false]) {
      final art = withArt ? 'pixel' : 'no_art';
      testWidgets('kit gallery $name $art', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final registry =
            withArt ? (await tester.runAsync(loadGameAssetRegistry))! : AssetRegistry.empty;
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AdventureTheme.build(),
          home: Scaffold(
            body: GameSpriteScope(
              tier: AdventureTier.pixel,
              registry: registry,
              child: const _KitGallery(),
            ),
          ),
        ));
        await _decodeKitArt(tester, registry);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/kit_gallery_${name}_$art.png'),
        );
      });
    }
  }
}
