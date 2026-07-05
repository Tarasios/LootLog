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

/// The configuration of a budget slice, plus the month it first appeared.
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
  });

  final String expenseId;
  final String name;
  final PartyOwnership ownership;
  final RecurringKind kind;

  /// The fixed amount, or the estimate for a variable expense.
  final int amountCents;
  final Month startMonth;
  final Month? endMonth;

  bool get isShared => ownership is SharedParty;

  String? get ownerUserId =>
      ownership is PersonalParty ? (ownership as PersonalParty).userId : null;

  /// Whether this expense is expected to run in [month].
  bool activeIn(Month month) =>
      !startMonth.isAfter(month) &&
      (endMonth == null || !month.isAfter(endMonth!));
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
    this.sliceHint,
    this.customSpriteSha256,
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
  final String? sliceHint;
  final String? customSpriteSha256;

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

/// A tracked net-worth account balance (latest recorded value).
class AccountBalance {
  const AccountBalance({
    required this.accountId,
    required this.name,
    required this.kind,
    required this.balanceCents,
  });

  final String accountId;
  final String name;
  final AccountKind kind;
  final int balanceCents;

  /// Debt contributes negatively to net worth.
  int get signedCents => kind == AccountKind.debt ? -balanceCents : balanceCents;
}

/// Net-worth summary derived from the latest balance per account.
class NetWorthState {
  const NetWorthState({
    required this.accounts,
    required this.totalCents,
    required this.show,
  });

  final Map<String, AccountBalance> accounts;
  final int totalCents;
  final bool show;
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

/// The full derived read-model of the household.
class HouseholdState {
  const HouseholdState({
    required this.settings,
    required this.userIds,
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
    required this.recurringExpenses,
    required this.variableActuals,
  });

  final Settings settings;
  final Set<String> userIds;
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

  /// Income keyed by `"userId|yyyy-MM"`.
  final Map<String, int> incomeByUserMonth;

  /// Recurring-expense configuration, keyed by `expenseId`.
  final Map<String, RecurringExpenseState> recurringExpenses;

  /// Recorded variable-expense actuals, keyed by `"expenseId|yyyy-MM"`.
  final Map<String, int> variableActuals;

  static String monthKey(String id, Month month) => '$id|${month.toKey()}';

  /// The recorded actual for a variable recurring expense in [month], or null
  /// when none has been recorded yet (the estimate still stands).
  int? variableActualFor(String expenseId, Month month) =>
      variableActuals[monthKey(expenseId, month)];

  int vaultOf(String userId) => vaultCents[userId] ?? 0;

  bool isVaultInconsistent(String userId) =>
      inconsistentVaults.contains(userId);

  SliceMonth? sliceMonth(String sliceId, Month month) =>
      sliceMonths[monthKey(sliceId, month)];

  int recurringChargeFor(String userId, Month month) =>
      recurringByUserMonth[monthKey(userId, month)] ?? 0;

  int incomeFor(String userId, Month month) =>
      incomeByUserMonth[monthKey(userId, month)] ?? 0;

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
