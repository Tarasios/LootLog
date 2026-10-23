import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/ritual_order.dart';
import 'package:lootlog/domain/time.dart';
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
    expect(battle.weapons.map((weapon) => weapon.sliceId),
        inRitualOrder(ritual.sliceLeftovers).map((leftover) => leftover.sliceId));
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

  group('a later weapon previews against what earlier ones left', () {
    const september = Month(2026, 9);
    const payFun = SpoilsChoice(SpoilsMove.debt, overbudgetSliceId: 'fun');

    test('the second hit on a partly paid debt matches the reducer', () {
      final ledger = twoLeftoversOneDebtLedger();
      final household = reduce(ledger.events, asOf: ritualInstant);
      final battle = MonthEndBattle.from(ritualOn(household), household)!;
      expect(battle.weapons.map((weapon) => weapon.sliceId), ['food', 'hygiene']);
      final debt = battle.debts.single;
      expect(debt.outstandingCents, 5000);

      final food = battle.weapons[0];
      final hygiene = battle.weapons[1];
      final firstHit = previewSpoilsChoice(food.leftover, payFun);
      final debtsNow = [debt.afterLanding(firstHit.landsCents)];
      final secondHit = previewSpoilsChoice(
        leftoverAgainst(hygiene.leftover, bosses: battle.bosses, debts: debtsNow),
        payFun,
      );

      ledger
        ..allocate('alex', 'food', september, allocationsForChoice(food.leftover, payFun))
        ..allocate('alex', 'hygiene', september, allocationsForChoice(hygiene.leftover, payFun));
      final after = reduce(ledger.events, asOf: ritualInstant);

      expect(firstHit.landsCents, 3000);
      expect(secondHit.landsCents, 2000, reason: 'only what is still owed');
      expect(secondHit.completesTarget, isTrue);
      expect(after.outstandingOverbudgetsFor('alex'), isEmpty);
      expect(secondHit.toPersonalCents, after.vaultOf('alex') - household.vaultOf('alex'));
      // The stale preview against the ritual's original debt over-promised.
      expect(previewSpoilsChoice(hygiene.leftover, payFun).landsCents, 4000);
    });

    test('a goal boss carries its progress into the next preview', () {
      final (household, ritual) = ritualFixture();
      final battle = MonthEndBattle.from(ritual, household)!;
      final boss = battle.bosses.single;
      final nearlyDone = boss.afterLanding(boss.targetCents - 100);
      final weapon = battle.weapons.first;
      final choice = SpoilsChoice(SpoilsMove.goal, questId: boss.questId);
      final current = leftoverAgainst(weapon.leftover, bosses: [nearlyDone], debts: const []);
      expect(current.questOptions.single.totalContributedCents, nearlyDone.progressCents);
      expect(previewSpoilsChoice(current, choice).completesTarget, isTrue);
      expect(previewSpoilsChoice(weapon.leftover, choice).completesTarget, isFalse);
    });

    test('targets the battle does not track are left as they are', () {
      final (household, ritual) = ritualFixture();
      final weapon = MonthEndBattle.from(ritual, household)!.weapons.first;
      final same = leftoverAgainst(weapon.leftover, bosses: const [], debts: const []);
      expect(same.questOptions.single.totalContributedCents, weapon.leftover.questOptions.single.totalContributedCents);
      expect(same.leftoverCents, weapon.leftover.leftoverCents);
    });
  });

  group("the battle follows the reducer's ritual order", () {
    const september = Month(2026, 9);
    const payFun = SpoilsChoice(SpoilsMove.debt, overbudgetSliceId: 'fun');

    test('fun categories come first, then important, then necessities, by id', () {
      final ordered = [
        (priority: SlicePriority.necessity, sliceId: 'a'),
        (priority: SlicePriority.important, sliceId: 'c'),
        (priority: SlicePriority.fun, sliceId: 'z'),
        (priority: SlicePriority.important, sliceId: 'b'),
      ]..sort(compareRitualOrder);
      expect(ordered.map((entry) => entry.sliceId), ['z', 'b', 'c', 'a']);
    });

    test('a matched and a non-matching leftover paying one debt: summed previews equal the reducer', () {
      final ledger = mixedPairOneDebtLedger();
      final household = reduce(ledger.events, asOf: ritualInstant);
      final ritual = ritualOn(household)!;
      expect(ritual.sliceLeftovers.map((leftover) => leftover.sliceId), ['arcade', 'snacks'], reason: 'by name');
      final battle = MonthEndBattle.from(ritual, household)!;
      expect(battle.weapons.map((weapon) => weapon.sliceId), ['snacks', 'arcade'], reason: 'fun resolves first');
      expect(battle.debts.single.outstandingCents, 5000);

      // Play the battle the way the dungeon does: each weapon previewed
      // against what the earlier ones left.
      var debts = battle.debts;
      var taxCents = 0;
      var toPersonalCents = 0;
      for (final weapon in battle.weapons) {
        final preview = previewSpoilsChoice(leftoverAgainst(weapon.leftover, bosses: battle.bosses, debts: debts), payFun);
        taxCents += preview.taxCents;
        toPersonalCents += preview.toPersonalCents;
        debts = [for (final debt in debts) debt.afterLanding(preview.landsCents)];
      }

      // Written in name order, as a sheet might: the reducer reorders anyway.
      for (final leftover in ritual.sliceLeftovers) {
        ledger.allocate('alex', leftover.sliceId, september, allocationsForChoice(leftover, payFun));
      }
      final after = reduce(ledger.events, asOf: ritualInstant);

      expect(debts.single.outstandingCents, 0);
      expect(after.outstandingOverbudgetsFor('alex'), isEmpty);
      expect(taxCents, after.warChest.balanceCents - household.warChest.balanceCents);
      expect(toPersonalCents, after.vaultOf('alex') - household.vaultOf('alex'));
      // Snacks' $30 pays $24 after the 20% general rate; Arcade's matched $40
      // pays the last $26 untaxed and its $14 excess pays 20% on the way.
      expect(taxCents, 600 + 280);
      expect(toPersonalCents, 1120);
    });
  });
}
