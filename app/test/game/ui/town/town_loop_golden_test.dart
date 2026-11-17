/// Goldens for the town loop on a phone, drawn with the bundled art packs
/// and the pixel fonts: a trader standing by the square with its sign, the
/// square dressed for a fair, and the "while you were away" summary. No
/// ambient villagers, so the frames are stable.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../hall_harness.dart';
import 'town_loop_fixtures.dart';
import 'town_test_overrides.dart';

Future<void> _loadPixelFonts() async {
  for (final (family, asset) in [
    (AdventureTokens.pixelFont, 'assets/fonts/KenneyMini.ttf'),
    (AdventureTokens.pixelMonoFont, 'assets/fonts/KenneyMiniSquare.ttf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
}

Future<void> _golden(
  WidgetTester tester,
  String name, {
  required List<GameEvent> events,
  bool popups = false,
  bool openAwaySummary = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(_loadPixelFonts);
  final registry = (await tester.runAsync(loadGameAssetRegistry))!;
  await tester.runAsync(() => PackAtlas.warmUp(registry).timeout(const Duration(seconds: 30)));
  await tester.pumpWidget(
    ProviderScope(
      overrides: townTestOverrides(
        tier: AdventureTier.pixel,
        registry: registry,
        game: projectGameState(events),
        loopPopups: popups,
      ),
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
      await precacheImage(
        AssetImage('assets/game/packs/$pack/tilemap_packed.png'),
        element,
      ).timeout(const Duration(seconds: 30));
    }
  });
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (openAwaySummary) {
    await tester.tap(find.byKey(const ValueKey('town-away-chip')));
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  testWidgets('a trader in town', (tester) async {
    await _golden(tester, 'town_loop_phone_event', events: [...sampleEvents(), offered('x0001')]);
  });

  testWidgets('a fair in the square', (tester) async {
    await _golden(
      tester,
      'town_loop_phone_festival',
      events: [...sampleEvents(), ...festivalEvents(tier: FestivalTier.grandFestival)],
    );
  });

  testWidgets('while you were away', (tester) async {
    await _golden(
      tester,
      'away_summary_dialog_phone',
      events: [
        ...sampleEvents(),
        built('x0001', 2, BuildingType.quarry, when: before(const Duration(hours: 4))),
      ],
      openAwaySummary: true,
    );
  });
}
