/// `HouseholdState` and its parts: the derived read-model produced by the
/// reducer. Nothing here mutates; the reducer builds a fresh snapshot from the
/// event log every time. Pure Dart, zero Flutter imports.
library;

import 'time.dart';
import 'value_types.dart';

/// Household settings, with the documented defaults.
class Settings {
  const Settings({
    this.spoilsGraceDays = 7,
    this.dissolutionTithePct = 10,
    this.showNetWorth = false,
  });

  final int spoilsGraceDays;
  final int dissolutionTithePct;
  final bool showNetWorth;

  Settings copyWith({int? spoilsGraceDays, int? dissolutionTithePct, bool? showNetWorth}) =>
      Settings(
        spoilsGraceDays: spoilsGraceDays ?? this.spoilsGraceDays,
        dissolutionTithePct: dissolutionTithePct ?? this.dissolutionTithePct,
        showNetWorth: showNetWorth ?? this.showNetWorth,
      );
}

/// A **main category** — the coarse grouping every budget category belongs to.
/// Its [colorArgb] is the single source of colour for the monthly spend report
/// (a pie by main category) and is the key used for quest-tithe matching. The
/// eight documented defaults are [defaultMainCategories]; households may rename,
/// recolour, or add to them via `MainCategorySet` events (last-writer-wins).
class MainCategory {
  const MainCategory({
    required this.id,
    required this.name,
    required this.colorArgb,
    required this.sortOrder,
  });

  final String id;
  final String name;

  /// A 32-bit ARGB colour (e.g. `0xFF4E79A7`).
  final int colorArgb;
  final int sortOrder;

  MainCategory copyWith({String? name, int? colorArgb, int? sortOrder}) =>
      MainCategory(
        id: id,
        name: name ?? this.name,
        colorArgb: colorArgb ?? this.colorArgb,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  @override
  bool operator ==(Object other) =>
      other is MainCategory &&
      other.id == id &&
      other.name == name &&
      other.colorArgb == colorArgb &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, name, colorArgb, sortOrder);
}

/// The eight documented default main categories, in display order. Their colours
/// (a colourblind-friendly qualitative palette) drive the spend report. The
/// reducer always seeds these, so every household has them even with no
/// `MainCategorySet` events on the log.
const List<MainCategory> defaultMainCategories = [
  MainCategory(id: 'housing', name: 'Housing', colorArgb: 0xFF4E79A7, sortOrder: 0),
  MainCategory(id: 'food', name: 'Food', colorArgb: 0xFFF28E2B, sortOrder: 1),
  MainCategory(id: 'transport', name: 'Transport', colorArgb: 0xFFE15759, sortOrder: 2),
  MainCategory(id: 'health', name: 'Health', colorArgb: 0xFF76B7B2, sortOrder: 3),
  MainCategory(
      id: 'entertainment', name: 'Entertainment', colorArgb: 0xFF59A14F, sortOrder: 4),
  MainCategory(id: 'pets', name: 'Pets', colorArgb: 0xFFEDC948, sortOrder: 5),
  MainCategory(id: 'savings', name: 'Savings', colorArgb: 0xFFB07AA1, sortOrder: 6),
  MainCategory(id: 'misc', name: 'Misc', colorArgb: 0xFF9C755F, sortOrder: 7),
];

/// The configuration of a budget category (internal type name retained;
/// `BudgetSliceSet` stays on the wire), plus the month it first appeared.
class SliceConfig {
  const SliceConfig({
    required this.sliceId,
    required this.name,
    required this.ownership,
    required this.limitCents,
    required this.poolTithePct,
    required this.defaultLeftoverPolicy,
    required this.taxDeductibleByDefault,
    required this.createdMonth,
    this.mainCategoryId,
    this.emergencyFundId,
    this.emergencyContributionCents = 0,
    this.petId,
  });

  final String sliceId;
  final String name;
  final SliceOwnership ownership;
  final int limitCents;
  final int poolTithePct;
  final LeftoverDestination defaultLeftoverPolicy;
  final bool taxDeductibleByDefault;
  final Month createdMonth;

  /// The [MainCategory] this budget category rolls up to, or null when
  /// unassigned (older categories, or ones created before a main category was
  /// picked). Reports bucket unassigned spend under "Uncategorized".
  final String? mainCategoryId;
  final String? emergencyFundId;
  final int emergencyContributionCents;
  final String? petId;

  bool get isGroup => ownership is GroupSlice;

  String? get ownerUserId =>
      ownership is PersonalSlice ? (ownership as PersonalSlice).userId : null;

  /// The limit less any monthly emergency contribution.
  int get baseEffectiveLimitCents => limitCents - emergencyContributionCents;
}

/// Derived per-slice, per-month figures.
class SliceMonth {
  const SliceMonth({
    required this.sliceId,
    required this.month,
    required this.isGroup,
    required this.ownerUserId,
    required this.effectiveLimitCents,
    required this.spentCents,
    required this.leftoverCents,
    required this.carryInCents,
    required this.carryOutCents,
    required this.overspendCents,
    required this.resolved,
  });

  final String sliceId;
  final Month month;
  final bool isGroup;
  final String? ownerUserId;

  /// `limit − emergency contribution + carry-in`.
  final int effectiveLimitCents;
  final int spentCents;
  final int leftoverCents;
  final int carryInCents;
  final int carryOutCents;
  final int overspendCents;

  /// Whether the month's leftover has been resolved (an allocation event
  /// exists, or the grace period has lapsed and the default policy applied).
  final bool resolved;

  bool get overspent => overspendCents > 0;
}

/// Derived configuration of a recurring expense ("equipment maintenance").
/// Exposed on the read-model so the dashboard's equipment-maintenance summary
/// and the spoils ritual's variable-actual step read it from the reducer rather
/// than re-deriving it from the event log.
class RecurringExpenseState {
  const RecurringExpenseState({
    required this.expenseId,
    required this.name,
    required this.ownership,
    required this.kind,
    required this.amountCents,
    required this.startMonth,
    this.endMonth,
    this.cadence = RecurringCadence.monthly,
    this.dueDay = 1,
    this.dueMonth,
    this.reserveCents = 0,
    this.lastReconciliation,
  });

  final String expenseId;
  final String name;
  final PartyOwnership ownership;
  final RecurringKind kind;

  /// The fixed amount, or the estimate for a variable expense. For an annual
  /// expense this is the full annual figure (accrued 1/12 monthly).
  final int amountCents;
  final Month startMonth;
  final Month? endMonth;

  /// Monthly (full amount each month) or annual (1/12 accrued monthly).
  final RecurringCadence cadence;

  /// Day of the month the bill is due (clamped to the month's length).
  final int dueDay;

  /// For an annual expense, the calendar month (1..12) it comes due; null for
  /// monthly expenses.
  final int? dueMonth;

  /// The reserve accrued toward an annual expense as of the read-time month
  /// (money set aside since the last due month). Always 0 for monthly.
  final int reserveCents;

  /// The most recent due-month reconciliation for an annual expense at or
  /// before the read-time month, or null when none has occurred yet.
  final AnnualDueReconciliation? lastReconciliation;

  bool get isShared => ownership is SharedParty;

  bool get isAnnual => cadence == RecurringCadence.annual;

  String? get ownerUserId =>
      ownership is PersonalParty ? (ownership as PersonalParty).userId : null;

  /// Whether this expense is expected to run in [month].
  bool activeIn(Month month) =>
      !startMonth.isAfter(month) &&
      (endMonth == null || !month.isAfter(endMonth!));

  /// The next due date at or after [from], in the household-local calendar,
  /// clamped to each month's length (so a `dueDay` of 31 lands on the last day).
  DateTime nextDueDate(DateTime from) {
    final f = DateTime(from.year, from.month, from.day);
    int lastDay(int y, int m) => DateTime(y, m + 1, 0).day;
    DateTime forMonth(int y, int m) =>
        DateTime(y, m, dueDay > lastDay(y, m) ? lastDay(y, m) : dueDay);
    if (isAnnual && dueMonth != null) {
      var candidate = forMonth(f.year, dueMonth!);
      if (candidate.isBefore(f)) {
        candidate = forMonth(f.year + 1, dueMonth!);
      }
      return candidate;
    }
    var candidate = forMonth(f.year, f.month);
    if (candidate.isBefore(f)) {
      final ny = f.month == 12 ? f.year + 1 : f.year;
      final nm = f.month == 12 ? 1 : f.month + 1;
      candidate = forMonth(ny, nm);
    }
    return candidate;
  }

  /// Whole days from [from] to the next due date (0 when due today).
  int daysUntilDue(DateTime from) => nextDueDate(from)
      .difference(DateTime(from.year, from.month, from.day))
      .inDays;
}

/// The reconciliation of an annual expense in its due month: the real amount is
/// applied against the reserve accumulated that far. A positive [deltaCents] is
/// a surplus (over-reserved), a negative one a shortfall (under-reserved,
/// typically a partial first year).
class AnnualDueReconciliation {
  const AnnualDueReconciliation({
    required this.month,
    required this.dueAmountCents,
    required this.reserveBeforeCents,
  });

  final Month month;
  final int dueAmountCents;

  /// The reserve balance the instant before the bill was applied.
  final int reserveBeforeCents;

  int get deltaCents => reserveBeforeCents - dueAmountCents;

  int get shortfallCents => deltaCents < 0 ? -deltaCents : 0;

  int get surplusCents => deltaCents > 0 ? deltaCents : 0;
}

/// Derived state of a savings-goal quest.
class QuestState {
  const QuestState({
    required this.questId,
    required this.name,
    required this.targetCents,
    required this.ownership,
    required this.balanceCents,
    required this.contributions,
    required this.completed,
    required this.abandoned,
    this.mainCategoryId,
    this.sliceHint,
    this.customSpriteSha256,
    this.descriptionText,
  });

  final String questId;
  final String name;
  final int targetCents;
  final PartyOwnership ownership;

  /// Total funded less quest-charged spending; clamped at zero.
  final int balanceCents;

  /// How much each user has funded (used for proportional abandonment returns).
  final Map<String, int> contributions;
  final bool completed;
  final bool abandoned;

  /// The main category this goal rolls up to; drives category-match tithing.
  final String? mainCategoryId;
  final String? sliceHint;
  final String? customSpriteSha256;

  /// The user-written character description used by text-mode adventure.
  final String? descriptionText;

  int get totalContributedCents =>
      contributions.values.fold(0, (a, b) => a + b);
}

/// Derived state of a named emergency fund.
class EmergencyFundState {
  const EmergencyFundState({
    required this.fundId,
    required this.name,
    required this.balanceCents,
    this.petId,
  });

  final String fundId;
  final String name;
  final int balanceCents;
  final String? petId;
}

/// A surfaced war-chest ransack: an emergency purchase drew this excess from the
/// pool without prior approval.
class RansackRecord {
  const RansackRecord({
    required this.fundId,
    required this.excessCents,
    required this.purpose,
    required this.occurredAt,
  });

  final String fundId;
  final int excessCents;
  final String purpose;
  final DateTime occurredAt;
}

/// War-chest progress toward a goal.
class GoalProgress {
  const GoalProgress({
    required this.targetCents,
    required this.pctComplete,
    required this.remainingCents,
    required this.avgNetInflowCents,
    required this.estMonthsRemaining,
  });

  final int targetCents;
  final double pctComplete;
  final int remainingCents;

  /// Trailing three-month average net pool inflow (may be ≤ 0).
  final double avgNetInflowCents;

  /// `remaining / avg`, or `null` when the average inflow is ≤ 0.
  final double? estMonthsRemaining;
}

/// The war chest (long-term shared pool).
class WarChestState {
  const WarChestState({
    required this.balanceCents,
    this.targetCents,
    this.goal,
  });

  final int balanceCents;
  final int? targetCents;
  final GoalProgress? goal;
}

enum WithdrawalStatus { pending, approved, cancelled }

/// A pool withdrawal proposal and its resolution.
class WithdrawalProposal {
  const WithdrawalProposal({
    required this.proposalId,
    required this.byUserId,
    required this.amountCents,
    required this.purpose,
    required this.destination,
    required this.status,
    this.approvedByUserId,
  });

  final String proposalId;
  final String byUserId;
  final int amountCents;
  final String purpose;
  final WithdrawalDestination destination;
  final WithdrawalStatus status;
  final String? approvedByUserId;
}

/// A display-only pet party member.
class PetState {
  const PetState({required this.petId, required this.name, this.customSpriteSha256});

  final String petId;
  final String name;
  final String? customSpriteSha256;
}

/// A household member. Only `adult` members carry a ledger (income, vault,
/// personal categories); `dependent` and `pet` members enrich the party without
/// any money of their own.
class MemberState {
  const MemberState({
    required this.memberId,
    required this.name,
    required this.role,
    required this.active,
    this.customSpriteSha256,
    this.descriptionText,
  });

  final String memberId;
  final String name;
  final MemberRole role;
  final bool active;
  final String? customSpriteSha256;
  final String? descriptionText;

  bool get isAdult => role == MemberRole.adult;
}

/// An attached receipt reference.
class ReceiptRef {
  const ReceiptRef({
    required this.sha256,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String sha256;
  final String mimeType;
  final int sizeBytes;
}

/// A recorded purchase (non-voided ones drive spending; voided ones are kept
/// for auditability).
class PurchaseState {
  const PurchaseState({
    required this.purchaseId,
    required this.userId,
    required this.target,
    required this.amountCents,
    required this.month,
    required this.occurredAt,
    required this.shared,
    required this.voided,
    required this.receipts,
    this.merchant,
    this.taxDeductible,
    this.note,
  });

  final String purchaseId;
  final String userId;
  final ChargeTarget target;
  final int amountCents;
  final Month month;
  final DateTime occurredAt;
  final bool shared;
  final bool voided;
  final List<ReceiptRef> receipts;
  final String? merchant;
  final bool? taxDeductible;
  final String? note;
}

/// A tracked net-worth account, derived at read time. [balanceCents] is the
/// last recorded balance; [currentValueCents] adds any transfers since and any
/// interest accrued from the recording instant (savings/debt only). Investments
/// are never auto-changed — their current value equals the last recording — but
/// go [stale] once their update cadence has lapsed.
class AccountBalance {
  const AccountBalance({
    required this.accountId,
    required this.name,
    required this.kind,
    required this.balanceCents,
    required this.currentValueCents,
    this.accruedInterestCents = 0,
    this.aprBps,
    this.accrualCadence,
    this.updateCadence,
    this.minPaymentCents,
    this.lastRecordedAt,
    this.stale = false,
  });

  final String accountId;
  final String name;
  final AccountKind kind;

  /// The last recorded balance (raw, before transfers or interest).
  final int balanceCents;

  /// Recorded balance + transfers since + accrued interest.
  final int currentValueCents;

  /// The interest portion of [currentValueCents] (0 when none accrues).
  final int accruedInterestCents;

  final int? aprBps;
  final AccountCadence? accrualCadence;
  final AccountCadence? updateCadence;
  final int? minPaymentCents;

  /// When the last balance was recorded, or null if the account has only ever
  /// been declared (a [TrackedAccountSet] with no balance yet).
  final DateTime? lastRecordedAt;

  /// True for an investment whose [updateCadence] has lapsed since the last
  /// recording — a "stale, update requested" nudge, never an auto-change.
  final bool stale;

  bool get isDebt => kind == AccountKind.debt;

  /// Debt contributes negatively to net worth.
  int get signedCents => isDebt ? -currentValueCents : currentValueCents;
}

/// Net-worth summary derived from the latest balance per account.
class NetWorthState {
  const NetWorthState({
    required this.accounts,
    required this.totalCents,
    required this.show,
  });

  final Map<String, AccountBalance> accounts;

  /// Signed household total: assets − debts, using each account's current value.
  final int totalCents;
  final bool show;

  /// Sum of non-debt current values.
  int get assetsCents => accounts.values
      .where((a) => !a.isDebt)
      .fold(0, (s, a) => s + a.currentValueCents);

  /// Sum of debt current values (a positive magnitude of what is owed).
  int get debtsCents => accounts.values
      .where((a) => a.isDebt)
      .fold(0, (s, a) => s + a.currentValueCents);

  /// Investments past their update cadence, needing a refresh nudge.
  List<AccountBalance> get staleAccounts =>
      accounts.values.where((a) => a.stale).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
}

/// A tax-deductible purchase, for the per-year deductible list.
class DeductiblePurchase {
  const DeductiblePurchase({
    required this.purchaseId,
    required this.userId,
    required this.sliceName,
    required this.amountCents,
    required this.shared,
    required this.occurredAt,
    required this.receiptShas,
    this.merchant,
    this.note,
  });

  final String purchaseId;
  final String userId;
  final String sliceName;
  final int amountCents;
  final bool shared;
  final DateTime occurredAt;
  final List<String> receiptShas;
  final String? merchant;
  final String? note;
}

/// A user's default monthly income, effective from [effectiveFromMonth] and
/// carried forward until a later default supersedes it.
class DefaultIncome {
  const DefaultIncome({
    required this.effectiveFromMonth,
    required this.amountCents,
  });

  final Month effectiveFromMonth;
  final int amountCents;
}

/// The full derived read-model of the household.
class HouseholdState {
  const HouseholdState({
    required this.settings,
    required this.userIds,
    required this.members,
    required this.mainCategories,
    required this.slices,
    required this.sliceMonths,
    required this.quests,
    required this.emergencyFunds,
    required this.pets,
    required this.withdrawals,
    required this.warChest,
    required this.vaultCents,
    required this.inconsistentVaults,
    required this.ransacks,
    required this.purchases,
    required this.netWorth,
    required this.deductibleByYear,
    required this.recurringByUserMonth,
    required this.incomeByUserMonth,
    required this.incomeDefaultsByUser,
    required this.recurringExpenses,
    required this.variableActuals,
  });

  final Settings settings;
  final Set<String> userIds;

  /// Every declared household member, keyed by `memberId`. Adults also appear in
  /// [userIds]; dependents and pets do not (they carry no ledger).
  final Map<String, MemberState> members;

  /// Main categories keyed by id, always including [defaultMainCategories]
  /// (any `MainCategorySet` events override or extend them).
  final Map<String, MainCategory> mainCategories;
  final Map<String, SliceConfig> slices;

  /// Keyed by `"sliceId|yyyy-MM"`.
  final Map<String, SliceMonth> sliceMonths;
  final Map<String, QuestState> quests;
  final Map<String, EmergencyFundState> emergencyFunds;
  final Map<String, PetState> pets;
  final Map<String, WithdrawalProposal> withdrawals;
  final WarChestState warChest;
  final Map<String, int> vaultCents;
  final Set<String> inconsistentVaults;
  final List<RansackRecord> ransacks;
  final Map<String, PurchaseState> purchases;
  final NetWorthState netWorth;
  final Map<int, List<DeductiblePurchase>> deductibleByYear;

  /// Recurring-expense burden keyed by `"userId|yyyy-MM"`.
  final Map<String, int> recurringByUserMonth;

  /// Single-month income overrides keyed by `"userId|yyyy-MM"`.
  final Map<String, int> incomeByUserMonth;

  /// Per-user default monthly incomes, each carried forward from its effective
  /// month until a later default supersedes it. Sorted ascending by month.
  final Map<String, List<DefaultIncome>> incomeDefaultsByUser;

  /// Recurring-expense configuration, keyed by `expenseId`.
  final Map<String, RecurringExpenseState> recurringExpenses;

  /// Recorded variable-expense actuals, keyed by `"expenseId|yyyy-MM"`.
  final Map<String, int> variableActuals;

  static String monthKey(String id, Month month) => '$id|${month.toKey()}';

  /// The recorded actual for a variable recurring expense in [month], or null
  /// when none has been recorded yet (the estimate still stands).
  int? variableActualFor(String expenseId, Month month) =>
      variableActuals[monthKey(expenseId, month)];

  /// The ledger-bearing adults used for every shared split and for approval
  /// quorum. When explicit adult members are declared, those active adults are
  /// authoritative; otherwise (legacy or dependents/pets-only histories) every
  /// known user is treated as an adult.
  Set<String> get adultIds {
    final declared = {
      for (final m in members.values)
        if (m.isAdult && m.active) m.memberId,
    };
    return declared.isNotEmpty ? declared : userIds;
  }

  int vaultOf(String userId) => vaultCents[userId] ?? 0;

  bool isVaultInconsistent(String userId) =>
      inconsistentVaults.contains(userId);

  SliceMonth? sliceMonth(String sliceId, Month month) =>
      sliceMonths[monthKey(sliceId, month)];

  int recurringChargeFor(String userId, Month month) =>
      recurringByUserMonth[monthKey(userId, month)] ?? 0;

  /// The single-month income override for [userId] in [month], or null when the
  /// month has no explicit override (the default, if any, applies instead).
  int? incomeOverrideFor(String userId, Month month) =>
      incomeByUserMonth[monthKey(userId, month)];

  /// Whether [month] carries an explicit income override for [userId].
  bool hasIncomeOverride(String userId, Month month) =>
      incomeByUserMonth.containsKey(monthKey(userId, month));

  /// The default monthly income in effect for [userId] as of [month] — the
  /// latest default whose effective month is on or before [month] — or null
  /// when no default has taken effect yet.
  int? defaultIncomeFor(String userId, Month month) {
    final defaults = incomeDefaultsByUser[userId];
    if (defaults == null) {
      return null;
    }
    int? amount;
    for (final d in defaults) {
      // Sorted ascending: keep the last one that is already effective.
      if (!d.effectiveFromMonth.isAfter(month)) {
        amount = d.amountCents;
      } else {
        break;
      }
    }
    return amount;
  }

  /// Resolved income for [userId] in [month]: a single-month override wins,
  /// else the latest effective default, else zero.
  int incomeFor(String userId, Month month) =>
      incomeOverrideFor(userId, month) ??
      defaultIncomeFor(userId, month) ??
      0;

  /// A deterministic numeric snapshot used to assert that reduction is
  /// order-independent (out-of-order events == sorted order).
  Map<String, Object?> debugSnapshot() {
    final sortedSliceMonths = sliceMonths.keys.toList()..sort();
    final sortedQuests = quests.keys.toList()..sort();
    final sortedFunds = emergencyFunds.keys.toList()..sort();
    final sortedVaults = vaultCents.keys.toList()..sort();
    final sortedWithdrawals = withdrawals.keys.toList()..sort();
    return {
      'warChest': warChest.balanceCents,
      'vaults': {for (final u in sortedVaults) u: vaultCents[u]},
      'inconsistentVaults': (inconsistentVaults.toList()..sort()),
      'quests': {
        for (final q in sortedQuests)
          q: {
            'balance': quests[q]!.balanceCents,
            'completed': quests[q]!.completed,
            'abandoned': quests[q]!.abandoned,
          },
      },
      'funds': {
        for (final f in sortedFunds) f: emergencyFunds[f]!.balanceCents,
      },
      'ransacks': ransacks.length,
      'ransackExcess': ransacks.fold<int>(0, (a, r) => a + r.excessCents),
      'sliceMonths': {
        for (final k in sortedSliceMonths)
          k: {
            'eff': sliceMonths[k]!.effectiveLimitCents,
            'spent': sliceMonths[k]!.spentCents,
            'leftover': sliceMonths[k]!.leftoverCents,
            'carryOut': sliceMonths[k]!.carryOutCents,
          },
      },
      'withdrawals': {
        for (final w in sortedWithdrawals) w: withdrawals[w]!.status.name,
      },
      'netWorth': netWorth.totalCents,
    };
  }
}
