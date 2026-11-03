/// The town's quest board: the goals, OVERBUDGETs, writs awaiting a
/// signature, this month's category monsters and the latest purchases, as one
/// read model the Adventure town renders.
///
/// Every figure is selected from the ledger read models the Standard
/// dashboard already uses ([buildSliceRings], [buildQuestCards],
/// [buildOverbudgetCards], [buildPendingAdvances]), so both modes always show
/// identical numbers; this file only picks, labels and orders them.
/// Pure Dart, zero Flutter imports.
library;

import '../../../domain/money.dart';
import '../../../domain/state.dart';
import '../../../domain/time.dart';
import '../../../domain/value_types.dart';
import '../../../features/dashboard/dashboard_model.dart';
import '../../../features/warchest/advance_model.dart';
import '../../../ui/glossary.dart';

/// A savings goal still being chased (a goal boss).
class QuestBoardGoal {
  const QuestBoardGoal({
    required this.questId,
    required this.name,
    required this.percent,
    required this.remaining,
    required this.target,
    required this.shared,
    this.pictureSha256,
  });

  final String questId;
  final String name;

  /// Progress toward [target], 0–100, rounded down: 100 only once reached.
  final int percent;

  /// What's still needed to reach [target].
  final Money remaining;
  final Money target;
  final bool shared;

  /// The goal's own picture, revealed as it fills; null for the default boss.
  final String? pictureSha256;
}

/// One category this month, as a monster on the board.
class QuestBoardMonster {
  const QuestBoardMonster({
    required this.categoryId,
    required this.name,
    required this.remaining,
    required this.limit,
    required this.enraged,
    required this.group,
    required this.colorArgb,
  });

  final String categoryId;
  final String name;

  /// What's left to spend this month (zero once the limit is passed).
  final Money remaining;

  /// This month's effective limit.
  final Money limit;

  /// Spending went past the limit: drama, never shame.
  final bool enraged;

  /// A household (group) category rather than one adult's.
  final bool group;

  /// The main category's colour (Misc's when the category has none).
  final int colorArgb;
}

/// An OVERBUDGET: overspending still to be repaid on a category.
class QuestBoardDebt {
  const QuestBoardDebt({
    required this.categoryId,
    required this.name,
    required this.outstanding,
  });

  final String categoryId;
  final String name;
  final Money outstanding;
}

/// One recent purchase.
class QuestBoardEntry {
  const QuestBoardEntry({
    required this.label,
    required this.amount,
    required this.occurredAt,
  });

  /// The merchant when one was recorded, otherwise what it was charged to.
  final String label;
  final Money amount;
  final DateTime occurredAt;
}

/// Everything the town's quest board shows, built by [QuestBoardView.from]
/// on every read from the household state; never stored.
class QuestBoardView {
  const QuestBoardView({
    this.goals = const [],
    this.debts = const [],
    this.pendingWrits = 0,
    this.monsters = const [],
    this.recent = const [],
  });

  /// How many purchases [recent] holds at most.
  static const int recentLimit = 5;

  /// Goals not yet reached, by percent descending (name breaks ties).
  final List<QuestBoardGoal> goals;

  /// Outstanding OVERBUDGETs, this device's adult's first.
  final List<QuestBoardDebt> debts;

  /// War-chest withdrawals and allowance advances waiting for another
  /// adult's signature, household-wide.
  final int pendingWrits;

  /// This month's categories: mine first, then group ones, then other
  /// adults' (left out when the visibility preference hides them).
  final List<QuestBoardMonster> monsters;

  /// The [recentLimit] newest purchases, newest first.
  final List<QuestBoardEntry> recent;

  static QuestBoardView from(
    HouseholdState state, {
    required String meId,
    required Month month,
    required bool showOtherAdults,
    required Map<String, String> names,
  }) {
    final rings = buildSliceRings(
      state,
      meUserId: meId,
      month: month,
      userNames: names,
      includeOtherAdults: showOtherAdults,
    );
    return QuestBoardView(
      goals: List.unmodifiable(_goals(state, names)),
      debts: List.unmodifiable([
        for (final debt in buildOverbudgetCards(
          state,
          meUserId: meId,
          userNames: names,
          includeOtherAdults: showOtherAdults,
        ))
          QuestBoardDebt(
            categoryId: debt.sliceId,
            name: debt.categoryName,
            outstanding: Money(debt.outstandingCents),
          ),
      ]),
      pendingWrits:
          _pendingWithdrawalCount(state) +
          buildPendingAdvances(state, meUserId: meId, userNames: names).length,
      monsters: List.unmodifiable(_monsters(rings)),
      recent: List.unmodifiable(
        _recent(state, meId: meId, showOtherAdults: showOtherAdults),
      ),
    );
  }

  static List<QuestBoardGoal> _goals(
    HouseholdState state,
    Map<String, String> names,
  ) {
    final goals = [
      for (final card in buildQuestCards(state, userNames: names))
        if (!card.completed)
          QuestBoardGoal(
            questId: card.questId,
            name: card.name,
            percent: _percent(card),
            remaining: Money(card.remainingCents),
            target: Money(card.targetCents),
            shared: card.isShared,
            pictureSha256: state.quests[card.questId]?.customSpriteSha256,
          ),
    ];
    goals.sort((first, second) {
      final byPercent = second.percent.compareTo(first.percent);
      return byPercent != 0 ? byPercent : first.name.compareTo(second.name);
    });
    return goals;
  }

  /// Whole percent toward the target, rounded down like the guild hall's
  /// goal list so a goal only reads 100% once it is actually reached.
  static int _percent(QuestCard card) {
    if (card.completed) return 100;
    if (card.targetCents <= 0) return 0;
    return (card.totalContributedCents * 100 ~/ card.targetCents).clamp(0, 99);
  }

  static List<QuestBoardMonster> _monsters(List<SliceRing> rings) {
    // The dashboard lists other adults' categories before group ones; the
    // board puts the household's shared ones right after mine.
    int rank(SliceRing ring) => ring.mine ? 0 : (ring.isGroup ? 1 : 2);
    final ordered = [...rings]
      ..sort((first, second) {
        final byRank = rank(first).compareTo(rank(second));
        return byRank != 0 ? byRank : first.name.compareTo(second.name);
      });
    return [
      for (final ring in ordered)
        QuestBoardMonster(
          categoryId: ring.sliceId,
          name: ring.name,
          remaining: Money(ring.remainingCents),
          limit: Money(ring.effectiveLimitCents),
          enraged: ring.overspent,
          group: ring.isGroup,
          colorArgb: ring.mainCategoryColorArgb ?? _fallbackColorArgb,
        ),
    ];
  }

  /// Misc's colour, for a category with no main category.
  static final int _fallbackColorArgb = defaultMainCategories
      .firstWhere((main) => main.id == 'misc')
      .colorArgb;

  static int _pendingWithdrawalCount(HouseholdState state) => state
      .withdrawals
      .values
      .where((withdrawal) => withdrawal.status == WithdrawalStatus.pending)
      .length;

  static List<QuestBoardEntry> _recent(
    HouseholdState state, {
    required String meId,
    required bool showOtherAdults,
  }) {
    bool hidden(PurchaseState purchase) {
      if (showOtherAdults) return false;
      final target = purchase.target;
      // Only personal categories (and debts) are hidden by the toggle, so
      // other adults' vault, goal, reserve and trip purchases stay visible.
      if (target is! SliceCharge) return false;
      final category = state.slices[target.sliceId];
      return category != null &&
          !category.isGroup &&
          category.ownerUserId != meId;
    }

    final purchases =
        [
          for (final purchase in state.purchases.values)
            if (!purchase.voided && !hidden(purchase)) purchase,
        ]..sort((first, second) {
          final byTime = second.occurredAt.compareTo(first.occurredAt);
          return byTime != 0
              ? byTime
              : second.purchaseId.compareTo(first.purchaseId);
        });
    return [
      for (final purchase in purchases.take(recentLimit))
        QuestBoardEntry(
          label: _label(state, purchase),
          amount: Money(purchase.amountCents),
          occurredAt: purchase.occurredAt,
        ),
    ];
  }

  static String _label(HouseholdState state, PurchaseState purchase) {
    final merchant = purchase.merchant?.trim();
    if (merchant != null && merchant.isNotEmpty) return merchant;
    return switch (purchase.target) {
      SliceCharge(:final sliceId) => state.slices[sliceId]?.name ?? 'A budget',
      VaultCharge() => Glossary.capitalize(
        Glossary.vaultLabel(
          isAdventure: true,
          savingsRules: state.savingsRules != null,
        ),
      ),
      QuestCharge(:final questId) => state.quests[questId]?.name ?? 'A goal',
      EmergencyCharge(:final fundId) =>
        state.emergencyFunds[fundId]?.name ?? 'A reserve',
      VacationCharge(:final vacationId) =>
        state.vacations[vacationId]?.name ?? 'An expedition',
    };
  }
}
