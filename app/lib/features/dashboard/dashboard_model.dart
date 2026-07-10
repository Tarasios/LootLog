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
import '../networth/networth_model.dart';
import '../spoils/spoils_model.dart';

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
    final f = spentCents / incomeCents;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
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

  bool get hasAccounts => assetsCents != 0 || debtsCents != 0 || series.isNotEmpty;
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

  /// Whether a personal slice belongs to the device owner.
  final bool mine;
  final String? ownerName;
  final String? petName;

  /// The colour of this category's main category, for colour-coded tiles. Null
  /// when the category has no main category assigned.
  final int? mainCategoryColorArgb;

  bool get overspent => overspendCents > 0;

  int get remainingCents {
    final r = effectiveLimitCents - spentCents;
    return r < 0 ? 0 : r;
  }

  /// Consumed fraction for the ring (0..1); a zero-limit slice reads full once
  /// anything is spent.
  double get fraction {
    if (effectiveLimitCents <= 0) return spentCents > 0 ? 1 : 0;
    final f = spentCents / effectiveLimitCents;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
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
    final f = totalContributedCents / targetCents;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
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
  String? nameOf(String id) => userNames[id];
  String? petName(String? id) => id == null ? null : state.pets[id]?.name;
  int? mainColor(String? id) =>
      id == null ? null : state.mainCategories[id]?.colorArgb;

  // ---- Slice rings -------------------------------------------------------
  // With the household-visibility toggle off, other adults' personal budgets
  // stay off this device's dashboard (shared/group ones always show).
  final rings = <SliceRing>[];
  for (final cfg in state.slices.values) {
    if (cfg.createdMonth.isAfter(month)) continue;
    if (!includeOtherAdults &&
        !cfg.isGroup &&
        cfg.ownerUserId != meUserId) {
      continue;
    }
    final sm = state.sliceMonth(cfg.sliceId, month);
    rings.add(SliceRing(
      sliceId: cfg.sliceId,
      name: cfg.name,
      isGroup: cfg.isGroup,
      spentCents: sm?.spentCents ?? 0,
      effectiveLimitCents: sm?.effectiveLimitCents ?? cfg.baseEffectiveLimitCents,
      overspendCents: sm?.overspendCents ?? 0,
      lockedCents: sm?.lockedCents ?? 0,
      mine: !cfg.isGroup && cfg.ownerUserId == meUserId,
      ownerName: cfg.isGroup ? null : nameOf(cfg.ownerUserId ?? ''),
      petName: petName(cfg.petId),
      mainCategoryColorArgb: mainColor(cfg.mainCategoryId),
    ));
  }
  rings.sort((a, b) {
    // My personal slices first, then my partner's, then group slices; name ties.
    int rank(SliceRing r) => r.isGroup ? 2 : (r.mine ? 0 : 1);
    final c = rank(a).compareTo(rank(b));
    return c != 0 ? c : a.name.compareTo(b.name);
  });

  // ---- Equipment maintenance --------------------------------------------
  final maintenance = <MaintenanceItem>[];
  for (final r in state.recurringExpenses.values) {
    final activeNow = r.activeIn(month);
    final activeClosed = r.activeIn(closed);
    if (!activeNow && !activeClosed) continue;
    final actualThis = state.variableActualFor(r.expenseId, month);
    final amount = r.kind == RecurringKind.variable
        ? (actualThis ?? r.amountCents)
        : r.amountCents;
    final awaiting = r.kind == RecurringKind.variable &&
        activeClosed &&
        state.variableActualFor(r.expenseId, closed) == null;
    maintenance.add(MaintenanceItem(
      name: r.name,
      kind: r.kind,
      amountCents: amount,
      isShared: r.isShared,
      awaitingTally: awaiting,
      ownerName: r.ownerUserId == null ? null : nameOf(r.ownerUserId!),
    ));
  }
  maintenance.sort((a, b) => a.name.compareTo(b.name));

  // ---- Upcoming payments strip ------------------------------------------
  // Household-local "today" drives the due-date countdown.
  final localNow = now.add(vancouverUtcOffset(now));
  final upcoming = <UpcomingPayment>[];
  for (final r in state.recurringExpenses.values) {
    if (!r.activeIn(month)) continue;
    upcoming.add(UpcomingPayment(
      name: r.name,
      amountCents: r.amountCents,
      isAnnual: r.isAnnual,
      isShared: r.isShared,
      dueDay: r.dueDay,
      dueMonth: r.dueMonth,
      daysUntilDue: r.daysUntilDue(localNow),
    ));
  }
  upcoming.sort((a, b) {
    final c = a.daysUntilDue.compareTo(b.daysUntilDue);
    return c != 0 ? c : a.name.compareTo(b.name);
  });

  // ---- Vault + projected spoils -----------------------------------------
  var projLeftover = 0;
  var projVault = 0;
  for (final cfg in state.slices.values) {
    if (cfg.isGroup || cfg.ownerUserId != meUserId) continue;
    final sm = state.sliceMonth(cfg.sliceId, month);
    final leftover = sm?.leftoverCents ?? 0;
    if (leftover <= 0) continue;
    projLeftover += leftover;
    projVault += Money.titheCents(leftover, cfg.poolTithePct).remainderCents;
  }
  final vault = VaultCard(
    balanceCents: state.vaultOf(meUserId),
    inconsistent: state.isVaultInconsistent(meUserId),
    projectedLeftoverCents: projLeftover,
    projectedVaultCents: projVault,
  );

  // ---- Quests ------------------------------------------------------------
  final quests = <QuestCard>[];
  for (final q in state.quests.values) {
    if (q.abandoned) continue;
    final contributors = <ContributorShare>[
      for (final e in q.contributions.entries)
        if (e.value != 0)
          ContributorShare(name: nameOf(e.key) ?? 'Someone', cents: e.value),
    ]..sort((a, b) => b.cents.compareTo(a.cents));
    quests.add(QuestCard(
      questId: q.questId,
      name: q.name,
      targetCents: q.targetCents,
      balanceCents: q.balanceCents,
      totalContributedCents: q.totalContributedCents,
      completed: q.completed,
      isShared: q.ownership is SharedParty,
      contributors: contributors,
    ));
  }
  quests.sort((a, b) {
    // In-progress before completed; then by remaining-to-target.
    final c = (a.completed ? 1 : 0).compareTo(b.completed ? 1 : 0);
    if (c != 0) return c;
    return a.name.compareTo(b.name);
  });

  // ---- War chest ---------------------------------------------------------
  final pendingForMe = <WithdrawalCard>[];
  final otherPending = <WithdrawalCard>[];
  for (final w in state.withdrawals.values) {
    if (w.status != WithdrawalStatus.pending) continue;
    final mineToApprove = w.byUserId != meUserId;
    final card = WithdrawalCard(
      proposalId: w.proposalId,
      byUserName: nameOf(w.byUserId) ?? 'Someone',
      amountCents: w.amountCents,
      purpose: w.purpose,
      destinationLabel: switch (w.destination) {
        UserVaultDestination(:final userId) =>
          '${nameOf(userId) ?? 'a'} vault',
        ExternalDestination() => 'external',
      },
      mineToApprove: mineToApprove,
    );
    (mineToApprove ? pendingForMe : otherPending).add(card);
  }
  final ransacks = <RansackCard>[
    for (final r in state.ransacks)
      RansackCard(
        fundName: state.emergencyFunds[r.fundId]?.name ?? 'a reserve',
        excessCents: r.excessCents,
        purpose: r.purpose,
        occurredAt: r.occurredAt,
      ),
  ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
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
    for (final f in state.emergencyFunds.values)
      EmergencyFundCard(
        name: f.name,
        balanceCents: f.balanceCents,
        petName: petName(f.petId),
      ),
  ]..sort((a, b) => a.name.compareTo(b.name));

  // ---- Month spend timeline ---------------------------------------------
  final daysInMonth = DateTime.utc(month.year, month.month + 1, 0).day;
  final byDay = List<int>.filled(daysInMonth + 1, 0);
  for (final p in state.purchases.values) {
    if (p.voided || p.month != month) continue;
    final local = p.occurredAt.add(vancouverUtcOffset(p.occurredAt));
    final d = local.day.clamp(1, daysInMonth);
    byDay[d] += p.amountCents;
  }
  var total = 0;
  var maxDay = 0;
  final points = <SpendPoint>[];
  for (var d = 1; d <= daysInMonth; d++) {
    total += byDay[d];
    if (byDay[d] > maxDay) maxDay = byDay[d];
    points.add(SpendPoint(day: d, cents: byDay[d]));
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
  final overbudgets = <OverbudgetCard>[
    for (final d in state.outstandingOverbudgets)
      if (includeOtherAdults || d.ownerUserId == meUserId)
        OverbudgetCard(
        sliceId: d.sliceId,
        categoryName: state.slices[d.sliceId]?.name ?? d.sliceId,
        outstandingCents: d.outstandingCents,
        accruedCents: d.accruedCents,
        mine: d.ownerUserId == meUserId,
        ownerName: nameOf(d.ownerUserId),
      ),
  ]..sort((a, b) {
      final c = (a.mine ? 0 : 1).compareTo(b.mine ? 0 : 1);
      return c != 0 ? c : a.categoryName.compareTo(b.categoryName);
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
    spoils: buildSpoilsRitual(
      state,
      meUserId: meUserId,
      userNames: userNames,
      asOf: now,
    ),
  );
}
