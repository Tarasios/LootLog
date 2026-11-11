/// Goldens for a visit to a neighbour's town on a phone, drawn with the
/// bundled art packs and the pixel fonts: Sam's town with the visiting HUD,
/// and the gift dialog over it. No ambient villagers, so the frames are
/// stable.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/town_view.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/scenes/town/town_scene_view.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/hall_ledger_view.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../hall_harness.dart';
import 'town_test_overrides.dart';

Future<void> _loadPixelFonts() async {
  for (final (family, asset) in [
    (AdventureTokens.pixelFont, 'assets/fonts/KenneyMini.ttf'),
    (AdventureTokens.pixelMonoFont, 'assets/fonts/KenneyMiniSquare.ttf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
}

const HallLedgerView _view = HallLedgerView(
  meId: robin,
  adults: [
    HallAdult(memberId: robin, name: 'Robin', inAdventure: true),
    HallAdult(memberId: sam, name: 'Sam', inAdventure: true),
  ],
  habitsAvailable: true,
);

Future<void> _steps(WidgetTester tester, int count) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _golden(WidgetTester tester, String name, {bool openGift = false}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(_loadPixelFonts);
  final registry = (await tester.runAsync(loadGameAssetRegistry))!;
  await tester.runAsync(() => PackAtlas.warmUp(registry).timeout(const Duration(seconds: 30)));
  final store = await storeWith([
    partyJoined('p01', kHouseholdPartyId, when: before(const Duration(days: 3))),
    partyJoined('p02', kHouseholdPartyId, when: before(const Duration(days: 3)), actor: sam),
    townsSplit('p03', robin, when: before(const Duration(days: 3))),
    granted('p04',
        when: before(const Duration(days: 2)),
        materials: MaterialBundle({MaterialKind.lumber: 100, MaterialKind.stone: 60, MaterialKind.ore: 12})),
    claimed('p05', 'reward-p04', when: before(const Duration(days: 2))),
    built('p06', 0, BuildingType.lumberyard, when: before(const Duration(days: 1)), actor: sam),
  ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: townTestOverrides(tier: AdventureTier.pixel, registry: registry, liveStore: store, view: _view),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AdventureTheme.build(),
        home: TownShell(onOpenLedger: () {}, ambientLife: false),
      ),
    ),
  );
  await tester.runAsync(() async {
    final element = tester.element(find.byType(TownShell));
    for (final pack in ['ui_pixel_adventure', 'tiny_dungeon', 'tiny_town', 'town_composed']) {
      await precacheImage(AssetImage('assets/game/packs/$pack/tilemap_packed.png'), element)
          .timeout(const Duration(seconds: 30));
    }
  });
  await _steps(tester, 4);
  tester.widget<TownSceneView>(find.byType(TownSceneView).last).onTarget(const SignpostTarget());
  await _steps(tester, 8);
  if (openGift) {
    await tester.tap(find.byKey(const ValueKey('neighbour-gift')));
    await _steps(tester, 4);
    await tester.tap(find.byKey(const ValueKey('gift-more-lumber')));
    await tester.tap(find.byKey(const ValueKey('gift-more-lumber')));
    await _steps(tester, 4);
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  testWidgets('visiting a neighbour on a phone', (tester) async {
    await _golden(tester, 'neighbour_view_phone');
  });

  testWidgets('the gift dialog on a phone', (tester) async {
    await _golden(tester, 'gift_dialog_phone', openGift: true);
  });
}
