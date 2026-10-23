/// The month-end ritual as a battle: each category's leftover is a weapon
/// worth exactly its value, goal bosses have the amount still to save as
/// HP, OVERBUDGET debts are monsters. Every number comes from the spoils
/// ritual and the shared move module; nothing here computes money.
/// Pure Dart, zero Flutter imports.
library;

import '../../domain/state.dart';
import '../../domain/value_types.dart';
import '../../features/spoils/spoils_model.dart';
import '../../features/spoils/spoils_move.dart';
import '../assets/asset_key.dart';

class BattleWeapon {
  const BattleWeapon({required this.leftover, required this.defaultChoice});

  final SliceLeftover leftover;
  final SpoilsChoice defaultChoice;

  String get sliceId => leftover.sliceId;
  String get name => leftover.name;
  int get valueCents => leftover.leftoverCents;
}

class GoalBoss {
  const GoalBoss({
    required this.questId,
    required this.name,
    required this.targetCents,
    required this.progressCents,
    required this.spriteKey,
    required this.shared,
    this.pictureSha256,
  });

  final String questId;
  final String name;
  final int targetCents;
  final int progressCents;
  final AssetKey spriteKey;
  final bool shared;
  final String? pictureSha256;

  int get remainingCents => progressCents >= targetCents ? 0 : targetCents - progressCents;

  double get revealFraction => targetCents <= 0 ? 1 : (progressCents / targetCents).clamp(0, 1).toDouble();

  /// The boss after [landedCents] reach it (a negative amount lands as 0).
  GoalBoss afterLanding(int landedCents) => GoalBoss(
        questId: questId,
        name: name,
        targetCents: targetCents,
        progressCents: progressCents + (landedCents < 0 ? 0 : landedCents),
        spriteKey: spriteKey,
        shared: shared,
        pictureSha256: pictureSha256,
      );
}

class DebtMonster {
  const DebtMonster({required this.sliceId, required this.name, required this.outstandingCents});

  final String sliceId;
  final String name;
  final int outstandingCents;

  AssetKey get spriteKey => const AssetKey('boss', 'overbudget');

  /// The monster after [landedCents] reach it (a negative amount lands as 0).
  DebtMonster afterLanding(int landedCents) => DebtMonster(
        sliceId: sliceId,
        name: name,
        outstandingCents: landedCents <= 0
            ? outstandingCents
            : landedCents >= outstandingCents
                ? 0
                : outstandingCents - landedCents,
      );
}

/// [leftover] with its goal and debt options showing where [bosses] and
/// [debts] stand now, after earlier weapons in this battle hit them. The
/// allocations land in the ledger in turn order, so previewing a later
/// weapon against these current amounts matches what the reducer does; the
/// ritual's own options still carry the amounts from before the battle.
/// Options the battle does not track are left as they are.
SliceLeftover leftoverAgainst(
  SliceLeftover leftover, {
  required List<GoalBoss> bosses,
  required List<DebtMonster> debts,
}) {
  final progressByQuest = {for (final boss in bosses) boss.questId: boss.progressCents};
  final owedBySlice = {for (final debt in debts) debt.sliceId: debt.outstandingCents};
  return SliceLeftover(
    sliceId: leftover.sliceId,
    name: leftover.name,
    leftoverCents: leftover.leftoverCents,
    poolTithePct: leftover.poolTithePct,
    defaultPolicy: leftover.defaultPolicy,
    questOptions: [
      for (final option in leftover.questOptions)
        switch (progressByQuest[option.questId]) {
          null => option,
          final progress => QuestOption(
              questId: option.questId,
              name: option.name,
              balanceCents: option.balanceCents + progress - option.totalContributedCents,
              targetCents: option.targetCents,
              totalContributedCents: progress,
              mainCategoryId: option.mainCategoryId,
            ),
        },
    ],
    overbudgetOptions: [
      for (final option in leftover.overbudgetOptions)
        switch (owedBySlice[option.sliceId]) {
          null => option,
          final owed => OverbudgetOption(
              sliceId: option.sliceId,
              name: option.name,
              outstandingCents: owed,
              mainCategoryId: option.mainCategoryId,
              provisions: option.provisions,
            ),
        },
    ],
    priority: leftover.priority,
    mainCategoryId: leftover.mainCategoryId,
    petName: leftover.petName,
    generalRatePct: leftover.generalRatePct,
    savings: leftover.savings,
  );
}

class MonthEndBattle {
  const MonthEndBattle({
    required this.ritual,
    required this.weapons,
    required this.bosses,
    required this.debts,
  });

  final SpoilsRitual ritual;
  final List<BattleWeapon> weapons;
  final List<GoalBoss> bosses;
  final List<DebtMonster> debts;

  List<VariableTally> get upkeep => ritual.variableTallies;
  List<GroupFlow> get groupFlows => ritual.groupFlows;

  static MonthEndBattle? from(SpoilsRitual? ritual, HouseholdState household) {
    if (ritual == null) return null;
    final bosses = <String, GoalBoss>{};
    final debts = <String, DebtMonster>{};
    for (final leftover in ritual.sliceLeftovers) {
      for (final option in leftover.questOptions) {
        bosses.putIfAbsent(option.questId, () => _bossFor(option, household));
      }
      for (final option in leftover.overbudgetOptions) {
        debts.putIfAbsent(option.sliceId,
            () => DebtMonster(sliceId: option.sliceId, name: option.name, outstandingCents: option.outstandingCents));
      }
    }
    return MonthEndBattle(
      ritual: ritual,
      weapons: List.unmodifiable([
        for (final leftover in ritual.sliceLeftovers)
          BattleWeapon(leftover: leftover, defaultChoice: defaultSpoilsChoice(leftover)),
      ]),
      bosses: List.unmodifiable(bosses.values),
      debts: List.unmodifiable(debts.values),
    );
  }

  static GoalBoss _bossFor(QuestOption option, HouseholdState household) {
    final quest = household.quests[option.questId];
    final categoryName = option.mainCategoryId == null ? null : household.mainCategories[option.mainCategoryId]?.name;
    final variant = categoryName == null
        ? AssetKey.defaultVariant
        : categoryName.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');
    return GoalBoss(
      questId: option.questId,
      name: option.name,
      targetCents: option.targetCents,
      progressCents: option.totalContributedCents,
      spriteKey: AssetKey('boss', 'goal', variant),
      shared: quest?.ownership is SharedParty,
      pictureSha256: quest?.customSpriteSha256,
    );
  }

  SliceLeftover leftoverFor(String sliceId) =>
      ritual.sliceLeftovers.firstWhere((leftover) => leftover.sliceId == sliceId);

  /// The confirmed ritual: an actual for every variable bill (the estimate
  /// when none was entered) and one choice's allocations per category.
  ///
  /// This carries the allowance choice only; it does not express the
  /// savings-rules move of a category's saved balance (`source: savings`).
  SpoilsResult resultFor({required Map<String, SpoilsChoice> choices, required Map<String, int> actualsByExpenseId}) =>
      SpoilsResult(
        tallies: [
          for (final tally in ritual.variableTallies)
            TallyResult(expenseId: tally.expenseId, actualCents: actualsByExpenseId[tally.expenseId] ?? tally.estimateCents),
        ],
        allocations: [
          for (final weapon in weapons)
            SliceAllocationResult(
              sliceId: weapon.sliceId,
              allocations: allocationsForChoice(weapon.leftover, choices[weapon.sliceId] ?? weapon.defaultChoice),
            ),
        ],
      );
}
