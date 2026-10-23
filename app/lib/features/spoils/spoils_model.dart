/// The "dividing the spoils" month-close ritual, as a pure view-model derived
/// from [HouseholdState]. It answers: does the just-closed month still have
/// undecided personal-slice leftovers or untallied variable expenses, and if so,
/// what does the user need to decide before the grace period lapses and the
/// reducer applies each slice's default policy?
///
/// Pure Dart (Flutter-free). The sheet renders this; the screen turns the user's
/// choices into appended events.
library;

import '../../domain/money.dart';
import '../../domain/pools.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';

/// A variable recurring expense whose actual for the closed month has not been
/// recorded yet — step 1 of the ritual.
class VariableTally {
  const VariableTally({
    required this.expenseId,
    required this.name,
    required this.estimateCents,
    required this.isShared,
    this.ownerName,
  });

  final String expenseId;
  final String name;
  final int estimateCents;
  final bool isShared;
  final String? ownerName;
}

/// A quest the slice owner may attack with leftover.
class QuestOption {
  const QuestOption({
    required this.questId,
    required this.name,
    required this.balanceCents,
    required this.targetCents,
    required this.totalContributedCents,
    this.mainCategoryId,
  });

  final String questId;
  final String name;
  final int balanceCents;
  final int targetCents;
  final int totalContributedCents;

  /// The goal's main category; drives category-match tithing in the preview.
  final String? mainCategoryId;
}

/// An outstanding OVERBUDGET the slice owner can pay down with leftover.
class OverbudgetOption {
  const OverbudgetOption({
    required this.sliceId,
    required this.name,
    required this.outstandingCents,
    this.mainCategoryId,
    this.provisions = false,
  });

  final String sliceId;
  final String name;
  final int outstandingCents;

  /// A variable bill's top-up rather than an overspent category: paid untaxed.
  final bool provisions;

  /// The indebted category's main category; drives category-match tithing.
  final String? mainCategoryId;
}

/// One personal slice with an undecided leftover — step 2 of the ritual.
class SliceLeftover {
  const SliceLeftover({
    required this.sliceId,
    required this.name,
    required this.leftoverCents,
    required this.poolTithePct,
    required this.defaultPolicy,
    required this.questOptions,
    this.overbudgetOptions = const [],
    this.priority = SlicePriority.important,
    this.mainCategoryId,
    this.petName,
    this.generalRatePct,
    this.savings = TaxedBalance.zero,
  });

  final String sliceId;
  final String name;
  final int leftoverCents;

  /// The per-slice pool tithe (%), applied to the discretionary portion and to
  /// an attack on a quest whose main category does NOT match this category.
  final int poolTithePct;
  final LeftoverDestination defaultPolicy;
  final List<QuestOption> questOptions;

  /// The owner's outstanding OVERBUDGETs — when non-empty, paying them is the
  /// pushed (and default) move for this leftover.
  final List<OverbudgetOption> overbudgetOptions;

  /// This category's priority tag; a "fun" leftover is the suggested source
  /// when a necessity carries an OVERBUDGET.
  final SlicePriority priority;

  /// This category's main category; drives category-match tithing.
  final String? mainCategoryId;
  final String? petName;

  /// Non-null when the savings rules apply to this month: the general savings
  /// tax. [poolTithePct] is then this category's carry tax.
  final int? generalRatePct;

  /// Savings rules only: what's saved in this category at month end (and the
  /// tax it already paid) — it stays put unless the user moves it.
  final TaxedBalance savings;

  bool get savingsRules => generalRatePct != null;
}

/// A read-only line: group-slice leftover flowing to the war chest.
class GroupFlow {
  const GroupFlow({required this.name, required this.leftoverCents});
  final String name;
  final int leftoverCents;
}

/// A read-only line: an automatic emergency-fund contribution off the top.
class EmergencyContribLine {
  const EmergencyContribLine({
    required this.fundName,
    required this.amountCents,
  });
  final String fundName;
  final int amountCents;
}

/// The full ritual view-model for one closed month.
class SpoilsRitual {
  const SpoilsRitual({
    required this.month,
    required this.forUserId,
    required this.graceDeadline,
    required this.asOf,
    required this.variableTallies,
    required this.sliceLeftovers,
    required this.groupFlows,
    required this.emergencyContribs,
  });

  final Month month;
  final String forUserId;

  /// The instant at which, with no allocation, the default policy applies.
  final DateTime graceDeadline;
  final DateTime asOf;

  final List<VariableTally> variableTallies;
  final List<SliceLeftover> sliceLeftovers;
  final List<GroupFlow> groupFlows;
  final List<EmergencyContribLine> emergencyContribs;

  /// Time left before defaults apply (never negative).
  Duration get timeRemaining {
    final remaining = graceDeadline.difference(asOf);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whole days (rounded down) left in the grace window.
  int get daysRemaining => timeRemaining.inHours ~/ 24;

  /// There is something for the user to actually do.
  bool get isActionable =>
      variableTallies.isNotEmpty || sliceLeftovers.isNotEmpty;
}

/// Builds the ritual for the most recently closed month, or returns null when
/// the grace window has passed or there is nothing left to decide.
///
/// [meUserId] is the device owner: only *their* personal slices are actionable
/// (each user divides their own spoils on their own device).
SpoilsRitual? buildSpoilsRitual(
  HouseholdState state, {
  required String meUserId,
  required Map<String, String> userNames,
  DateTime? asOf,
}) {
  final now = (asOf ?? DateTime.now()).toUtc();
  final month = Month.fromInstant(now).prev();
  final deadline = month.endInstantUtc().add(
    Duration(days: state.settings.spoilsGraceDays),
  );

  // Past the grace window: the reducer has already applied defaults; the ritual
  // is no longer reopenable.
  if (now.isAfter(deadline)) {
    return null;
  }

  String? nameOf(String id) => userNames[id];

  // Step 1: variable recurring expenses active that month with no actual yet.
  final tallies = <VariableTally>[];
  for (final expense in state.recurringExpenses.values) {
    if (expense.kind != RecurringKind.variable) continue;
    if (!expense.activeIn(month)) continue;
    if (state.variableActualFor(expense.expenseId, month) != null) continue;
    tallies.add(
      VariableTally(
        expenseId: expense.expenseId,
        name: expense.name,
        estimateCents: expense.amountCents,
        isShared: expense.isShared,
        ownerName: expense.ownerUserId == null
            ? null
            : nameOf(expense.ownerUserId!),
      ),
    );
  }
  tallies.sort((first, second) => first.name.compareTo(second.name));

  // Quests this user can fund.
  final questOptions = <QuestOption>[];
  for (final quest in state.quests.values) {
    if (quest.completed || quest.abandoned) continue;
    final ownership = quest.ownership;
    final mine =
        ownership is SharedParty ||
        (ownership is PersonalParty && ownership.userId == meUserId);
    if (!mine) continue;
    questOptions.add(
      QuestOption(
        questId: quest.questId,
        name: quest.name,
        balanceCents: quest.balanceCents,
        targetCents: quest.targetCents,
        totalContributedCents: quest.totalContributedCents,
        mainCategoryId: quest.mainCategoryId,
      ),
    );
  }
  questOptions.sort((first, second) => first.name.compareTo(second.name));

  // My outstanding OVERBUDGETs, payable from any of my leftovers.
  final overbudgetOptions = <OverbudgetOption>[
    for (final debt in state.outstandingOverbudgetsFor(meUserId))
      OverbudgetOption(
        sliceId: debt.sliceId,
        name: debt.kind == DebtKind.provisions
            ? '${state.recurringExpenses[debt.sliceId.substring('provisions:'.length)]?.name ?? 'Bill'} top-up'
            : state.slices[debt.sliceId]?.name ?? debt.sliceId,
        outstandingCents: debt.outstandingCents,
        mainCategoryId: state.slices[debt.sliceId]?.mainCategoryId,
        provisions: debt.kind == DebtKind.provisions,
      ),
  ];

  // Under the savings rules the previews use the carry and general rates.
  final rules = state.savingsRules;
  final generalRate = rules != null && rules.appliesTo(month)
      ? rules.generalRateFor(month)
      : null;

  // Step 2: my personal slices with an unresolved leftover for that month.
  final leftovers = <SliceLeftover>[];
  final groupFlows = <GroupFlow>[];
  final emergencyByFund = <String, int>{};
  for (final sliceConfig in state.slices.values) {
    if (sliceConfig.createdMonth.isAfter(month)) continue;
    final sliceMonth = state.sliceMonth(sliceConfig.sliceId, month);

    if (sliceConfig.emergencyFundId != null &&
        sliceConfig.emergencyContributionCents > 0) {
      emergencyByFund[sliceConfig.emergencyFundId!] =
          (emergencyByFund[sliceConfig.emergencyFundId!] ?? 0) +
          sliceConfig.emergencyContributionCents;
    }

    if (sliceConfig.isGroup) {
      final leftover = sliceMonth?.leftoverCents ?? 0;
      if (leftover > 0) {
        groupFlows.add(
          GroupFlow(name: sliceConfig.name, leftoverCents: leftover),
        );
      }
      continue;
    }
    if (sliceConfig.ownerUserId != meUserId) continue;
    if (sliceMonth == null ||
        sliceMonth.resolved ||
        sliceMonth.leftoverCents <= 0) {
      continue;
    }
    leftovers.add(
      SliceLeftover(
        sliceId: sliceConfig.sliceId,
        name: sliceConfig.name,
        leftoverCents: sliceMonth.leftoverCents,
        poolTithePct: sliceConfig.poolTithePct,
        defaultPolicy: sliceConfig.defaultLeftoverPolicy,
        questOptions: questOptions,
        overbudgetOptions: overbudgetOptions,
        priority: sliceConfig.priority,
        mainCategoryId: sliceConfig.mainCategoryId,
        petName: sliceConfig.petId == null
            ? null
            : state.pets[sliceConfig.petId]?.name,
        generalRatePct: generalRate,
        savings: generalRate == null
            ? TaxedBalance.zero
            : TaxedBalance(
                sliceMonth.savingsCents,
                sliceMonth.savingsTaxPaidCents,
              ),
      ),
    );
  }
  leftovers.sort((first, second) => first.name.compareTo(second.name));
  groupFlows.sort((first, second) => first.name.compareTo(second.name));

  final emergencyContribs = <EmergencyContribLine>[
    for (final entry in emergencyByFund.entries)
      EmergencyContribLine(
        fundName: state.emergencyFunds[entry.key]?.name ?? 'Reserve',
        amountCents: entry.value,
      ),
  ]..sort((first, second) => first.fundName.compareTo(second.fundName));

  final ritual = SpoilsRitual(
    month: month,
    forUserId: meUserId,
    graceDeadline: deadline,
    asOf: now,
    variableTallies: tallies,
    sliceLeftovers: leftovers,
    groupFlows: groupFlows,
    emergencyContribs: emergencyContribs,
  );
  return ritual.isActionable ? ritual : null;
}

/// A single user-chosen allocation line for a slice, from the sheet.
class DraftAllocation {
  const DraftAllocation({required this.destination, required this.amountCents});
  final LeftoverDestination destination;
  final int amountCents;
}

/// Splits a discretionary [amountCents] into the vault remainder and the
/// war-chest tithe for a live preview. Floor rounding sends the floored tithe to
/// the chest; the rest is the user's — matching the reducer exactly.
({int vaultCents, int titheCents}) previewDiscretionary(
  int amountCents,
  int poolTithePct,
) {
  final split = Money.titheCents(amountCents, poolTithePct);
  return (vaultCents: split.remainderCents, titheCents: split.titheCents);
}

/// Splits an attack of [amountCents] from a category into the damage dealt to a
/// quest and the war-chest tithe, applying the category-match rule the reducer
/// uses: a match ([sliceMainCategoryId] == [questMainCategoryId], both non-null)
/// is untithed full damage; otherwise the source category's [poolTithePct] is
/// floored to the chest and the remainder is damage.
({int damageCents, int titheCents, bool matched}) previewQuestAttack(
  int amountCents,
  int poolTithePct, {
  required String? sliceMainCategoryId,
  required String? questMainCategoryId,
}) {
  final matched =
      questMainCategoryId != null && questMainCategoryId == sliceMainCategoryId;
  if (matched) {
    return (damageCents: amountCents, titheCents: 0, matched: true);
  }
  final split = Money.titheCents(amountCents, poolTithePct);
  return (
    damageCents: split.remainderCents,
    titheCents: split.titheCents,
    matched: false,
  );
}

/// Previews a whole-leftover OVERBUDGET payment exactly as the reducer will
/// apply it. Non-matching categories: the pool tithe comes off the whole
/// [amountCents] first, the post-tithe value pays up to [outstandingCents],
/// and the rest lands in the vault (already tithed). Matching categories: the
/// debt is paid at full value, and only the excess beyond the debt converts
/// to discretionary with the usual tithe. Either way the OVERBUDGET never
/// takes more than it needs.
({
  int payCents,
  int titheCents,
  int toVaultCents,
  int excessTitheCents,
  bool matched,
})
previewOverbudgetPayment(
  int amountCents,
  int poolTithePct, {
  required int outstandingCents,
  required String? sliceMainCategoryId,
  required String? targetMainCategoryId,
}) {
  final matched =
      targetMainCategoryId != null &&
      targetMainCategoryId == sliceMainCategoryId;
  if (matched) {
    final pay = amountCents < outstandingCents ? amountCents : outstandingCents;
    final excessSplit = Money.titheCents(amountCents - pay, poolTithePct);
    return (
      payCents: pay,
      titheCents: 0,
      toVaultCents: excessSplit.remainderCents,
      excessTitheCents: excessSplit.titheCents,
      matched: true,
    );
  }
  final split = Money.titheCents(amountCents, poolTithePct);
  final damage = split.remainderCents;
  final pay = damage < outstandingCents ? damage : outstandingCents;
  return (
    payCents: pay,
    titheCents: split.titheCents,
    toVaultCents: damage - pay,
    excessTitheCents: 0,
    matched: false,
  );
}

// ---- Savings rules previews -------------------------------------------------
// The same pools.dart math the reducer uses, so a preview always matches what
// gets appended.

/// Moving [amountCents] out of [from] to a destination taxed at [ratePct]:
/// what lands there and what goes to shared savings.
({int keepCents, int taxCents}) previewMove(
  TaxedBalance from,
  int amountCents,
  int ratePct,
) {
  final amount = amountCents < from.balanceCents
      ? amountCents
      : from.balanceCents;
  final move = moveTaxed(from, amount, ratePct);
  return (keepCents: move.delivered.balanceCents, taxCents: move.topUpCents);
}

/// The rate a month-end destination charges under the savings rules: saving in
/// the category costs its carry tax; general savings, a non-matching goal and
/// repaying another category's overspending cost the general rate; a matching
/// goal or debt, or a bill top-up, is untaxed.
int savingsRateFor(
  LeftoverDestination destination, {
  required int carryPct,
  required int generalPct,
  required String? sliceMainCategoryId,
  String? destMainCategoryId,
  bool provisions = false,
}) {
  final matches =
      destMainCategoryId != null && destMainCategoryId == sliceMainCategoryId;
  return switch (destination) {
    CarryInSlice() => carryPct,
    Discretionary() => generalPct,
    QuestDestination() => matches ? 0 : generalPct,
    OverbudgetPayment() => (matches || provisions) ? 0 : generalPct,
  };
}

/// A whole-amount debt payment under the savings rules, exactly as the reducer
/// applies it: the payment never takes more than the debt needs, and the
/// excess tops up to the general rate on its way to general savings.
({
  int payCents,
  int titheCents,
  int toVaultCents,
  int excessTitheCents,
  bool matched,
})
previewSavingsOverbudget(
  TaxedBalance from,
  int amountCents, {
  required int ratePct,
  required int generalPct,
  required int outstandingCents,
}) {
  final amount = amountCents < from.balanceCents
      ? amountCents
      : from.balanceCents;
  final move = moveTaxed(from, amount, ratePct);
  final delivered = move.delivered.balanceCents;
  final pay = delivered < outstandingCents ? delivered : outstandingCents;
  final excess = delivered - pay;
  var toVault = 0;
  var excessTax = 0;
  if (excess > 0) {
    final paid = delivered == 0
        ? 0
        : move.delivered.taxPaidCents * excess ~/ delivered;
    final toGeneral = moveTaxed(TaxedBalance(excess, paid), excess, generalPct);
    toVault = toGeneral.delivered.balanceCents;
    excessTax = toGeneral.topUpCents;
  }
  return (
    payCents: pay,
    titheCents: move.topUpCents,
    toVaultCents: toVault,
    excessTitheCents: excessTax,
    matched: ratePct == 0,
  );
}
