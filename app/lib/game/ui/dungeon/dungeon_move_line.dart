/// The adventure log's line for one confirmed strike, in game voice, with the
/// real split: what landed where, the tithe that flew to the war chest, and
/// a goal that fell. The amounts are the shared move module's preview.
library;

import '../../../features/spoils/spoils_move.dart';
import '../../../ui/format.dart';
import '../../battle/month_end_battle.dart';
import 'dungeon_voice.dart';

/// The log line for [weapon] striking [choice], naming its target from
/// [bosses] and [debts] (the weapon itself when the target is unknown).
String dungeonMoveLine(
  DungeonVoice voice, {
  required String seed,
  required BattleWeapon weapon,
  required SpoilsChoice choice,
  required SpoilsMovePreview preview,
  required List<GoalBoss> bosses,
  required List<DebtMonster> debts,
}) {
  final amount = money(preview.landsCents);
  final bossName = bosses.where((boss) => boss.questId == choice.questId).firstOrNull?.name ?? weapon.name;
  final debtName = debts.where((debt) => debt.sliceId == choice.overbudgetSliceId).firstOrNull?.name ?? weapon.name;
  return [
    switch (choice.move) {
      SpoilsMove.goal => voice.line('hitGoal', seed: seed, fill: {'amount': amount, 'target': bossName}),
      SpoilsMove.debt => voice.line('hitDebt', seed: seed, fill: {'amount': amount, 'target': debtName}),
      SpoilsMove.bank => voice.line('bank', seed: seed, fill: {'amount': amount}),
      SpoilsMove.carry => voice.line('carry', seed: seed, fill: {'amount': amount, 'name': weapon.name}),
    },
    if (preview.taxCents > 0) voice.line('taxFlies', seed: seed, fill: {'amount': money(preview.taxCents)}),
    if (choice.move == SpoilsMove.goal && preview.completesTarget)
      voice.line('bossFalls', seed: seed, fill: {'target': bossName}),
  ].join(' ');
}
