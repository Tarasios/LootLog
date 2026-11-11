/// Goldens for the districts on a phone (and the farmland on a desktop):
/// the farmland district with fields at several tiers, the district picker
/// and the town book. Drawn with the bundled art and the pixel fonts; no
/// ambient villagers, so the frames are stable.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/game/ui/town/quest_board_prefs.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../../domain/town/growth_fixtures.dart';
import '../hall_harness.dart' show before, claimed, granted, sampleEvents, storeWith;
import 'town_test_overrides.dart';

class _FoldedBoard extends QuestBoardCollapsedNotifier {
  @override
  bool build() => true;
}

Future<void> _loadPixelFonts() async {
  for (final (family, asset) in [
    (AdventureTokens.pixelFont, 'assets/fonts/KenneyMini.ttf'),
    (AdventureTokens.pixelMonoFont, 'assets/fonts/KenneyMiniSquare.ttf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
}

/// Robin's hamlet with the farmland bought and planted: farms and an
/// orchard at several tiers and a granary.
List<GameEvent> _farmlandEvents() {
  final when = before(const Duration(days: 1));
  return [
    ...sampleEvents(),
    tierReached('t-hamlet', TownTier.hamlet, when: before(const Duration(days: 3))),
    granted('stores-a', when: before(const Duration(days: 2)), rewardId: 'stores',
        materials: MaterialBundle({MaterialKind.lumber: 140, MaterialKind.stone: 140})),
    claimed('stores-b', 'stores', when: before(const Duration(days: 2))),
    districtPurchased('d-farmland', kFarmlandDistrictId, when: when),
    farmBuilt('f0', 0, FarmBuildingType.farm, when: when),
    farmBuilt('f1', 0, FarmBuildingType.farm, when: when, tier: 2),
    farmBuilt('f2', 0, FarmBuildingType.farm, when: when, tier: 3),
    farmBuilt('o0', 2, FarmBuildingType.orchard, when: when),
    farmBuilt('o1', 2, FarmBuildingType.orchard, when: when, tier: 2),
    farmBuilt('o2', 2, FarmBuildingType.orchard, when: when, tier: 3),
    farmBuilt('o3', 2, FarmBuildingType.orchard, when: when, tier: 4),
    farmBuilt('o4', 2, FarmBuildingType.orchard, when: when, tier: 5),
    farmBuilt('g0', 3, FarmBuildingType.granary, when: when),
    farmBuilt('p0', 1, FarmBuildingType.farm, when: when),
  ];
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(_loadPixelFonts);
  final registry = (await tester.runAsync(loadGameAssetRegistry))!;
  await tester.runAsync(() => PackAtlas.warmUp(registry).timeout(const Duration(seconds: 30)));
  final store = (await tester.runAsync(() => storeWith(_farmlandEvents())))!;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...townTestOverrides(tier: AdventureTier.pixel, registry: registry, liveStore: store),
        questBoardCollapsedProvider.overrideWith(_FoldedBoard.new),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AdventureTheme.build(),
        home: TownShell(onOpenLedger: () {}, ambientLife: false),
      ),
    ),
  );
  await tester.runAsync(() async {
    final element = tester.element(find.byType(TownShell));
    for (final pack in ['ui_pixel_adventure', 'tiny_dungeon', 'tiny_farm', 'town_composed']) {
      await precacheImage(AssetImage('assets/game/packs/$pack/tilemap_packed.png'), element)
          .timeout(const Duration(seconds: 30));
    }
  });
  await _frames(tester);
}

Future<void> _frames(WidgetTester tester) async {
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openFarmland(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('district-farmland')));
  await _frames(tester);
}

void main() {
  testWidgets('farmland on a phone', (tester) async {
    await _pump(tester, const Size(390, 844));
    await _openFarmland(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/district_farmland_phone.png'));
  });

  testWidgets('farmland on a desktop', (tester) async {
    await _pump(tester, const Size(1280, 800));
    await _openFarmland(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/district_farmland_desktop.png'));
  });

  testWidgets('district picker on a phone', (tester) async {
    await _pump(tester, const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('district-map')));
    await _frames(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/district_picker_phone.png'));
  });

  testWidgets('town book on a phone', (tester) async {
    await _pump(tester, const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('town-hud-date')));
    await _frames(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/town_book_phone.png'));
  });
}
