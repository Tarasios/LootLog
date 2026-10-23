/// The status-dashboard view-model: a single pure projection of
/// [HouseholdState] into the cards the dashboard renders. Building this in one
/// place keeps [DashboardView] a dumb, golden-testable widget and keeps every
/// number sourced from the reducer.
///
/// Pure Dart (Flutter-free).
library;

import '../../domain/event.dart';
import '../../domain/money.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';
import '../../ui/glossary.dart';
import '../networth/networth_model.dart';
import '../spoils/spoils_model.dart';
import '../vacation/vacation_dashboard.dart';
import '../warchest/advance_model.dart';

export '../warchest/advance_model.dart' show PendingAdvance;

/// The month hero: the household's income, spend, and remaining for the current
/// month — the headline "how are we doing this month" figures.
class MonthHero {
  const MonthHero({required this.incomeCents, required this.spentCents});

  final int incomeCents;
  final int spentCents;

  int get remainingCents => incomeCents - spentCents;
  bool get hasIncome => incomeCents > 0;
  bool get overBudget => spentCents > incomeCents;

  /// Fraction of income spent (0..1, clamped). With no income recorded, reads
  /// full once anything is spent.
  double get spentFraction {
    if (incomeCents <= 0) return spentCents > 0 ? 1 : 0;
    final fraction = spentCents / incomeCents;
    return fraction < 0 ? 0 : (fraction > 1 ? 1 : fraction);
  }
}

/// The net-worth summary card: the signed total and the recorded trend for a
/// sparkline. Sourced from tracked accounts only — never budget money.
class NetWorthSummary {
  const NetWorthSummary({
    required this.show,
    required this.totalCents,
    required this.assetsCents,
    required this.debtsCents,
    required this.series,
  });

  /// Whether the household has opted to show net worth at all.
  final bool show;
  final int totalCents;
  final int assetsCents;
  final int debtsCents;

  /// Recorded net-worth samples over time, oldest first.
  final List<BalancePoint> series;

  bool get hasAccounts =>
      assetsCents != 0 || debtsCents != 0 || series.isNotEmpty;
  bool get hasHistory => series.length >= 2;
}

/// One per-slice progress ring.
class SliceRing {
  const SliceRing({
    required this.sliceId,
    required this.name,
    required this.isGroup,
    required this.spentCents,
    required this.effectiveLimitCents,
    required this.overspendCents,
    required this.mine,
    this.lockedCents = 0,
    this.savingsCents = 0,
    this.ownerName,
    this.petName,
    this.mainCategoryColorArgb,
  });

  final String sliceId;
  final String name;
  final bool isGroup;
  final int spentCents;
  final int effectiveLimitCents;
  final int overspendCents;

  /// Funding withheld this month to repay earlier overspending; when > 0 the
  /// category is (partly or fully) locked.
  final int lockedCents;

  /// Savings rules only: what's saved inside this category right now.
  /// [spentCents] then counts only spending against this month's allowance —
  /// what savings, general savings or an advance paid for isn't included.
  final int savingsCents;

  /// Whether a personal slice belongs to the device owner.
  final bool mine;
  final String? ownerName;
  final String? petName;

  /// The colour of this category's main category, for colour-coded tiles. Null
  /// when the category has no main category assigned.
  final int? mainCategoryColorArgb;

  bool get overspent => overspendCents > 0;

  int get remainingCents {
    final remaining = effectiveLimitCents - spentCents;
    return remaining < 0 ? 0 : remaining;
  }

  /// Consumed fraction for the ring (0..1); a zero-limit slice reads full once
  /// anything is spent.
  double get fraction {
    if (effectiveLimitCents <= 0) return spentCents > 0 ? 1 : 0;
    final fraction = spentCents / effectiveLimitCents;
    return fraction < 0 ? 0 : (fraction > 1 ? 1 : fraction);
  }

  int get pctSpent => (fraction * 100).round();
}

/// One equipment-maintenance (recurring expense) line.
class MaintenanceItem {
  const MaintenanceItem({
    required this.name,
    required this.kind,
    required this.amountCents,
    required this.isShared,
    required this.awaitingTally,
    this.ownerName,
  });

  final String name;
  final RecurringKind kind;

  /// The amount charged this month (actual if recorded, else estimate/fixed).
  final int amountCents;
  final bool isShared;

  /// A variable expense whose closed-month actual has not been recorded.
  final bool awaitingTally;
  final String? ownerName;

  bool get isVariable => kind == RecurringKind.variable;
}

/// One line in the upcoming-payments strip: a recurring bill and when it lands.
class UpcomingPayment {
  const UpcomingPayment({
    required this.name,
    required this.amountCents,
    required this.isAnnual,
    required this.isShared,
    required this.dueDay,
    required this.daysUntilDue,
    this.dueMonth,
  });

  final String name;

  /// The real bill amount (the annual figure for an annual expense).
  final int amountCents;
  final bool isAnnual;
  final bool isShared;
  final int dueDay;
  final int? dueMonth;

  /// Whole days until the next occurrence of this bill.
  final int daysUntilDue;
}

/// The vault (gold pouch) card.
class VaultCard {
  const VaultCard({
    required this.balanceCents,
    required this.inconsistent,
    required this.projectedLeftoverCents,
    required this.projectedVaultCents,
  });

  final int balanceCents;
  final bool inconsistent;

  /// Sum of current, still-open leftovers across my personal slices.
  final int projectedLeftoverCents;

  /// What those leftovers would add to my vault if all converted to
  /// discretionary at each slice's tithe — the "projected spoils" figure.
  final int projectedVaultCents;
}

/// A contributor's share of a shared quest.
class ContributorShare {
  const ContributorShare({required this.name, required this.cents});
  final String name;
  final int cents;
}

/// One quest (savings-goal monster) card.
class QuestCard {
  const QuestCard({
    required this.questId,
    required this.name,
    required this.targetCents,
    required this.balanceCents,
    required this.totalContributedCents,
    required this.completed,
    required this.isShared,
    required this.contributors,
  });

  final String questId;
  final String name;
  final int targetCents;
  final int balanceCents;
  final int totalContributedCents;
  final bool completed;
  final bool isShared;
  final List<ContributorShare> contributors;

  double get progress {
    if (targetCents <= 0) return 1;
    final fraction = totalContributedCents / targetCents;
    return fraction < 0 ? 0 : (fraction > 1 ? 1 : fraction);
  }

  int get pctComplete => (progress * 100).round();
}

/// A pending war-chest withdrawal (writ).
class WithdrawalCard {
  const WithdrawalCard({
    required this.proposalId,
    required this.byUserName,
    required this.amountCents,
    required this.purpose,
    required this.destinationLabel,
    required this.mineToApprove,
  });

  final String proposalId;
  final String byUserName;
  final int amountCents;
  final String purpose;
  final String destinationLabel;

  /// True when the *other* user proposed it and it awaits my signature.
  final bool mineToApprove;
}

/// Outstanding overspending to repay (the OVERBUDGET). Visible to every
/// adult; the indebted category stays locked until it clears.
class OverbudgetCard {
  const OverbudgetCard({
    required this.sliceId,
    required this.categoryName,
    required this.outstandingCents,
    required this.accruedCents,
    required this.mine,
    this.ownerName,
  });

  final String sliceId;
  final String categoryName;
  final int outstandingCents;
  final int accruedCents;
  final bool mine;
  final String? ownerName;

  int get paidCents => accruedCents - outstandingCents;
}

/// A surfaced war-chest ransack.
class RansackCard {
  const RansackCard({
    required this.fundName,
    required this.excessCents,
    required this.purpose,
    required this.occurredAt,
  });

  final String fundName;
  final int excessCents;
  final String purpose;
  final DateTime occurredAt;
}

/// The war-chest (shared pool) card.
class WarChestCard {
  const WarChestCard({
    required this.balanceCents,
    required this.pendingForMe,
    required this.otherPending,
    required this.ransacks,
    this.targetCents,
    this.pctComplete,
    this.estMonthsRemaining,
  });

  final int balanceCents;
  final int? targetCents;
  final double? pctComplete;
  final double? estMonthsRemaining;
  final List<WithdrawalCard> pendingForMe;
  final List<WithdrawalCard> otherPending;
  final List<RansackCard> ransacks;

  bool get hasGoal => targetCents != null;

  /// "about N months to go", or null when the estimate is unavailable.
  int? get monthsToGo => estMonthsRemaining == null
      ? null
      : (estMonthsRemaining!.isFinite ? estMonthsRemaining!.ceil() : null);
}

/// An emergency-fund (reserve cache) chip.
class EmergencyFundCard {
  const EmergencyFundCard({
    required this.name,
    required this.balanceCents,
    this.petName,
  });

  final String name;
  final int balanceCents;
  final String? petName;
}

/// An open vacation (trip sub-budget), surfaced on the dashboard while it runs.
class OpenVacationCard {
  const OpenVacationCard({
    required this.vacationId,
    required this.name,
    required this.spentCents,
    required this.budgetCents,
    required this.allowanceLabel,
    this.warnings = const [],
  });

  final String vacationId;
  final String name;
  final int spentCents;
  final int budgetCents;

  /// e.g. "$120.00/day for 6 more days".
  final String allowanceLabel;

  /// Overspend warnings, most urgent first; empty when comfortably on budget.
  final List<String> warnings;

  double get fraction {
    if (budgetCents <= 0) return spentCents > 0 ? 1 : 0;
    final fraction = spentCents / budgetCents;
    return fraction < 0 ? 0 : (fraction > 1 ? 1 : fraction);
  }
}

/// One day's spend on the month timeline.
class SpendPoint {
  const SpendPoint({required this.day, required this.cents});
  final int day;
  final int cents;
}

/// The current month's spend timeline.
class SpendTimeline {
  const SpendTimeline({
    required this.month,
    required this.points,
    required this.totalCents,
    required this.maxDayCents,
    required this.daysInMonth,
  });

  final Month month;
  final List<SpendPoint> points;
  final int totalCents;
  final int maxDayCents;
  final int daysInMonth;

  bool get isEmpty => totalCents == 0;
}

/// Everything the dashboard renders.
class DashboardModel {
  const DashboardModel({
    required this.currentMonth,
    required this.meName,
    required this.hero,
    required this.slices,
    required this.maintenance,
    required this.upcoming,
    required this.vault,
    required this.quests,
    required this.warChest,
    required this.emergencyFunds,
    required this.netWorth,
    required this.timeline,
    this.overbudgets = const [],
    this.advances = const [],
    this.vacations = const [],
    this.savingsRules = true,
    required this.spoils,
  });

  final Month currentMonth;
  final String meName;

  /// Income / spent / remaining headline for the current month.
  final MonthHero hero;

  /// The household net-worth summary + trend.
  final NetWorthSummary netWorth;
  final List<SliceRing> slices;
  final List<MaintenanceItem> maintenance;

  /// Recurring bills sorted by how soon they come due.
  final List<UpcomingPayment> upcoming;
  final VaultCard vault;
  final List<QuestCard> quests;
  final WarChestCard warChest;
  final List<EmergencyFundCard> emergencyFunds;
  final SpendTimeline timeline;

  /// Outstanding overspending to repay, the device owner's first.
  final List<OverbudgetCard> overbudgets;

  /// Pending requests to borrow from a budget's future months, the ones
  /// awaiting this device's adult first.
  final List<PendingAdvance> advances;

  /// Trips currently open, by name.
  final List<OpenVacationCard> vacations;

  /// Whether the household is on the savings rules — Classic then calls each
  /// adult's own pool "general savings" rather than "personal spending".
  final bool savingsRules;

  /// The reopenable month-close ritual, when one is pending; null otherwise.
  final SpoilsRitual? spoils;
}

/// Builds the dashboard model for [meUserId] as of [asOf] (now by default).
DashboardModel buildDashboardModel(
  HouseholdState state, {
  required String meUserId,
  required Map<String, String> userNames,
  Iterable<Event> events = const [],
  DateTime? asOf,
  bool includeOtherAdults = true,
}) {
  final now = (asOf ?? DateTime.now()).toUtc();
  final month = Month.fromInstant(now);
  final closed = month.prev();
  final savingsRules = state.savingsRules != null;
  String? nameOf(String id) => userNames[id];
  String? petName(String? id) => id == null ? null : state.pets[id]?.name;
  int? mainColor(String? id) =>
      id == null ? null : state.mainCategories[id]?.colorArgb;

  // ---- Slice rings -------------------------------------------------------
  // With the household-visibility toggle off, other adults' personal budgets
  // stay off this device's dashboard (shared/group ones always show).
  final rings = <SliceRing>[];
  for (final sliceConfig in state.slices.values) {
    if (sliceConfig.createdMonth.isAfter(month)) continue;
    if (!includeOtherAdults &&
        !sliceConfig.isGroup &&
        sliceConfig.ownerUserId != meUserId) {
      continue;
    }
    final sliceMonth = state.sliceMonth(sliceConfig.sliceId, month);
    rings.add(
      SliceRing(
        sliceId: sliceConfig.sliceId,
        name: sliceConfig.name,
        isGroup: sliceConfig.isGroup,
        spentCents: sliceMonth == null
            ? 0
            : sliceMonth.spentCents -
                  sliceMonth.coveredCents -
                  sliceMonth.fromSavingsCents,
        effectiveLimitCents:
            sliceMonth?.effectiveLimitCents ??
            sliceConfig.baseEffectiveLimitCents,
        overspendCents: sliceMonth?.overspendCents ?? 0,
        lockedCents: sliceMonth?.lockedCents ?? 0,
        savingsCents: sliceMonth?.savingsCents ?? 0,
        mine: !sliceConfig.isGroup && sliceConfig.ownerUserId == meUserId,
        ownerName: sliceConfig.isGroup
            ? null
            : nameOf(sliceConfig.ownerUserId ?? ''),
        petName: petName(sliceConfig.petId),
        mainCategoryColorArgb: mainColor(sliceConfig.mainCategoryId),
      ),
    );
  }
  rings.sort((first, second) {
    // My personal slices first, then my partner's, then group slices; name ties.
    int rank(SliceRing ring) => ring.isGroup ? 2 : (ring.mine ? 0 : 1);
    final comparison = rank(first).compareTo(rank(second));
    return comparison != 0 ? comparison : first.name.compareTo(second.name);
  });

  // ---- Equipment maintenance --------------------------------------------
  final maintenance = <MaintenanceItem>[];
  for (final expense in state.recurringExpenses.values) {
    final activeNow = expense.activeIn(month);
    final activeClosed = expense.activeIn(closed);
    if (!activeNow && !activeClosed) continue;
    final actualThis = state.variableActualFor(expense.expenseId, month);
    final amount = expense.kind == RecurringKind.variable
        ? (actualThis ?? expense.amountCents)
        : expense.amountCents;
    final awaiting =
        expense.kind == RecurringKind.variable &&
        activeClosed &&
        state.variableActualFor(expense.expenseId, closed) == null;
    maintenance.add(
      MaintenanceItem(
        name: expense.name,
        kind: expense.kind,
        amountCents: amount,
        isShared: expense.isShared,
        awaitingTally: awaiting,
        ownerName: expense.ownerUserId == null
            ? null
            : nameOf(expense.ownerUserId!),
      ),
    );
  }
  maintenance.sort((first, second) => first.name.compareTo(second.name));

  // ---- Upcoming payments strip ------------------------------------------
  // Household-local "today" drives the due-date countdown.
  final localNow = now.add(vancouverUtcOffset(now));
  final upcoming = <UpcomingPayment>[];
  for (final expense in state.recurringExpenses.values) {
    if (!expense.activeIn(month)) continue;
    upcoming.add(
      UpcomingPayment(
        name: expense.name,
        amountCents: expense.amountCents,
        isAnnual: expense.isAnnual,
        isShared: expense.isShared,
        dueDay: expense.dueDay,
        dueMonth: expense.dueMonth,
        daysUntilDue: expense.daysUntilDue(localNow),
      ),
    );
  }
  upcoming.sort((first, second) {
    final comparison = first.daysUntilDue.compareTo(second.daysUntilDue);
    return comparison != 0 ? comparison : first.name.compareTo(second.name);
  });

  // ---- Vault + projected spoils -----------------------------------------
  var projLeftover = 0;
  var projVault = 0;
  for (final sliceConfig in state.slices.values) {
    if (sliceConfig.isGroup || sliceConfig.ownerUserId != meUserId) continue;
    final sliceMonth = state.sliceMonth(sliceConfig.sliceId, month);
    final leftover = sliceMonth?.leftoverCents ?? 0;
    if (leftover <= 0) continue;
    projLeftover += leftover;
    projVault += Money.titheCents(
      leftover,
      sliceConfig.poolTithePct,
    ).remainderCents;
  }
  final vault = VaultCard(
    balanceCents: state.vaultOf(meUserId),
    inconsistent: state.isVaultInconsistent(meUserId),
    projectedLeftoverCents: projLeftover,
    projectedVaultCents: projVault,
  );

  // ---- Quests ------------------------------------------------------------
  final quests = <QuestCard>[];
  for (final quest in state.quests.values) {
    if (quest.abandoned) continue;
    final contributors = <ContributorShare>[
      for (final entry in quest.contributions.entries)
        if (entry.value != 0)
          ContributorShare(
            name: nameOf(entry.key) ?? 'Someone',
            cents: entry.value,
          ),
    ]..sort((first, second) => second.cents.compareTo(first.cents));
    quests.add(
      QuestCard(
        questId: quest.questId,
        name: quest.name,
        targetCents: quest.targetCents,
        balanceCents: quest.balanceCents,
        totalContributedCents: quest.totalContributedCents,
        completed: quest.completed,
        isShared: quest.ownership is SharedParty,
        contributors: contributors,
      ),
    );
  }
  quests.sort((first, second) {
    // In-progress before completed; then by remaining-to-target.
    final comparison = (first.completed ? 1 : 0).compareTo(
      second.completed ? 1 : 0,
    );
    if (comparison != 0) return comparison;
    return first.name.compareTo(second.name);
  });

  // ---- War chest ---------------------------------------------------------
  final pendingForMe = <WithdrawalCard>[];
  final otherPending = <WithdrawalCard>[];
  for (final withdrawal in state.withdrawals.values) {
    if (withdrawal.status != WithdrawalStatus.pending) continue;
    final mineToApprove = withdrawal.byUserId != meUserId;
    final card = WithdrawalCard(
      proposalId: withdrawal.proposalId,
      byUserName: nameOf(withdrawal.byUserId) ?? 'Someone',
      amountCents: withdrawal.amountCents,
      purpose: withdrawal.purpose,
      destinationLabel: switch (withdrawal.destination) {
        UserVaultDestination(:final userId) =>
          '${nameOf(userId) ?? 'someone'}’s ${Glossary.vaultLabel(isAdventure: false, savingsRules: savingsRules)}',
        ExternalDestination() => 'external',
      },
      mineToApprove: mineToApprove,
    );
    (mineToApprove ? pendingForMe : otherPending).add(card);
  }
  final ransacks = <RansackCard>[
    for (final ransack in state.ransacks)
      RansackCard(
        fundName: state.emergencyFunds[ransack.fundId]?.name ?? 'a reserve',
        excessCents: ransack.excessCents,
        purpose: ransack.purpose,
        occurredAt: ransack.occurredAt,
      ),
  ]..sort((first, second) => second.occurredAt.compareTo(first.occurredAt));
  final goal = state.warChest.goal;
  final warChest = WarChestCard(
    balanceCents: state.warChest.balanceCents,
    targetCents: state.warChest.targetCents,
    pctComplete: goal?.pctComplete,
    estMonthsRemaining: goal?.estMonthsRemaining,
    pendingForMe: pendingForMe,
    otherPending: otherPending,
    ransacks: ransacks,
  );

  // ---- Emergency funds ---------------------------------------------------
  final funds = <EmergencyFundCard>[
    for (final fund in state.emergencyFunds.values)
      EmergencyFundCard(
        name: fund.name,
        balanceCents: fund.balanceCents,
        petName: petName(fund.petId),
      ),
  ]..sort((first, second) => first.name.compareTo(second.name));

  // ---- Month spend timeline ---------------------------------------------
  final daysInMonth = DateTime.utc(month.year, month.month + 1, 0).day;
  final byDay = List<int>.filled(daysInMonth + 1, 0);
  for (final purchase in state.purchases.values) {
    if (purchase.voided || purchase.month != month) continue;
    final local = purchase.occurredAt.add(
      vancouverUtcOffset(purchase.occurredAt),
    );
    final dayOfMonth = local.day.clamp(1, daysInMonth);
    byDay[dayOfMonth] += purchase.amountCents;
  }
  var total = 0;
  var maxDay = 0;
  final points = <SpendPoint>[];
  for (var day = 1; day <= daysInMonth; day++) {
    total += byDay[day];
    if (byDay[day] > maxDay) maxDay = byDay[day];
    points.add(SpendPoint(day: day, cents: byDay[day]));
  }
  final timeline = SpendTimeline(
    month: month,
    points: points,
    totalCents: total,
    maxDayCents: maxDay,
    daysInMonth: daysInMonth,
  );

  // ---- Month hero (income vs spent vs remaining) ------------------------
  var incomeCents = 0;
  for (final adultId in state.adultIds) {
    incomeCents += state.incomeFor(adultId, month);
  }
  final hero = MonthHero(incomeCents: incomeCents, spentCents: total);

  // ---- Net worth summary + trend ----------------------------------------
  final netWorth = NetWorthSummary(
    show: state.netWorth.show,
    totalCents: state.netWorth.totalCents,
    assetsCents: state.netWorth.assetsCents,
    debtsCents: state.netWorth.debtsCents,
    series: buildNetWorthSeries(events),
  );

  // ---- Outstanding overspending to repay ----------------------------------
  final overbudgets =
      <OverbudgetCard>[
        for (final debt in state.outstandingOverbudgets)
          if (includeOtherAdults || debt.ownerUserId == meUserId)
            OverbudgetCard(
              sliceId: debt.sliceId,
              categoryName: state.slices[debt.sliceId]?.name ?? debt.sliceId,
              outstandingCents: debt.outstandingCents,
              accruedCents: debt.accruedCents,
              mine: debt.ownerUserId == meUserId,
              ownerName: nameOf(debt.ownerUserId),
            ),
      ]..sort((first, second) {
        final comparison = (first.mine ? 0 : 1).compareTo(second.mine ? 0 : 1);
        return comparison != 0
            ? comparison
            : first.categoryName.compareTo(second.categoryName);
      });

  return DashboardModel(
    currentMonth: month,
    meName: nameOf(meUserId) ?? 'You',
    hero: hero,
    netWorth: netWorth,
    slices: rings,
    maintenance: maintenance,
    upcoming: upcoming,
    vault: vault,
    quests: quests,
    warChest: warChest,
    emergencyFunds: funds,
    timeline: timeline,
    overbudgets: overbudgets,
    advances: buildPendingAdvances(
      state,
      meUserId: meUserId,
      userNames: userNames,
    ),
    savingsRules: savingsRules,
    vacations: [
      for (final vacation in state.openVacations)
        OpenVacationCard(
          vacationId: vacation.vacationId,
          name: vacation.name,
          spentCents: vacation.totalSpentCents,
          budgetCents: vacation.totalLimitCents,
          allowanceLabel: dailyAllowanceLabel(vacation),
          warnings: vacationWarnings(vacation),
        ),
    ],
    spoils: buildSpoilsRitual(
      state,
      meUserId: meUserId,
      userNames: userNames,
      asOf: now,
    ),
  );
}
