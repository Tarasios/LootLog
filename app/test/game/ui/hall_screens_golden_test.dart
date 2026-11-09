/// Goldens for the framed vault, forge and expeditions at desktop size, under
/// the Adventure theme with the bundled art packs. Text renders as
/// placeholder blocks (the test font), as in the other pixel goldens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/expeditions_screen.dart';
import 'package:lootlog/game/ui/forge_screen.dart';
import 'package:lootlog/game/ui/hall_common.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/game/ui/vault_screen.dart';

import 'decor/decor_golden_support.dart';
import 'hall_harness.dart';

List<GameEvent> _forgeEvents() => [
      ...sampleEvents(),
      built('f1', 2, BuildingType.forge, when: before(const Duration(hours: 4))),
      granted('f2',
          when: before(const Duration(hours: 4)),
          rewardId: 'ore',
          materials: MaterialBundle({MaterialKind.ore: 30, MaterialKind.hide: 12})),
      claimed('f3', 'ore', when: before(const Duration(hours: 4))),
    ];

Future<void> _pumpAndCapture(
  WidgetTester tester, {
  required Widget screen,
  required List<GameEvent> events,
  required String golden,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = await storeWith(events);
  final registry = (await tester.runAsync(loadGameAssetRegistry))!;
  await tester.pumpWidget(
    ProviderScope(
      overrides: hallOverrides(store: store, tier: AdventureTier.pixel, registry: registry),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AdventureTheme.build(),
        initialRoute: '/screen',
        routes: {
          '/': (_) => const SizedBox.shrink(),
          '/screen': (_) => HallScope(child: screen),
        },
      ),
    ),
  );
  await settle(tester);
  await decodeAllGameArt(tester, registry, find.byType(Scaffold));
  expect(tester.takeException(), isNull);
  await expectLater(find.byType(Scaffold), matchesGoldenFile(golden));
}

void main() {
  testWidgets('vault desktop', (tester) async {
    await _pumpAndCapture(tester,
        screen: VaultScreen(onOpenLedger: () {}),
        events: sampleEvents(),
        golden: 'goldens/vault_desktop.png');
  });

  testWidgets('forge desktop', (tester) async {
    await _pumpAndCapture(tester,
        screen: const ForgeScreen(),
        events: _forgeEvents(),
        golden: 'goldens/forge_desktop.png');
  });

  testWidgets('expeditions desktop', (tester) async {
    await _pumpAndCapture(tester,
        screen: const ExpeditionsScreen(),
        events: [
          ...sampleEvents(),
          expeditionStarted('x1', ExpeditionRegion.marketCatacombs,
              when: before(const Duration(minutes: 10)), minutes: 30),
        ],
        golden: 'goldens/expeditions_desktop.png');
  });
}
