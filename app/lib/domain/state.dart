/// `HouseholdState` and its parts: the derived read-model produced by the
/// reducer. Nothing here mutates; the reducer builds a fresh snapshot from the
/// event log every time. Pure Dart, zero Flutter imports.
///
/// This file holds [HouseholdState] and [Settings]; the per-area read-models
/// (categories, recurring and income, quests, emergency funds, vacations, war
/// chest, members, purchases, net worth, savings rules) are `state/` parts.
library;

import 'pools.dart';
import 'time.dart';
import 'value_types.dart';

part 'state/categories.dart';
part 'state/emergency_funds.dart';
part 'state/members.dart';
part 'state/net_worth.dart';
part 'state/purchases.dart';
part 'state/quests.dart';
part 'state/recurring_and_income.dart';
part 'state/savings_rules.dart';
part 'state/vacations.dart';
part 'state/war_chest.dart';

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

  Settings copyWith({
    int? spoilsGraceDays,
    int? dissolutionTithePct,
    bool? showNetWorth,
  }) => Settings(
    spoilsGraceDays: spoilsGraceDays ?? this.spoilsGraceDays,
    dissolutionTithePct: dissolutionTithePct ?? this.dissolutionTithePct,
    showNetWorth: showNetWorth ?? this.showNetWorth,
  );
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
    required this.overbudgets,
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
    required this.vacations,
    this.savingsRules,
    this.categorySavings = const {},
    this.advances = const {},
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

  /// OVERBUDGET debts keyed by sliceId — every category whose overspending
  /// ever became debt, settled or not. Visible to all adults.
  final Map<String, OverbudgetState> overbudgets;
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

  /// Vacations (open and closed), keyed by `vacationId`.
  final Map<String, VacationState> vacations;

  /// The savings-economy rules, or null when the household hasn't adopted them
  /// (every month then reduces with the legacy math).
  final SavingsRules? savingsRules;

  /// Savings rules only: each personal category's savings pool right now (the
  /// already-taxed money it holds), keyed by sliceId.
  final Map<String, TaxedBalance> categorySavings;

  /// Savings rules only: requests to borrow from future months, keyed by id.
  final Map<String, AdvanceState> advances;

  /// The currently-open vacations, sorted by name — the ones quick entry offers
  /// a charge target for and the dashboard boards while a trip is under way.
  List<VacationState> get openVacations =>
      (vacations.values.where((vacation) => vacation.isOpen).toList())
        ..sort((first, second) => first.name.compareTo(second.name));

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
      for (final member in members.values)
        if (member.isAdult && member.active) member.memberId,
    };
    return declared.isNotEmpty ? declared : userIds;
  }

  int vaultOf(String userId) => vaultCents[userId] ?? 0;

  /// The outstanding OVERBUDGET debts owned by [userId], sorted by sliceId.
  List<OverbudgetState> outstandingOverbudgetsFor(String userId) =>
      (overbudgets.values
            .where((debt) => debt.ownerUserId == userId && !debt.settled)
            .toList())
        ..sort((first, second) => first.sliceId.compareTo(second.sliceId));

  /// Every outstanding OVERBUDGET in the household, sorted by sliceId.
  List<OverbudgetState> get outstandingOverbudgets =>
      (overbudgets.values
            .where((debt) => !debt.settled && debt.kind == DebtKind.overbudget)
            .toList())
        ..sort((first, second) => first.sliceId.compareTo(second.sliceId));

  /// Variable-bill top-ups still owed (paid from next month's leftovers;
  /// never shown as a monster or as overspending).
  List<OverbudgetState> get outstandingProvisions =>
      (overbudgets.values
            .where((debt) => !debt.settled && debt.kind == DebtKind.provisions)
            .toList())
        ..sort((first, second) => first.sliceId.compareTo(second.sliceId));

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

  /// The full default-income record in effect for [userId] as of [month] —
  /// the latest default whose effective month is on or before [month] — or
  /// null when no default has taken effect yet. Carries the estimated range
  /// for variable earners.
  DefaultIncome? effectiveIncomeDefault(String userId, Month month) {
    final defaults = incomeDefaultsByUser[userId];
    if (defaults == null) {
      return null;
    }
    DefaultIncome? best;
    for (final defaultIncome in defaults) {
      // Sorted ascending: keep the last one that is already effective.
      if (!defaultIncome.effectiveFromMonth.isAfter(month)) {
        best = defaultIncome;
      } else {
        break;
      }
    }
    return best;
  }

  /// The default monthly income in effect for [userId] as of [month], or null
  /// when no default has taken effect yet.
  int? defaultIncomeFor(String userId, Month month) =>
      effectiveIncomeDefault(userId, month)?.amountCents;

  /// Resolved income for [userId] in [month]: a single-month override wins,
  /// else the latest effective default, else zero.
  int incomeFor(String userId, Month month) =>
      incomeOverrideFor(userId, month) ?? defaultIncomeFor(userId, month) ?? 0;

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
      'vaults': {for (final userId in sortedVaults) userId: vaultCents[userId]},
      'inconsistentVaults': (inconsistentVaults.toList()..sort()),
      'quests': {
        for (final questId in sortedQuests)
          questId: {
            'balance': quests[questId]!.balanceCents,
            'completed': quests[questId]!.completed,
            'abandoned': quests[questId]!.abandoned,
          },
      },
      'funds': {
        for (final fundId in sortedFunds)
          fundId: emergencyFunds[fundId]!.balanceCents,
      },
      'ransacks': ransacks.length,
      'ransackExcess': ransacks.fold<int>(
        0,
        (sum, ransack) => sum + ransack.excessCents,
      ),
      'overbudgets': {
        for (final sliceId in overbudgets.keys.toList()..sort())
          sliceId: {
            'accrued': overbudgets[sliceId]!.accruedCents,
            'outstanding': overbudgets[sliceId]!.outstandingCents,
          },
      },
      'sliceMonths': {
        for (final sliceMonthKey in sortedSliceMonths)
          sliceMonthKey: {
            'eff': sliceMonths[sliceMonthKey]!.effectiveLimitCents,
            'spent': sliceMonths[sliceMonthKey]!.spentCents,
            'leftover': sliceMonths[sliceMonthKey]!.leftoverCents,
            'carryOut': sliceMonths[sliceMonthKey]!.carryOutCents,
          },
      },
      'withdrawals': {
        for (final withdrawalId in sortedWithdrawals)
          withdrawalId: withdrawals[withdrawalId]!.status.name,
      },
      'netWorth': netWorth.totalCents,
    };
  }
}
