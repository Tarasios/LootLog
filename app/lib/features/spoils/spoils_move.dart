/// The month-end choice for one category's leftover, shared by every surface
/// that divides leftovers (the Standard sheet, the text battle, the dungeon):
/// which move, the allocations it writes, and a preview computed with the
/// reducer's own math. Pure Dart, zero Flutter imports.
library;

import '../../domain/pools.dart';
import '../../domain/value_types.dart';
import 'spoils_model.dart';

/// Where the whole leftover goes.
enum SpoilsMove {
  /// Keep it in the category (next month's limit, or category savings under
  /// the savings rules).
  carry,

  /// To the owner's personal money (general savings under the savings rules).
  bank,

  /// Toward a savings goal.
  goal,

  /// Toward an OVERBUDGET debt.
  debt,
}

class SpoilsChoice {
  const SpoilsChoice(this.move, {this.questId, this.overbudgetSliceId});

  final SpoilsMove move;
  final String? questId;
  final String? overbudgetSliceId;

  SpoilsChoice copyWith({SpoilsMove? move, String? questId, String? overbudgetSliceId}) => SpoilsChoice(
        move ?? this.move,
        questId: questId ?? this.questId,
        overbudgetSliceId: overbudgetSliceId ?? this.overbudgetSliceId,
      );

  @override
  bool operator ==(Object other) =>
      other is SpoilsChoice &&
      other.move == move &&
      other.questId == questId &&
      other.overbudgetSliceId == overbudgetSliceId;

  @override
  int get hashCode => Object.hash(move, questId, overbudgetSliceId);
}

/// What the ritual pre-selects: an outstanding debt first (CLAUDE.md: the UI
/// pre-selects paying it), otherwise the category's configured default.
SpoilsChoice defaultSpoilsChoice(SliceLeftover leftover) {
  if (leftover.overbudgetOptions.isNotEmpty) {
    return SpoilsChoice(SpoilsMove.debt, overbudgetSliceId: leftover.overbudgetOptions.first.sliceId);
  }
  final firstQuestId = leftover.questOptions.isEmpty ? null : leftover.questOptions.first.questId;
  return switch (leftover.defaultPolicy) {
    CarryInSlice() => SpoilsChoice(SpoilsMove.carry, questId: firstQuestId),
    QuestDestination(:final questId) => SpoilsChoice(SpoilsMove.goal, questId: questId),
    _ => SpoilsChoice(SpoilsMove.bank, questId: firstQuestId),
  };
}

QuestOption? _questFor(SliceLeftover leftover, String? questId) {
  for (final option in leftover.questOptions) {
    if (option.questId == questId) return option;
  }
  return null;
}

OverbudgetOption? _debtFor(SliceLeftover leftover, String? sliceId) {
  for (final option in leftover.overbudgetOptions) {
    if (option.sliceId == sliceId) return option;
  }
  return leftover.overbudgetOptions.isEmpty ? null : leftover.overbudgetOptions.first;
}

/// The allocations [choice] writes. They always sum to the whole leftover; a
/// goal or debt choice with nothing to target banks the leftover instead. A
/// debt payment is one whole-leftover line: the reducer pays no more than the
/// debt needs and sends the rest to personal money.
List<Allocation> allocationsForChoice(SliceLeftover leftover, SpoilsChoice choice) {
  final amount = leftover.leftoverCents;
  final LeftoverDestination destination = switch (choice.move) {
    SpoilsMove.carry => const CarryInSlice(),
    SpoilsMove.bank => const Discretionary(),
    SpoilsMove.goal => _questFor(leftover, choice.questId) == null
        ? const Discretionary()
        : QuestDestination(choice.questId!),
    SpoilsMove.debt => switch (_debtFor(leftover, choice.overbudgetSliceId)) {
        null => const Discretionary(),
        final debt => OverbudgetPayment(debt.sliceId),
      },
  };
  return [Allocation(destination: destination, amountCents: amount)];
}

/// A recorded variable actual, part of the confirmed result.
class TallyResult {
  const TallyResult({required this.expenseId, required this.actualCents});
  final String expenseId;
  final int actualCents;
}

/// A confirmed per-slice allocation, part of the result.
class SliceAllocationResult {
  const SliceAllocationResult({
    required this.sliceId,
    required this.allocations,
  });
  final String sliceId;
  final List<Allocation> allocations;
}

/// Everything the ritual produces on confirm.
class SpoilsResult {
  const SpoilsResult({required this.tallies, required this.allocations});
  final List<TallyResult> tallies;
  final List<SliceAllocationResult> allocations;
}

/// What one choice does, in the reducer's numbers.
class SpoilsMovePreview {
  const SpoilsMovePreview({
    required this.landsCents,
    required this.taxCents,
    this.toPersonalCents = 0,
    this.targetRemainingAfterCents,
    this.completesTarget = false,
    this.matched = false,
  });

  /// What reaches the destination (the goal's progress, the debt paid, the
  /// category or personal money).
  final int landsCents;

  /// What goes to the war chest / shared savings on the way.
  final int taxCents;

  /// The excess of a debt payment that lands in personal money.
  final int toPersonalCents;

  /// The goal's or debt's remaining amount after this move (null for carry
  /// and bank).
  final int? targetRemainingAfterCents;

  /// The move completes the goal or clears the debt.
  final bool completesTarget;

  /// The category matched the target's main category (untaxed).
  final bool matched;
}

SpoilsMovePreview previewSpoilsChoice(SliceLeftover leftover, SpoilsChoice choice) {
  final amount = leftover.leftoverCents;
  if (leftover.savingsRules) return _previewUnderSavingsRules(leftover, choice, amount);
  switch (choice.move) {
    case SpoilsMove.carry:
      return SpoilsMovePreview(landsCents: amount, taxCents: 0);
    case SpoilsMove.bank:
      final split = previewDiscretionary(amount, leftover.poolTithePct);
      return SpoilsMovePreview(landsCents: split.vaultCents, taxCents: split.titheCents);
    case SpoilsMove.goal:
      final quest = _questFor(leftover, choice.questId);
      if (quest == null) {
        return previewSpoilsChoice(leftover, choice.copyWith(move: SpoilsMove.bank));
      }
      final split = previewQuestAttack(amount, leftover.poolTithePct,
          sliceMainCategoryId: leftover.mainCategoryId, questMainCategoryId: quest.mainCategoryId);
      return _goalPreview(quest, split.damageCents, split.titheCents, split.matched);
    case SpoilsMove.debt:
      final debt = _debtFor(leftover, choice.overbudgetSliceId);
      if (debt == null) {
        return previewSpoilsChoice(leftover, choice.copyWith(move: SpoilsMove.bank));
      }
      final payment = previewOverbudgetPayment(amount, leftover.poolTithePct,
          outstandingCents: debt.outstandingCents,
          sliceMainCategoryId: leftover.mainCategoryId,
          targetMainCategoryId: debt.mainCategoryId);
      return SpoilsMovePreview(
        landsCents: payment.payCents,
        taxCents: payment.titheCents + payment.excessTitheCents,
        toPersonalCents: payment.toVaultCents,
        targetRemainingAfterCents: debt.outstandingCents - payment.payCents,
        completesTarget: payment.payCents >= debt.outstandingCents,
        matched: payment.matched,
      );
  }
}

SpoilsMovePreview _goalPreview(QuestOption quest, int landsCents, int taxCents, bool matched) {
  final after = quest.totalContributedCents + landsCents;
  final remaining = quest.targetCents - after;
  return SpoilsMovePreview(
    landsCents: landsCents,
    taxCents: taxCents,
    targetRemainingAfterCents: remaining < 0 ? 0 : remaining,
    completesTarget: after >= quest.targetCents,
    matched: matched,
  );
}

SpoilsMovePreview _previewUnderSavingsRules(SliceLeftover leftover, SpoilsChoice choice, int amount) {
  final from = TaxedBalance(amount);
  final generalPct = leftover.generalRatePct!;
  switch (choice.move) {
    case SpoilsMove.carry:
      final move = previewMove(from, amount, leftover.poolTithePct);
      return SpoilsMovePreview(landsCents: move.keepCents, taxCents: move.taxCents);
    case SpoilsMove.bank:
      final move = previewMove(from, amount, generalPct);
      return SpoilsMovePreview(landsCents: move.keepCents, taxCents: move.taxCents);
    case SpoilsMove.goal:
      final quest = _questFor(leftover, choice.questId);
      if (quest == null) {
        return _previewUnderSavingsRules(leftover, choice.copyWith(move: SpoilsMove.bank), amount);
      }
      final rate = savingsRateFor(QuestDestination(quest.questId),
          carryPct: leftover.poolTithePct,
          generalPct: generalPct,
          sliceMainCategoryId: leftover.mainCategoryId,
          destMainCategoryId: quest.mainCategoryId);
      final move = previewMove(from, amount, rate);
      final matched = quest.mainCategoryId != null && quest.mainCategoryId == leftover.mainCategoryId;
      return _goalPreview(quest, move.keepCents, move.taxCents, matched);
    case SpoilsMove.debt:
      final debt = _debtFor(leftover, choice.overbudgetSliceId);
      if (debt == null) {
        return _previewUnderSavingsRules(leftover, choice.copyWith(move: SpoilsMove.bank), amount);
      }
      final rate = savingsRateFor(OverbudgetPayment(debt.sliceId),
          carryPct: leftover.poolTithePct,
          generalPct: generalPct,
          sliceMainCategoryId: leftover.mainCategoryId,
          destMainCategoryId: debt.mainCategoryId,
          provisions: debt.provisions);
      final payment = previewSavingsOverbudget(from, amount,
          ratePct: rate, generalPct: generalPct, outstandingCents: debt.outstandingCents);
      return SpoilsMovePreview(
        landsCents: payment.payCents,
        taxCents: payment.titheCents + payment.excessTitheCents,
        toPersonalCents: payment.toVaultCents,
        targetRemainingAfterCents: debt.outstandingCents - payment.payCents,
        completesTarget: payment.payCents >= debt.outstandingCents,
        matched: payment.matched,
      );
  }
}
