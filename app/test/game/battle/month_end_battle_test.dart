import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/spoils/spoils_move.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/battle/month_end_battle.dart';

import '../../features/spoils/spoils_fixtures.dart';

void main() {
  test('no ritual, no battle', () {
    final (household, _) = ritualFixture();
    expect(MonthEndBattle.from(null, household), isNull);
  });

  test('every leftover becomes a weapon worth exactly its value', () {
    final (household, ritual) = ritualFixture();
    final battle = MonthEndBattle.from(ritual, household)!;
    expect(battle.weapons, isNotEmpty);
    expect(battle.weapons.map((weapon) => weapon.sliceId), ritual.sliceLeftovers.map((leftover) => leftover.sliceId));
    for (final weapon in battle.weapons) {
      expect(weapon.valueCents, weapon.leftover.leftoverCents);
    }
  });

  test('goal bosses: HP is what is left, the picture reveals with progress', () {
    final (household, ritual) = ritualFixture();
    final boss = MonthEndBattle.from(ritual, household)!.bosses.first;
    expect(boss.remainingCents, boss.targetCents - boss.progressCents);
    expect(boss.revealFraction, closeTo(boss.progressCents / boss.targetCents, 1e-9));
    final hit = boss.afterLanding(boss.remainingCents + 500);
    expect(hit.remainingCents, 0);
    expect(hit.revealFraction, 1.0);
  });

  test('an outstanding debt is the pre-selected target', () {
    final (household, ritual) = ritualFixtureWithDebt();
    expect(ritual.sliceLeftovers.first.overbudgetOptions, isNotEmpty);
    final battle = MonthEndBattle.from(ritual, household)!;
    final weapon = battle.weapons.first;
    expect(weapon.defaultChoice.move, SpoilsMove.debt);
    expect(battle.debts, isNotEmpty);
    final monster = battle.debts.first;
    expect(monster.afterLanding(monster.outstandingCents + 1).outstandingCents, 0);
  });

  test('resultFor writes the same allocations the Standard sheet would', () {
    final (household, ritual) = ritualFixture();
    final battle = MonthEndBattle.from(ritual, household)!;
    final choices = {for (final weapon in battle.weapons) weapon.sliceId: const SpoilsChoice(SpoilsMove.bank)};
    final result = battle.resultFor(choices: choices, actualsByExpenseId: const {});
    expect(result.allocations, isNotEmpty);
    for (final sliceResult in result.allocations) {
      final leftover = ritual.sliceLeftovers.firstWhere((leftover) => leftover.sliceId == sliceResult.sliceId);
      final expected = allocationsForChoice(leftover, const SpoilsChoice(SpoilsMove.bank));
      expect(sliceResult.allocations.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        expect(sliceResult.allocations[i].destination, expected[i].destination);
        expect(sliceResult.allocations[i].amountCents, expected[i].amountCents);
      }
    }
    expect(result.tallies.length, ritual.variableTallies.length, reason: 'unrecorded actuals default to the estimate');
  });

  test('a quest offered on several leftovers is one boss; a debt offered on several is one monster', () {
    final (household, ritual) = ritualFixture();
    expect(ritual.sliceLeftovers.length, greaterThan(1));
    expect(MonthEndBattle.from(ritual, household)!.bosses, hasLength(1));
    final (debtHousehold, debtRitual) = ritualFixtureWithDebt();
    expect(MonthEndBattle.from(debtRitual, debtHousehold)!.debts, hasLength(1));
  });

  test('a boss with no target is already revealed and has no HP', () {
    const boss = GoalBoss(
      questId: 'q',
      name: 'q',
      targetCents: 0,
      progressCents: 0,
      spriteKey: AssetKey('boss', 'goal'),
      shared: false,
    );
    expect(boss.revealFraction, 1.0);
    expect(boss.remainingCents, 0);
  });

  test('a negative landing changes nothing', () {
    final (household, ritual) = ritualFixture();
    final boss = MonthEndBattle.from(ritual, household)!.bosses.first;
    expect(boss.afterLanding(-500).progressCents, boss.progressCents);
    final (debtHousehold, debtRitual) = ritualFixtureWithDebt();
    final monster = MonthEndBattle.from(debtRitual, debtHousehold)!.debts.first;
    expect(monster.afterLanding(-500).outstandingCents, monster.outstandingCents);
  });

  test('variable bills: the estimate stands unless an actual is entered', () {
    final (household, ritual) = ritualFixtureWithVariableBill();
    final battle = MonthEndBattle.from(ritual, household)!;
    expect(ritual.variableTallies, isNotEmpty);
    expect(battle.upkeep, ritual.variableTallies);
    final tally = ritual.variableTallies.first;

    final estimated = battle.resultFor(choices: const {}, actualsByExpenseId: const {});
    expect(estimated.tallies.map((entry) => entry.expenseId), ritual.variableTallies.map((entry) => entry.expenseId));
    expect(estimated.tallies.first.actualCents, tally.estimateCents);

    final entered = battle.resultFor(choices: const {}, actualsByExpenseId: {tally.expenseId: 9123});
    expect(entered.tallies.first.actualCents, 9123);
  });

  test('with no choices the pre-selected debt payment is written', () {
    final (household, ritual) = ritualFixtureWithDebt();
    final result = MonthEndBattle.from(ritual, household)!.resultFor(choices: const {}, actualsByExpenseId: const {});
    final lines = result.allocations.first.allocations;
    expect(lines, hasLength(1));
    expect(lines.first.destination, isA<OverbudgetPayment>());
    expect(lines.first.amountCents, ritual.sliceLeftovers.first.leftoverCents);
  });
}
