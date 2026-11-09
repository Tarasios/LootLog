/// Goldens for the town as the Adventure home under the Adventure theme,
/// drawn with the bundled art packs and the pixel fonts: a phone, a desktop
/// window with the quest board folded away (the whole window is town), and a
/// large desktop window with the board docked. A month-end waiting, a bill
/// due tomorrow and goal progress hang their signs. No ambient villagers, so
/// the frames are stable.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/money.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/battle/month_end_battle.dart';
import 'package:lootlog/game/domain/town/quest_board_view.dart';
import 'package:lootlog/game/domain/town/town_ledger.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/game/ui/town/quest_board_prefs.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../../../features/spoils/spoils_fixtures.dart';
import '../hall_harness.dart' show robin;
import 'town_test_overrides.dart';

/// The board folded away, as a player who prefers the whole town would have.
class _FoldedBoard extends QuestBoardCollapsedNotifier {
  @override
  bool build() => true;
}

/// The sample ledger plus a second goal, a debt, a writ, recent loot and
/// Robin's rent due tomorrow.
final TownLedger _goldenLedger = TownLedger(
  board: QuestBoardView(
    goals: [
      ...kSampleTownLedger.board.goals,
      const QuestBoardGoal(
        questId: 'trip',
        name: 'Island trip',
        percent: 15,
        remaining: Money(170000),
        target: Money(200000),
        shared: true,
      ),
    ],
    debts: const [
      QuestBoardDebt(categoryId: 'games', name: 'Games', outstanding: Money(4000)),
    ],
    pendingWrits: 1,
    monsters: kSampleTownLedger.board.monsters,
    recent: [
      QuestBoardEntry(label: 'Corner Market', amount: const Money(3000), occurredAt: DateTime.utc(2026, 10, 2)),
      QuestBoardEntry(label: 'Fun', amount: const Money(25000), occurredAt: DateTime.utc(2026, 10, 1)),
    ],
  ),
  goldPouch: kSampleTownLedger.goldPouch,
  warChest: kSampleTownLedger.warChest,
  bills: const [(name: 'Rent', daysUntilDue: 1, ownerId: robin)],
);

Future<void> _loadPixelFonts() async {
  for (final (family, asset) in [
    (AdventureTokens.pixelFont, 'assets/fonts/KenneyPixel.ttf'),
    (AdventureTokens.pixelMonoFont, 'assets/fonts/KenneyMiniSquare.ttf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
}

void main() {
  for (final (name, size, folded) in [
    ('phone', const Size(390, 844), false),
    ('desktop', const Size(1280, 800), true),
    ('desktop_board', const Size(1440, 900), false),
  ]) {
    testWidgets('town shell $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(_loadPixelFonts);
      final registry = (await tester.runAsync(loadGameAssetRegistry))!;
      // Decode the art for real first (bounded); the scene then finds it
      // ready and draws within a few frames of the test clock.
      await tester.runAsync(() => PackAtlas.warmUp(registry).timeout(const Duration(seconds: 30)));
      final (household, ritual) = ritualFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...townTestOverrides(
              tier: AdventureTier.pixel,
              registry: registry,
              ledger: _goldenLedger,
              battle: MonthEndBattle.from(ritual, household),
            ),
            if (folded) questBoardCollapsedProvider.overrideWith(_FoldedBoard.new),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AdventureTheme.build(),
            home: TownShell(onOpenLedger: () {}, ambientLife: false),
          ),
        ),
      );
      // Decode the sheets the Flutter-drawn frames and portraits use too.
      await tester.runAsync(() async {
        final element = tester.element(find.byType(TownShell));
        for (final pack in ['ui_pixel_adventure', 'tiny_dungeon']) {
          await precacheImage(
            AssetImage('assets/game/packs/$pack/tilemap_packed.png'),
            element,
          ).timeout(const Duration(seconds: 30));
        }
      });
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await expectLater(
        find.byType(TownShell),
        matchesGoldenFile('goldens/town_shell_$name.png'),
      );
    });
  }
}
