/// What a purchase is short by, and the ways to cover it (savings rules).
///
/// Pure view-model: derived from [HouseholdState] *before* the purchase is
/// saved, so quick entry can offer cover only when it's actually needed and
/// everyday entry stays two taps. Tax previews come from `pools.dart`; nothing
/// here moves money.
library;

import '../../domain/pools.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';

/// One category-savings pool that can top up a quest-goal purchase.
class SavingsSource {
  const SavingsSource({
    required this.sliceId,
    required this.name,
    required this.balanceCents,
    required this.moveCents,
    required this.taxCents,
    required this.deliveredCents,
  });

  final String sliceId;
  final String name;
  final int balanceCents;

  /// What leaves the category savings to cover the gap (capped at its balance).
  final int moveCents;

  /// The difference tax that goes to shared savings on the way.
  final int taxCents;

  /// What lands on the goal (`moveCents − taxCents`).
  final int deliveredCents;
}

/// A purchase that exceeds what its target has available.
class ShortfallOptions {
  const ShortfallOptions({
    required this.shortCents,
    required this.generalAvailableCents,
    required this.savingsSources,
    required this.canBorrow,
    this.sliceId,
    this.sliceName,
    this.questId,
  });

  final int shortCents;

  /// The purchaser's general savings (their vault).
  final int generalAvailableCents;

  /// Category savings that can top up a quest-goal purchase.
  final List<SavingsSource> savingsSources;

  /// Whether borrowing from future months is offered (personal categories).
  final bool canBorrow;

  /// The personal category being bought from, for borrowing.
  final String? sliceId;
  final String? sliceName;

  /// The quest whose goal is being bought.
  final String? questId;

  bool get generalCoversIt => generalAvailableCents >= shortCents;
}

/// The shortfall for buying [amountCents] against [target] at [at], or null
/// when nothing is short or the savings rules don't apply to that month.
/// Only the purchaser's own personal categories and quest goals can be short.
ShortfallOptions? shortfallFor(
  HouseholdState state, {
  required String meUserId,
  required ChargeTarget target,
  required int amountCents,
  required DateTime at,
}) {
  final month = Month.fromInstant(at);
  final rules = state.savingsRules;
  if (rules == null || !rules.appliesTo(month) || amountCents <= 0) {
    return null;
  }
  final general = state.vaultOf(meUserId);

  switch (target) {
    case SliceCharge(:final sliceId):
      final cfg = state.slices[sliceId];
      if (cfg == null || cfg.isGroup || cfg.ownerUserId != meUserId) {
        return null;
      }
      final sm = state.sliceMonth(sliceId, month);
      final allowance = sm?.effectiveLimitCents ?? cfg.baseEffectiveLimitCents;
      final usedAllowance = sm == null
          ? 0
          : sm.spentCents - sm.coveredCents - sm.fromSavingsCents;
      final freeAllowance = allowance > usedAllowance
          ? allowance - usedAllowance
          : 0;
      final savings =
          sm?.savingsCents ?? state.categorySavings[sliceId]?.balanceCents ?? 0;
      final short = amountCents - freeAllowance - savings;
      if (short <= 0) return null;
      return ShortfallOptions(
        shortCents: short,
        generalAvailableCents: general,
        savingsSources: const [],
        canBorrow: true,
        sliceId: sliceId,
        sliceName: cfg.name,
      );

    case QuestCharge(:final questId):
      final quest = state.quests[questId];
      if (quest == null || quest.completed || quest.abandoned) return null;
      final short = amountCents - quest.balanceCents;
      if (short <= 0) return null;
      final rate = rules.generalRateFor(month);
      final sources = <SavingsSource>[];
      for (final cfg in state.slices.values) {
        if (cfg.isGroup || cfg.ownerUserId != meUserId) continue;
        final pool = state.categorySavings[cfg.sliceId] ?? TaxedBalance.zero;
        if (pool.balanceCents <= 0) continue;
        final matches =
            quest.mainCategoryId != null &&
            quest.mainCategoryId == cfg.mainCategoryId;
        final destRate = matches ? 0 : rate;
        final move = grossToDeliver(pool, short, destRate);
        final r = moveTaxed(pool, move, destRate);
        sources.add(
          SavingsSource(
            sliceId: cfg.sliceId,
            name: cfg.name,
            balanceCents: pool.balanceCents,
            moveCents: move,
            taxCents: r.topUpCents,
            deliveredCents: r.delivered.balanceCents,
          ),
        );
      }
      sources.sort((a, b) => a.name.compareTo(b.name));
      return ShortfallOptions(
        shortCents: short,
        generalAvailableCents: general,
        savingsSources: sources,
        canBorrow: false,
        questId: questId,
      );

    case VaultCharge():
    case EmergencyCharge():
    case VacationCharge():
      return null;
  }
}
