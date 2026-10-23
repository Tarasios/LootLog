import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/features/spoils/spoils_model.dart';
import 'package:lootlog/features/spoils/spoils_move.dart';
import 'package:lootlog/game/battle/month_end_battle.dart';
import 'package:lootlog/game/data/game_providers.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/text_mode/text_battle.dart';
import 'package:lootlog/game/ui/dungeon/battle_turn_sheet.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_commit.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_providers.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_screen.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_voice.dart';
import 'package:lootlog/game/ui/hall_voice.dart';
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

/// Reads the on-time streak, failing the first [failures] times (as if the
/// ledger read behind the chest went wrong).
class FlakyOnTimeMonths {
  FlakyOnTimeMonths({this.failures = 0});

  int failures;
  int calls = 0;

  Future<int> read() async {
    calls++;
    if (calls <= failures) throw StateError('ledger read failed');
    return 0;
  }
}

Future<(TownTestHarness, List<RecordedWrite>)> pumpDungeon(
  WidgetTester tester, {
  MonthEndBattle? battle,
  AdventureTier tier = AdventureTier.pixel,
  FlakyOnTimeMonths? onTimeMonths,
  SpoilsWriter? writer,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = await TownTestHarness.create();
  final writes = <RecordedWrite>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...harness.overrides(tier: tier, battle: battle),
      spoilsWriterProvider.overrideWithValue((ritual, result) async {
        writes.add(RecordedWrite(ritual, result));
        await writer?.call(ritual, result);
      }),
      onTimeRitualMonthsProvider.overrideWith((ref) => (onTimeMonths ?? FlakyOnTimeMonths()).read()),
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

  Future<List<ChestGranted>> chestsIn(WidgetTester tester, TownTestHarness harness) async =>
      (await tester.runAsync(harness.store.all))!.whereType<ChestGranted>().toList();

  group('a chest that fails after the leftovers are saved', () {
    testWidgets('never rewrites the ledger; Return retries the chest alone', (tester) async {
      final battle = fixtureBattle();
      final onTime = FlakyOnTimeMonths(failures: 1);
      final (harness, writes) = await pumpDungeon(tester, battle: battle, onTimeMonths: onTime);
      await strikeEveryWeapon(tester, battle);
      await tester.tap(find.text('Return to town'));
      await pumpFrames(tester);
      expect(writes, hasLength(1));
      expect(await chestsIn(tester, harness), isEmpty);
      final note = tester.widget<Text>(find.byKey(const ValueKey('chest-pending'))).data!;
      expect(note, contains('divided and saved'));
      expect(find.text('The spoils are home'), findsNothing);

      await tester.tap(find.text('Return to town'));
      await pumpFrames(tester);
      expect(writes, hasLength(1), reason: 'the ledger is written once per battle');
      expect(await chestsIn(tester, harness), hasLength(1));
      expect(find.text('The spoils are home'), findsOneWidget);
    });

    testWidgets('keeps failing: still one ledger write however often Return is tapped', (tester) async {
      final battle = fixtureBattle();
      final (harness, writes) =
          await pumpDungeon(tester, battle: battle, onTimeMonths: FlakyOnTimeMonths(failures: 99));
      await strikeEveryWeapon(tester, battle);
      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.tap(find.text('Return to town'));
        await pumpFrames(tester);
      }
      expect(writes, hasLength(1));
      expect(await chestsIn(tester, harness), isEmpty);
      expect(find.byKey(const ValueKey('chest-pending')), findsOneWidget);
    });

    testWidgets('text tier: a dialog says the leftovers are saved and retries the chest alone', (tester) async {
      final battle = fixtureBattle();
      final (harness, writes) = await pumpDungeon(
        tester,
        battle: battle,
        tier: AdventureTier.text,
        onTimeMonths: FlakyOnTimeMonths(failures: 1),
      );
      final strike = find.text('Strike! — divide the spoils');
      await tester.ensureVisible(strike);
      await tester.tap(strike);
      await pumpFrames(tester);
      expect(writes, hasLength(1));
      expect(await chestsIn(tester, harness), isEmpty);
      final note = tester.widget<Text>(find.byKey(const ValueKey('chest-pending'))).data!;
      expect(note, contains('divided and saved'));

      await tester.tap(find.text('Try again'));
      await pumpFrames(tester);
      expect(writes, hasLength(1));
      expect(await chestsIn(tester, harness), hasLength(1));
      expect(find.text('The spoils are home'), findsOneWidget);
    });
  });

  testWidgets('a second tap on Return while saving does nothing', (tester) async {
    final battle = fixtureBattle();
    final release = Completer<void>();
    final (_, writes) = await pumpDungeon(tester, battle: battle, writer: (ritual, result) => release.future);
    await strikeEveryWeapon(tester, battle);
    final returnButton = find.text('Return to town');
    await tester.tap(returnButton);
    await tester.tap(returnButton, warnIfMissed: false);
    release.complete();
    await pumpFrames(tester);
    expect(writes, hasLength(1));
  });

  testWidgets('an unreadable upkeep amount shows an error and holds the descent', (tester) async {
    final (household, ritual) = ritualFixtureWithVariableBill();
    final battle = MonthEndBattle.from(ritual, household)!;
    await pumpDungeon(tester, battle: battle);
    final field = find.byKey(ValueKey('upkeep-${battle.upkeep.single.expenseId}'));
    await tester.enterText(field, 'eighty');
    await pumpFrames(tester);
    expect(find.text('Enter an amount, like 82.50'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Descend')).onPressed, isNull);
    await tester.enterText(field, '80');
    await pumpFrames(tester);
    expect(find.text('Enter an amount, like 82.50'), findsNothing);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Descend')).onPressed, isNotNull);
  });

  group('the turn sheet', () {
    Future<void> openSheet(WidgetTester tester, MonthEndBattle battle,
        {required List<GoalBoss> bosses, required List<DebtMonster> debts}) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showBattleTurnSheet(
                context,
                weapon: battle.weapons.first,
                bosses: bosses,
                debts: debts,
                isAdventure: true,
              ),
              child: const Text('turn'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('turn'));
      await tester.pumpAndSettle();
    }

    testWidgets('a debt an earlier weapon cleared is not offered, and the default banks instead', (tester) async {
      final (household, ritual) = ritualFixtureWithDebt();
      final battle = MonthEndBattle.from(ritual, household)!;
      final debt = battle.debts.single;
      await openSheet(tester, battle, bosses: battle.bosses, debts: [debt.afterLanding(debt.outstandingCents)]);
      expect(find.textContaining('Pay off'), findsNothing);
      final bank = previewSpoilsChoice(battle.weapons.first.leftover, const SpoilsChoice(SpoilsMove.bank));
      final shown = tester.widget<Text>(find.byKey(const ValueKey('battle-preview'))).data!;
      expect(shown, startsWith('${money(bank.landsCents)} lands.'));
    });

    testWidgets('a still-standing debt is offered', (tester) async {
      final (household, ritual) = ritualFixtureWithDebt();
      final battle = MonthEndBattle.from(ritual, household)!;
      await openSheet(tester, battle, bosses: battle.bosses, debts: battle.debts);
      expect(find.text('Pay off ${battle.debts.single.name}'), findsOneWidget);
    });

    testWidgets('a goal already reached is not offered', (tester) async {
      final battle = fixtureBattle();
      final goal = battle.bosses.first;
      await openSheet(tester, battle, bosses: [goal.afterLanding(goal.targetCents)], debts: const []);
      expect(find.text('Toward ${goal.name}'), findsNothing);
    });
  });

  group('the celebration lines', () {
    GameCommandResult bonusResult(int gems) => GameCommandResult.accepted([
          RewardGranted(
            eventId: 'r1',
            deviceId: 'd',
            actorId: 'alex',
            occurredAt: ritualInstant,
            createdAt: ritualInstant,
            rewardId: 'ritual.bonus:alex:2026-09',
            kind: 'gems',
            gems: gems,
            materials: const MaterialBundle.empty(),
            tokens: 0,
            reasonCode: 'ritual.bonus',
            sourceLedgerEventIds: const [],
          ),
        ]);

    List<String> linesFor(MonthEndGameOutcome outcome) => monthEndCelebrationLines(outcome,
        dungeonVoice: DungeonVoice.empty, hallVoice: HallVoice.empty, seed: 'seed');

    testWidgets('a bonus with no on-time streak never claims one', (tester) async {
      final lines = linesFor(MonthEndGameOutcome(result: bonusResult(2), onTimeRitualMonths: 0));
      expect(lines.last, DungeonVoice.empty.line('bonusGear', fill: const {'gems': '2'}));
    });

    testWidgets('a bonus with a streak names the streak', (tester) async {
      final lines = linesFor(MonthEndGameOutcome(result: bonusResult(6), onTimeRitualMonths: 2));
      expect(lines.last, DungeonVoice.empty.line('bonusOnTime', fill: const {'gems': '6', 'months': '2'}));
    });
  });
}
