import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/features/spoils/spoils_move.dart';
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
}
