import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/features/spoils/spoils_model.dart';
import 'package:lootlog/features/spoils/spoils_move.dart';
import 'package:lootlog/game/battle/month_end_battle.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/text_mode/text_battle.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_providers.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_screen.dart';
import 'package:lootlog/ui/format.dart';

import '../../../features/spoils/spoils_fixtures.dart';
import '../town/town_test_overrides.dart';

class RecordedWrite {
  const RecordedWrite(this.ritual, this.result);
  final SpoilsRitual ritual;
  final SpoilsResult result;
}

/// The Flame scene ticks forever, so pumpAndSettle never settles: advance
/// time in fixed steps instead (enough for a route or sheet to finish).
Future<void> pumpFrames(WidgetTester tester) async {
  for (var step = 0; step < 8; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<(TownTestHarness, List<RecordedWrite>)> pumpDungeon(
  WidgetTester tester, {
  MonthEndBattle? battle,
  AdventureTier tier = AdventureTier.pixel,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = await TownTestHarness.create();
  final writes = <RecordedWrite>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...harness.overrides(tier: tier, battle: battle),
      spoilsWriterProvider.overrideWithValue((ritual, result) async => writes.add(RecordedWrite(ritual, result))),
      onTimeRitualMonthsProvider.overrideWith((ref) async => 0),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () => DungeonScreen.open(context), child: const Text('enter')),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('enter'));
  await pumpFrames(tester);
  return (harness, writes);
}

MonthEndBattle fixtureBattle() {
  final (household, ritual) = ritualFixture();
  return MonthEndBattle.from(ritual, household)!;
}

Future<void> strikeEveryWeapon(WidgetTester tester, MonthEndBattle battle) async {
  for (var turn = 0; turn < battle.weapons.length; turn++) {
    await tester.tap(find.byKey(const ValueKey('next-weapon')));
    await pumpFrames(tester);
    await tester.tap(find.text('Strike'));
    await pumpFrames(tester);
  }
}

void main() {
  testWidgets('a closed gate explains when it opens', (tester) async {
    await pumpDungeon(tester);
    expect(find.textContaining('sealed until the month turns'), findsOneWidget);
  });

  testWidgets('an open gate shows the scene and the first weapon', (tester) async {
    final battle = fixtureBattle();
    await pumpDungeon(tester, battle: battle);
    expect(find.byKey(const ValueKey('dungeon-scene')), findsOneWidget);
    final weapon = battle.weapons.first;
    expect(find.text('${weapon.name}: ${money(weapon.valueCents)}'), findsOneWidget);
  });

  testWidgets('a turn previews exactly what the shared move module computes', (tester) async {
    final battle = fixtureBattle();
    await pumpDungeon(tester, battle: battle);
    await tester.tap(find.byKey(const ValueKey('next-weapon')));
    await pumpFrames(tester);
    final weapon = battle.weapons.first;
    final goal = battle.bosses.first;
    await tester.tap(find.text('Toward ${goal.name}'));
    await pumpFrames(tester);
    final preview = previewSpoilsChoice(weapon.leftover, SpoilsChoice(SpoilsMove.goal, questId: goal.questId));
    final shown = tester.widget<Text>(find.byKey(const ValueKey('battle-preview'))).data!;
    expect(shown, startsWith('${money(preview.landsCents)} lands.'));
  });

  testWidgets('a strike at a goal is logged with the real split', (tester) async {
    final battle = fixtureBattle();
    await pumpDungeon(tester, battle: battle);
    await tester.tap(find.byKey(const ValueKey('next-weapon')));
    await pumpFrames(tester);
    final weapon = battle.weapons.first;
    final goal = battle.bosses.first;
    await tester.tap(find.text('Toward ${goal.name}'));
    await pumpFrames(tester);
    await tester.tap(find.text('Strike'));
    await pumpFrames(tester);
    final preview = previewSpoilsChoice(weapon.leftover, SpoilsChoice(SpoilsMove.goal, questId: goal.questId));
    final logged = tester.widget<Text>(find.byKey(const ValueKey('dungeon-log'))).data!;
    expect(logged, contains(money(preview.landsCents)));
    expect(logged, contains(goal.name));
  });

  testWidgets('nothing is written until Return to town; then one result and the spoils chest', (tester) async {
    final battle = fixtureBattle();
    final (harness, writes) = await pumpDungeon(tester, battle: battle);
    await strikeEveryWeapon(tester, battle);
    expect(writes, isEmpty);
    await tester.tap(find.text('Return to town'));
    await pumpFrames(tester);
    expect(writes, hasLength(1));
    expect(writes.single.ritual, same(battle.ritual));
    expect(writes.single.result.allocations, hasLength(battle.weapons.length));
    final expected = battle.resultFor(choices: const {}, actualsByExpenseId: const {});
    for (var index = 0; index < expected.allocations.length; index++) {
      final written = writes.single.result.allocations[index];
      expect(written.sliceId, expected.allocations[index].sliceId);
      expect(
        written.allocations.map((line) => (line.destination, line.amountCents)),
        expected.allocations[index].allocations.map((line) => (line.destination, line.amountCents)),
      );
    }
    final chests = (await tester.runAsync(harness.store.all))!.whereType<ChestGranted>();
    expect(chests.single.chestType, ChestType.spoils);
    expect(find.text('The spoils are home'), findsOneWidget);
  });

  testWidgets('leaving early writes nothing', (tester) async {
    final battle = fixtureBattle();
    final (harness, writes) = await pumpDungeon(tester, battle: battle);
    await tester.tap(find.byKey(const ValueKey('next-weapon')));
    await pumpFrames(tester);
    await tester.tap(find.text('Strike'));
    await pumpFrames(tester);
    await tester.pageBack();
    await pumpFrames(tester);
    expect(writes, isEmpty);
    expect((await tester.runAsync(harness.store.all))!.whereType<ChestGranted>(), isEmpty);
  });

  testWidgets('variable bills are tallied at the entrance and written with the result', (tester) async {
    final (household, ritual) = ritualFixtureWithVariableBill();
    final battle = MonthEndBattle.from(ritual, household)!;
    final (_, writes) = await pumpDungeon(tester, battle: battle);
    final tally = battle.upkeep.single;
    await tester.enterText(find.byKey(ValueKey('upkeep-${tally.expenseId}')), '91.23');
    await tester.tap(find.text('Descend'));
    await pumpFrames(tester);
    await strikeEveryWeapon(tester, battle);
    await tester.tap(find.text('Return to town'));
    await pumpFrames(tester);
    final written = writes.single.result.tallies.single;
    expect(written.expenseId, tally.expenseId);
    expect(written.actualCents, 9123);
  });

  testWidgets('text tier shows the text battle for the same ritual', (tester) async {
    final battle = fixtureBattle();
    await pumpDungeon(tester, battle: battle, tier: AdventureTier.text);
    final view = tester.widget<TextBattleView>(find.byType(TextBattleView));
    expect(view.ritual, same(battle.ritual));
  });

  testWidgets('the text battle commits through the same path and grants the chest', (tester) async {
    final battle = fixtureBattle();
    final (harness, writes) = await pumpDungeon(tester, battle: battle, tier: AdventureTier.text);
    final strike = find.text('Strike! — divide the spoils');
    await tester.ensureVisible(strike);
    await tester.tap(strike);
    await pumpFrames(tester);
    expect(writes, hasLength(1));
    expect(writes.single.result.allocations, hasLength(battle.weapons.length));
    final chests = (await tester.runAsync(harness.store.all))!.whereType<ChestGranted>();
    expect(chests.single.chestType, ChestType.spoils);
    expect(find.text('The spoils are home'), findsOneWidget);
  });
}
