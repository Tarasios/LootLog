/// Goldens for the long road on a phone: each civic quarter with buildings
/// at several tiers, Castle Hill with the surveyed hilltop and with the
/// finished Castle, the workshop sheet and the Castle sheet (and Market Row
/// on a desktop). Drawn with the bundled art and the pixel fonts; no
/// ambient villagers, so the frames are stable.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/scenes/town/town_scene_view.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/game/ui/town/quest_board_prefs.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../../domain/town/growth_fixtures.dart';
import '../hall_harness.dart' show before, storeWith;
import 'long_road_fixtures.dart';
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

/// [type] built up to [tier] on [plotIndex] of [districtId], a tier at a
/// time, finished long ago.
List<CivicBuildingStarted> _upTo(String districtId, int plotIndex, CivicBuildingType type, int tier) => [
      for (var level = 1; level <= tier; level++)
        civicBuilt('$districtId-$plotIndex-$level', districtId, plotIndex, type,
            tier: level, when: before(Duration(days: 40 - level))),
    ];

/// Every quarter built up, a workshop job under way, and [castleStages]
/// Castle stages finished.
List<GameEvent> _builtUp({int castleStages = 0}) {
  var start = before(const Duration(days: 150));
  return longRoadEvents(TownTier.city, goods: true, extra: [
    ..._upTo(kGuardPostDistrictId, 0, CivicBuildingType.watchtower, 1),
    ..._upTo(kGuardPostDistrictId, 1, CivicBuildingType.barracks, 3),
    ..._upTo(kGuardPostDistrictId, 2, CivicBuildingType.wallSection, 5),
    ..._upTo(kResidentialDistrictId, 0, CivicBuildingType.cottage, 1),
    ..._upTo(kResidentialDistrictId, 1, CivicBuildingType.cottage, 2),
    ..._upTo(kResidentialDistrictId, 2, CivicBuildingType.rowhouse, 3),
    ..._upTo(kResidentialDistrictId, 3, CivicBuildingType.well, 4),
    ..._upTo(kResidentialDistrictId, 4, CivicBuildingType.cottage, 5),
    ..._upTo(kParkDistrictId, 0, CivicBuildingType.garden, 2),
    ..._upTo(kParkDistrictId, 1, CivicBuildingType.bandstand, 3),
    ..._upTo(kParkDistrictId, 2, CivicBuildingType.fountain, 5),
    ..._upTo(kMarketRowDistrictId, 0, CivicBuildingType.stall, 1),
    ..._upTo(kMarketRowDistrictId, 1, CivicBuildingType.workshop, 2),
    ..._upTo(kMarketRowDistrictId, 2, CivicBuildingType.guildHall, 4),
    ..._upTo(kMarketRowDistrictId, 3, CivicBuildingType.stall, 3),
    refiningStarted('job', 1, 'tools',
        when: before(const Duration(minutes: 20)),
        completesAt: before(const Duration(minutes: 20)).add(const Duration(minutes: 120)),
        output: GoodsBundle({GoodsKind.tools: 2})),
    for (var stage = 1; stage <= castleStages; stage++)
      castleStageStarted('castle-$stage', stage, when: start = start.add(Duration(days: stage == 1 ? 0 : Balance.castleStages[stage - 2].buildDays))),
  ]);
}

Future<void> _pump(WidgetTester tester, Size size, List<GameEvent> events) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(_loadPixelFonts);
  final registry = (await tester.runAsync(loadGameAssetRegistry))!;
  await tester.runAsync(() => PackAtlas.warmUp(registry).timeout(const Duration(seconds: 30)));
  final store = (await tester.runAsync(() => storeWith(events)))!;
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
    for (final pack in ['ui_pixel_adventure', 'tiny_town', 'tiny_dungeon', 'tiny_farm', 'town_composed']) {
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

Future<void> _open(WidgetTester tester, String districtId) async {
  final button = find.byKey(ValueKey('district-$districtId'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _frames(tester);
}

Future<void> _tapCastle(WidgetTester tester) async {
  final scene = tester.widget<TownSceneView>(find.byType(TownSceneView).last);
  scene.onTarget(scene.view.targetAt(scene.view.layout.castleOrigin!)!);
  await _frames(tester);
}

void main() {
  const phone = Size(390, 844);

  for (final id in [kGuardPostDistrictId, kResidentialDistrictId, kParkDistrictId, kMarketRowDistrictId]) {
    testWidgets('$id on a phone', (tester) async {
      await _pump(tester, phone, _builtUp());
      await _open(tester, id);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/district_${id}_phone.png'));
    });
  }

  testWidgets('market row on a desktop', (tester) async {
    await _pump(tester, const Size(1280, 800), _builtUp());
    await _open(tester, kMarketRowDistrictId);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/district_marketRow_desktop.png'));
  });

  testWidgets('castle hill surveyed, on a phone', (tester) async {
    await _pump(tester, phone, _builtUp());
    await _open(tester, kCastleHillDistrictId);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/castle_hill_stage0_phone.png'));
  });

  testWidgets('castle hill finished, on a phone', (tester) async {
    await _pump(tester, phone, _builtUp(castleStages: 5));
    await _open(tester, kCastleHillDistrictId);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/castle_hill_stage5_phone.png'));
  });

  testWidgets('the castle sheet on a phone', (tester) async {
    await _pump(tester, phone, _builtUp(castleStages: 2));
    await _open(tester, kCastleHillDistrictId);
    await _tapCastle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/castle_sheet_phone.png'));
  });

  testWidgets('the workshop sheet on a phone', (tester) async {
    await _pump(tester, phone, _builtUp());
    await _open(tester, kMarketRowDistrictId);
    final scene = tester.widget<TownSceneView>(find.byType(TownSceneView).last);
    scene.onTarget(scene.view.targetAt(scene.view.plots[1].origin)!);
    await _frames(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/workshop_sheet_phone.png'));
  });
}
