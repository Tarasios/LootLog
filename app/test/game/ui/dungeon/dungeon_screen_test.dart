import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/state.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/spoils/spoils_model.dart';
import 'package:lootlog/features/spoils/spoils_move.dart';
import 'package:lootlog/game/battle/month_end_battle.dart';
import 'package:lootlog/game/data/game_providers.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart' show spoilsChestId;
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/text_mode/text_battle.dart';
import 'package:lootlog/game/ui/dungeon/battle_turn_panel.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_commit.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_providers.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_screen.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_voice.dart';
import 'package:lootlog/game/ui/hall_voice.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
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
  Month? firstBudgetMonth,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = await TownTestHarness.create(firstBudgetMonth: firstBudgetMonth);
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

/// Swings the weapon on the card at its selected target.
Future<void> strike(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Strike'));
  await tester.tap(find.text('Strike'));
  await pumpFrames(tester);
}

/// Picks the target button labelled [label] for the weapon on the card.
Future<void> aimAt(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await pumpFrames(tester);
}

Future<void> strikeEveryWeapon(WidgetTester tester, MonthEndBattle battle) async {
  for (var turn = 0; turn < battle.weapons.length; turn++) {
    await strike(tester);
  }
}

/// Taps "Return to town" (scrolling it into view first).
Future<void> returnToTown(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Return to town'));
  await tester.tap(find.text('Return to town'));
}

void main() {
  testWidgets('a closed gate explains when it opens', (tester) async {
    // The household started budgeting this month: no month-end is waiting.
    await pumpDungeon(tester, firstBudgetMonth: const Month(2026, 10));
    expect(find.textContaining('sealed until the month turns'), findsOneWidget);
  });

  testWidgets('a second weapon at a partly paid debt previews only what is still owed', (tester) async {
    final household = reduce(twoLeftoversOneDebtLedger().events, asOf: ritualInstant);
    final battle = MonthEndBattle.from(ritualOn(household), household)!;
    await pumpDungeon(tester, battle: battle);
    // Food's $30 strikes the $50 OVERBUDGET first (the pre-selected move).
    await strike(tester);
    // Hygiene's $40 now meets $20 of debt.
    final shown = tester.widget<Text>(find.byKey(const ValueKey('battle-preview'))).data!;
    expect(shown, startsWith('${money(2000)} lands.'));
    expect(find.text('That finishes it!'), findsOneWidget);
    await strike(tester);
    // The victory tally agrees: the OVERBUDGET is cleared, not over-paid.
    expect(find.text('Cleared!'), findsOneWidget);
  });

  group('the spoils chest never depends on leftovers', () {
    const september = Month(2026, 9);

    Future<void> expectChestWithoutLedgerWrite(WidgetTester tester, HouseholdState household) async {
      final battle = MonthEndBattle.from(ritualOn(household), household);
      expect(battle, isNull, reason: 'the ledger has nothing left to divide');
      final (harness, writes) = await pumpDungeon(tester, battle: battle, firstBudgetMonth: september);
      expect(find.byKey(const ValueKey('spoils-return')), findsOneWidget);
      expect(find.textContaining('September 2026'), findsOneWidget);
      await returnToTown(tester);
      await pumpFrames(tester);
      expect(writes, isEmpty, reason: 'nothing is written to the ledger');
      final chests = (await tester.runAsync(harness.store.all))!.whereType<ChestGranted>().toList();
      expect(chests.single.chestId, spoilsChestId(harness.meId, september));
      expect(find.text('The spoils are home'), findsOneWidget);
    }

    testWidgets('an all-overspent month still gets its chest', (tester) async {
      await expectChestWithoutLedgerWrite(tester, allOverspentHousehold());
    });

    testWidgets('a month past its grace period still gets its chest', (tester) async {
      await expectChestWithoutLedgerWrite(tester, pastGraceHousehold());
    });

    testWidgets('a month divided in the ledger gets its chest through the dungeon', (tester) async {
      await expectChestWithoutLedgerWrite(tester, dividedInLedgerHousehold());
    });

    testWidgets('the oldest waiting month comes home first', (tester) async {
      final (harness, _) = await pumpDungeon(tester);
      expect(find.textContaining('August 2026'), findsOneWidget);
      await returnToTown(tester);
      await pumpFrames(tester);
      final chests = (await tester.runAsync(harness.store.all))!.whereType<ChestGranted>().toList();
      expect(chests.single.chestId, spoilsChestId(harness.meId, const Month(2026, 8)));
    });

    testWidgets('a failed chest says so and the next tap tries again', (tester) async {
      final (harness, _) = await pumpDungeon(
        tester,
        firstBudgetMonth: september,
        onTimeMonths: FlakyOnTimeMonths(failures: 1),
      );
      await returnToTown(tester);
      await pumpFrames(tester);
      expect(find.byKey(const ValueKey('chest-pending')), findsOneWidget);
      await returnToTown(tester);
      await pumpFrames(tester);
      final chests = (await tester.runAsync(harness.store.all))!.whereType<ChestGranted>();
      expect(chests, hasLength(1));
    });

    testWidgets('the text tier shows the same victory', (tester) async {
      await pumpDungeon(tester, tier: AdventureTier.text, firstBudgetMonth: september);
      expect(find.byKey(const ValueKey('spoils-return')), findsOneWidget);
    });
  });

  testWidgets('an open gate shows the scene and the first weapon', (tester) async {
    final battle = fixtureBattle();
    await pumpDungeon(tester, battle: battle);
    expect(find.byKey(const ValueKey('dungeon-scene')), findsOneWidget);
    final weapon = battle.weapons.first;
    final card = find.byKey(const ValueKey('next-weapon'));
    expect(find.descendant(of: card, matching: find.text(weapon.name)), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(money(weapon.valueCents))), findsOneWidget);
  });

  testWidgets('the party frames show every adventurer around the floor', (tester) async {
    await pumpDungeon(tester, battle: fixtureBattle());
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
  });

  testWidgets('a second Strike before the card changes swings only one weapon', (tester) async {
    final household = reduce(twoLeftoversOneDebtLedger().events, asOf: ritualInstant);
    final battle = MonthEndBattle.from(ritualOn(household), household)!;
    await pumpDungeon(tester, battle: battle);
    final strikeButton = find.text('Strike');
    await tester.ensureVisible(strikeButton);
    final strikeAt = tester.getCenter(strikeButton);
    await tester.tapAt(strikeAt);
    await tester.tapAt(strikeAt);
    await pumpFrames(tester);
    final card = find.byKey(const ValueKey('next-weapon'));
    expect(find.descendant(of: card, matching: find.text(battle.weapons[1].name)), findsOneWidget);
  });

  testWidgets('a turn previews exactly what the shared move module computes', (tester) async {
    final battle = fixtureBattle();
    await pumpDungeon(tester, battle: battle);
    final weapon = battle.weapons.first;
    final goal = battle.bosses.first;
    await aimAt(tester, 'Toward ${goal.name}');
    final preview = previewSpoilsChoice(weapon.leftover, SpoilsChoice(SpoilsMove.goal, questId: goal.questId));
    final shown = tester.widget<Text>(find.byKey(const ValueKey('battle-preview'))).data!;
    expect(shown, startsWith('${money(preview.landsCents)} lands.'));
  });

  testWidgets('a strike at a goal is logged with the real split', (tester) async {
    final battle = fixtureBattle();
    await pumpDungeon(tester, battle: battle);
    final weapon = battle.weapons.first;
    final goal = battle.bosses.first;
    await aimAt(tester, 'Toward ${goal.name}');
    await strike(tester);
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
    await returnToTown(tester);
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
    await strike(tester);
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
    await tester.ensureVisible(find.text('Descend'));
    await tester.tap(find.text('Descend'));
    await pumpFrames(tester);
    await strikeEveryWeapon(tester, battle);
    await returnToTown(tester);
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
      await returnToTown(tester);
      await pumpFrames(tester);
      expect(writes, hasLength(1));
      expect(await chestsIn(tester, harness), isEmpty);
      final note = tester.widget<Text>(find.byKey(const ValueKey('chest-pending'))).data!;
      expect(note, contains('divided and saved'));
      expect(find.text('The spoils are home'), findsNothing);

      await returnToTown(tester);
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
        await returnToTown(tester);
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
    await tester.ensureVisible(returnButton);
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
    expect(tester.widget<WoodButton>(find.widgetWithText(WoodButton, 'Descend')).onPressed, isNull);
    await tester.enterText(field, '80');
    await pumpFrames(tester);
    expect(find.text('Enter an amount, like 82.50'), findsNothing);
    expect(tester.widget<WoodButton>(find.widgetWithText(WoodButton, 'Descend')).onPressed, isNotNull);
  });

  group('the turn panel', () {
    Future<void> pumpPanel(
      WidgetTester tester,
      BattleWeapon weapon, {
      required List<GoalBoss> bosses,
      required List<DebtMonster> debts,
      void Function(SpoilsChoice choice)? onStrike,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          // A bounded slot, as the battle layout gives it.
          body: Align(
            alignment: Alignment.topCenter,
            child: BattleTurnPanel(
              weapon: weapon,
              bosses: bosses,
              debts: debts,
              isAdventure: true,
              onStrike: onStrike ?? (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> openSheet(WidgetTester tester, MonthEndBattle battle,
            {required List<GoalBoss> bosses, required List<DebtMonster> debts}) =>
        pumpPanel(tester, battle.weapons.first, bosses: bosses, debts: debts);

    SpoilsChoice selectedTarget(WidgetTester tester) => tester
        .widgetList<BattleTargetButton>(find.byType(BattleTargetButton))
        .singleWhere((button) => button.selected)
        .choice;

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

    testWidgets('when the default debt is cleared, another standing debt comes before banking', (tester) async {
      const leftover = SliceLeftover(
        sliceId: 'food',
        name: 'Food',
        leftoverCents: 3000,
        poolTithePct: 0,
        defaultPolicy: Discretionary(),
        questOptions: [],
        overbudgetOptions: [
          OverbudgetOption(sliceId: 'fun', name: 'Fun', outstandingCents: 5000),
          OverbudgetOption(sliceId: 'toys', name: 'Toys', outstandingCents: 1000),
        ],
      );
      final weapon = BattleWeapon(leftover: leftover, defaultChoice: defaultSpoilsChoice(leftover));
      const fun = DebtMonster(sliceId: 'fun', name: 'Fun', outstandingCents: 0);
      const toys = DebtMonster(sliceId: 'toys', name: 'Toys', outstandingCents: 1000);
      await pumpPanel(tester, weapon, bosses: const [], debts: const [fun, toys]);
      expect(selectedTarget(tester), const SpoilsChoice(SpoilsMove.debt, overbudgetSliceId: 'toys'));
      final shown = tester.widget<Text>(find.byKey(const ValueKey('battle-preview'))).data!;
      expect(shown, startsWith('${money(1000)} lands.'));
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

    testWidgets('Strike hands back the target picked on the card', (tester) async {
      final battle = fixtureBattle();
      final goal = battle.bosses.first;
      final struck = <SpoilsChoice>[];
      await pumpPanel(tester, battle.weapons.first, bosses: battle.bosses, debts: const [], onStrike: struck.add);
      await tester.tap(find.text('Keep it in ${battle.weapons.first.name}'));
      await tester.pump();
      expect(selectedTarget(tester).move, SpoilsMove.carry);
      await tester.tap(find.text('Toward ${goal.name}'));
      await tester.pump();
      await tester.tap(find.text('Strike'));
      expect(struck, [SpoilsChoice(SpoilsMove.goal, questId: goal.questId)]);
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
