/// The single source of truth for "what is true now": a pure function
/// `List<Event> -> HouseholdState`. Everything time-based is computed here at
/// read time; there are no scheduled jobs. Pure Dart, zero Flutter imports.
///
/// The reduction is one library split by concern: this file gathers the
/// events and orchestrates the derivation; each `reducer/` part derives one
/// area of the ledger (purchases, the month sweep, savings rules, quests…) as
/// an extension on the same private builder, so every part reads and writes
/// the same running balances in a fixed, deterministic order.
library;

import 'event.dart';
import 'money.dart';
import 'pools.dart';
import 'state.dart';
import 'time.dart';
import 'value_types.dart';

part 'reducer/approvals.dart';
part 'reducer/emergency_funds.dart';
part 'reducer/household_config.dart';
part 'reducer/household_shares.dart';
part 'reducer/month_sweep.dart';
part 'reducer/net_worth.dart';
part 'reducer/overbudget.dart';
part 'reducer/purchases.dart';
part 'reducer/quests.dart';
part 'reducer/recurring.dart';
part 'reducer/savings_economy.dart';
part 'reducer/spoils.dart';
part 'reducer/vacations.dart';
part 'reducer/vaults_and_war_chest.dart';

/// Reduces the event log to the derived household state as of [asOf]
/// (defaults to now). The reduction is deterministic and order-independent:
/// events are de-duplicated by id and sorted internally.
HouseholdState reduce(List<Event> events, {DateTime? asOf}) {
  final now = (asOf ?? DateTime.now()).toUtc();

  // Idempotency: keep one event per id. Total order: (occurredAt, eventId).
  final seenIds = <String>{};
  final ordered = <Event>[];
  for (final event in events) {
    if (seenIds.add(event.eventId)) {
      ordered.add(event);
    }
  }
  ordered.sort((first, second) {
    final byTime = first.occurredAt.compareTo(second.occurredAt);
    return byTime != 0 ? byTime : first.eventId.compareTo(second.eventId);
  });

  final builder = _HouseholdStateBuilder(now);
  for (final event in ordered) {
    builder.gather(event);
  }
  return builder.build();
}

/// Mutable accumulator that gathers events, then derives the read-model.
class _HouseholdStateBuilder {
  _HouseholdStateBuilder(this.now);

  final DateTime now;

  Settings settings = const Settings();
  final Set<String> userIds = {};

  // Last-writer-wins configuration by id.
  final Map<String, MainCategorySet> mainCategoryConfigs = {};
  final Map<String, SliceConfig> slices = {};
  final Map<String, QuestSet> questConfigs = {};
  final Map<String, EmergencyFundSet> fundConfigs = {};
  final Map<String, PetSet> petConfigs = {};
  final Map<String, MemberSet> memberConfigs = {};

  // Vacations: last-writer-wins config by id, plus the set of closed ones.
  final Map<String, VacationSet> vacationConfigs = {};
  final Set<String> closedVacations = {};

  // Per-adult share tables, last-writer-wins per month key.
  final Map<String, GroupShareSet> shareSets = {};
  final Map<String, RecurringExpenseSet> recurringConfigs = {};
  final Map<String, AccountBalanceRecorded> latestAccountBalances = {};
  final Map<String, TrackedAccountSet> accountConfigs = {};
  final List<AccountTransferRecorded> accountTransfers = [];

  // Purchases and their receipts. Receipt attach/detach events are buffered
  // here and applied once all purchases are gathered (see [_applyReceipts]).
  final Map<String, _PurchaseAccumulator> purchases = {};
  final List<Event> _receiptEvents = [];

  // Variable-expense actuals, keyed "expenseId|month".
  final Map<String, int> variableActuals = {};

  // Leftover allocations, keyed "userId|sliceId|month" (last writer wins).
  final Map<String, LeftoverAllocated> allocations = {};

  // Quest lifecycle: abandoned quests and the instant each was abandoned.
  final Set<String> abandonedQuests = {};
  final Map<String, DateTime> _abandonInstants = {};

  // Gifts, contributions, refunds, income.
  final List<GiftReceived> gifts = [];
  final List<PoolContributionMade> contributions = [];
  final List<TaxRefundRecorded> taxRefunds = [];
  final Map<String, int> income = {}; // "userId|month" -> cents
  // Default incomes, keyed "userId|effectiveFromMonth" (last writer wins).
  final Map<String, DefaultIncomeSet> defaultIncomeConfigs = {};

  // Withdrawals.
  final Map<String, PoolWithdrawalProposed> withdrawalProposals = {};
  final Map<String, List<PoolWithdrawalApproved>> withdrawalApprovals = {};
  final Set<String> cancelledWithdrawals = {};

  int? goalTarget;

  // Savings-rule general rates keyed by the 'yyyy-MM' month they take effect.
  final Map<String, int> savingsRuleRates = {};

  SavingsRules? get savingsRules {
    if (savingsRuleRates.isEmpty) return null;
    final adoptionMonth = savingsRuleRates.keys
        .map(Month.parse)
        .reduce(
          (earliest, month) => earliest.isBefore(month) ? earliest : month,
        );
    return SavingsRules(
      fromMonth: adoptionMonth,
      generalPctByFromMonth: savingsRuleRates,
    );
  }

  // Savings economy (applied only from the adoption month).
  final List<ShortfallCovered> shortfallCovers = [];
  final Map<String, AllowanceAdvanceProposed> advanceProposals = {};
  final Map<String, List<AllowanceAdvanceApproved>> advanceApprovals = {};
  final Set<String> cancelledAdvances = {};

  void _noteUser(String? userId) {
    if (userId != null) {
      userIds.add(userId);
    }
  }

  void gather(Event event) {
    // A newer release's event: relayed, never interpreted (not even its author).
    if (event is UnknownEvent) return;
    _noteUser(event.userId);
    switch (event) {
      case PurchaseAdded():
        _noteUser(event.userId);
        purchases.putIfAbsent(
          event.purchaseId,
          () => _PurchaseAccumulator(event),
        );
      case PurchaseVoided():
        final purchase = purchases[event.purchaseId];
        if (purchase != null) {
          purchase.voided = true;
        }
      case ReceiptAttached():
      case ReceiptDetached():
        // Buffer receipt events and bind them after every purchase has been
        // gathered, so a receipt whose envelope happens to sort before its
        // purchase (same `occurredAt`, id tie-break) still attaches. Keeps the
        // reduction order-independent.
        _receiptEvents.add(event);
      case BudgetSliceSet():
        _gatherSliceConfig(event);
      case MainCategorySet():
        mainCategoryConfigs[event.id] = event;
      case RecurringExpenseSet():
        if (event.ownership is PersonalParty) {
          _noteUser((event.ownership as PersonalParty).userId);
        }
        recurringConfigs[event.expenseId] = event;
      case VariableExpenseRecorded():
        variableActuals['${event.expenseId}|${event.month.toKey()}'] =
            event.actualCents;
      case IncomeSet():
        _noteUser(event.forUserId);
        income['${event.forUserId}|${event.month.toKey()}'] = event.amountCents;
      case DefaultIncomeSet():
        _noteUser(event.forUserId);
        defaultIncomeConfigs['${event.forUserId}|${event.effectiveFromMonth.toKey()}'] =
            event;
      case QuestSet():
        if (event.ownership is PersonalParty) {
          _noteUser((event.ownership as PersonalParty).userId);
        }
        questConfigs[event.questId] = event;
      case QuestAbandoned():
        abandonedQuests.add(event.questId);
        _abandonInstants[event.questId] = event.occurredAt;
      case LeftoverAllocated():
        _noteUser(event.forUserId);
        allocations['${event.forUserId}|${event.sliceId}|${event.month.toKey()}'] =
            event;
      case GiftReceived():
        _noteUser(event.forUserId);
        gifts.add(event);
      case PoolContributionMade():
        _noteUser(event.fromUserId);
        contributions.add(event);
      case PoolWithdrawalProposed():
        _noteUser(event.byUserId);
        if (event.destination is UserVaultDestination) {
          _noteUser((event.destination as UserVaultDestination).userId);
        }
        withdrawalProposals[event.proposalId] = event;
      case PoolWithdrawalApproved():
        _noteUser(event.byUserId);
        withdrawalApprovals.putIfAbsent(event.proposalId, () => []).add(event);
      case PoolWithdrawalCancelled():
        cancelledWithdrawals.add(event.proposalId);
      case TaxRefundRecorded():
        taxRefunds.add(event);
      case EmergencyFundSet():
        fundConfigs[event.fundId] = event;
      case PetSet():
        petConfigs[event.petId] = event;
      case MemberSet():
        memberConfigs[event.memberId] = event;
        // Adults carry a ledger, so they must be known users (even when
        // retired, so a prior balance still surfaces). Dependents and pets do
        // not — they never get a vault.
        if (event.role == MemberRole.adult) {
          _noteUser(event.memberId);
        }
      case GroupShareSet():
        shareSets[event.month.toKey()] = event;
      case GoalSet():
        goalTarget = event.targetCents;
      case TrackedAccountSet():
        accountConfigs[event.accountId] = event;
      case AccountBalanceRecorded():
        latestAccountBalances[event.accountId] = event;
      case AccountTransferRecorded():
        accountTransfers.add(event);
      case VacationSet():
        vacationConfigs[event.vacationId] = event;
      case VacationClosed():
        closedVacations.add(event.vacationId);
      case SettingChanged():
        _applySetting(event);
      case CosmeticSet():
        break; // domain-inert
      case GameRewardGranted():
        break; // cosmetic reward — the firewall: never touches a cent
      case NoSpendCheckedIn():
      case ReconcileCompleted():
        break; // habit markers — money-inert
      case ShortfallCovered():
        shortfallCovers.add(event);
      case AllowanceAdvanceProposed():
        _noteUser(event.byUserId);
        advanceProposals[event.advanceId] = event;
      case AllowanceAdvanceApproved():
        _noteUser(event.byUserId);
        advanceApprovals.putIfAbsent(event.advanceId, () => []).add(event);
      case AllowanceAdvanceCancelled():
        cancelledAdvances.add(event.advanceId);
      case UnknownEvent():
        break; // unreachable: returned above
    }
  }

  /// Records a category's latest configuration, keeping the earliest month
  /// it was ever configured in as its creation month.
  void _gatherSliceConfig(BudgetSliceSet event) {
    final existing = slices[event.sliceId];
    final createdMonth = existing == null
        ? event.occurredMonth
        : (existing.createdMonth.isBefore(event.occurredMonth)
              ? existing.createdMonth
              : event.occurredMonth);
    if (event.ownership is PersonalSlice) {
      _noteUser((event.ownership as PersonalSlice).userId);
    }
    slices[event.sliceId] = SliceConfig(
      sliceId: event.sliceId,
      name: event.name,
      ownership: event.ownership,
      mainCategoryId: event.mainCategoryId,
      limitCents: event.limitCents,
      poolTithePct: event.poolTithePct,
      defaultLeftoverPolicy: event.defaultLeftoverPolicy,
      taxDeductibleByDefault: event.taxDeductibleByDefault,
      createdMonth: createdMonth,
      emergencyFundId: event.emergencyContribution?.fundId,
      emergencyContributionCents: event.emergencyContribution?.amountCents ?? 0,
      petId: event.petId,
      petOwnerIds: event.petOwnerIds,
      priority: event.priority,
    );
  }

  void _applySetting(SettingChanged event) {
    final value = event.value;
    switch (event.key) {
      case 'spoilsGraceDays':
        if (value is int) settings = settings.copyWith(spoilsGraceDays: value);
      case 'dissolutionTithePct':
        if (value is int) {
          settings = settings.copyWith(dissolutionTithePct: value);
        }
      case 'showNetWorth':
        if (value is bool) settings = settings.copyWith(showNetWorth: value);
      case 'savingsRules':
        if (value is Map) {
          final fromMonth = value['fromMonth'];
          final generalPct = value['generalTithePct'];
          if (fromMonth is String &&
              generalPct is int &&
              generalPct >= 0 &&
              generalPct <= 100) {
            try {
              savingsRuleRates[Month.parse(fromMonth).toKey()] = generalPct;
            } on FormatException {
              // Malformed month: ignore the entry.
            }
          }
        }
    }
  }

  // ---- Derivation -------------------------------------------------------

  // Running balances.
  final Map<String, int> vault = {};
  int warChest = 0;
  final Map<String, int> chestMonthlyNet = {}; // "yyyy-MM" -> net inflow
  final Map<String, int> questBalance = {};
  final Map<String, Map<String, int>> questContributions = {};
  final Map<String, SliceMonth> sliceMonths = {};
  final Map<String, int> recurringByUserMonth = {};
  final List<RansackRecord> ransacks = [];

  // OVERBUDGET settlement. Debts are per personal category. [availableVault]
  // mirrors each vault chronologically inside the month sweep — month-bucketed
  // external flows ([vaultFlowByMonth]) plus in-sweep discretionary
  // conversions — so close-time seizure never takes money the owner did not
  // have yet. Abandoned-quest returns are computed after the sweep and are
  // deliberately left out, so seizure only ever errs on the small side.
  final Map<String, int> availableVault = {};
  final Map<String, Map<String, int>> vaultFlowByMonth = {};
  final Map<String, int> debtBySlice = {};
  final Map<String, int> debtAccrued = {};
  final Map<String, String> debtOwner = {};
  final Map<String, DebtKind> debtKind = {};

  // Savings economy (from the adoption month): each personal category's
  // savings pool, spending covered from elsewhere and advance repayments
  // (both keyed "sliceId|yyyy-MM").
  final Map<String, TaxedBalance> savings = {};
  final Map<String, int> coverBySliceMonth = {};
  final Map<String, int> trimBySliceMonth = {};
  final Map<String, int> trimRollover = {};

  // Annual-accrual reserves: the running reserve per annual expense (also the
  // as-of-now snapshot, since it is only advanced for months that have started)
  // and each expense's most recent due-month reconciliation.
  final Map<String, int> annualReserveByExpense = {};
  final Map<String, AnnualDueReconciliation> annualReconByExpense = {};

  /// Debt minimum payments surfaced as shared recurring expenses.
  final List<_DerivedRecurring> derivedRecurring = [];

  /// Buckets a vault movement into [month] for the seizure-availability model.
  void _recordVaultFlow(String userId, Month month, int amountCents) {
    final bucket = vaultFlowByMonth.putIfAbsent(month.toKey(), () => {});
    bucket[userId] = (bucket[userId] ?? 0) + amountCents;
  }

  /// Whether [month] has fully ended as of the read time.
  bool _isClosed(Month month) => !now.isBefore(month.endInstantUtc());

  void _addChest(int amountCents, Month month) {
    warChest += amountCents;
    final monthKey = month.toKey();
    chestMonthlyNet[monthKey] = (chestMonthlyNet[monthKey] ?? 0) + amountCents;
  }

  void _addVault(String userId, int amountCents) {
    vault[userId] = (vault[userId] ?? 0) + amountCents;
  }

  /// Credits [userId]'s vault with money created inside the month sweep, so it
  /// is also immediately available to a later close-time seizure.
  void _creditVaultDuringSweep(String userId, int amountCents) {
    _addVault(userId, amountCents);
    availableVault[userId] = (availableVault[userId] ?? 0) + amountCents;
  }

  HouseholdState build() {
    _applyReceipts();
    final rules = savingsRules;
    for (final userId in userIds) {
      vault.putIfAbsent(userId, () => 0);
    }

    _deriveDebtMinimumPayments();
    final spending = _tallyPurchaseSpending();
    final vacationDrawByFund = _reserveVacationFunds(spending);
    final questCoversBySliceMonth = _applyShortfallCovers(rules);
    // Withdrawals resolve before the sweep so approved vault credits enter the
    // seizure-availability model in their approval month.
    final withdrawals = _resolveWithdrawals();
    final advanceStates = _resolveAdvances(rules);
    _bucketGiftAndContributionFlows();

    final range = _monthRange();
    final fundSchedule = range == null
        ? <String, List<_FundContribution>>{}
        : _sweepMonths(
            range,
            _SweepContext(
              rules: rules,
              spending: spending,
              questCoversBySliceMonth: questCoversBySliceMonth,
              sortedSlices: slices.values.toList()
                ..sort(
                  (first, second) => first.sliceId.compareTo(second.sliceId),
                ),
            ),
          );

    _applyGiftsContributionsAndRefunds();
    final questStates = _settleQuests(spending.questDrawdown);
    final fundStates = _settleEmergencyFunds(
      fundSchedule,
      vacationDrawByFund,
      spending.emergencyPurchases,
    );
    final (:clampedVaults, :inconsistentVaults) = _clampVaults();
    final members = _memberStates();

    return HouseholdState(
      settings: settings,
      userIds: userIds,
      members: members,
      mainCategories: _mainCategories(),
      slices: slices,
      sliceMonths: sliceMonths,
      quests: questStates,
      emergencyFunds: fundStates,
      pets: _petStates(members),
      withdrawals: withdrawals,
      overbudgets: _overbudgetStates(),
      warChest: WarChestState(
        balanceCents: warChest,
        targetCents: goalTarget,
        goal: _warChestGoal(range),
      ),
      vaultCents: clampedVaults,
      inconsistentVaults: inconsistentVaults,
      ransacks: ransacks,
      purchases: _purchaseStates(),
      netWorth: _netWorth(),
      deductibleByYear: _deductiblePurchasesByYear(),
      recurringByUserMonth: recurringByUserMonth,
      incomeByUserMonth: income,
      incomeDefaultsByUser: _incomeDefaultsByUser(),
      recurringExpenses: _recurringExpenseStates(range),
      variableActuals: Map<String, int>.from(variableActuals),
      vacations: _vacationStates(spending, questStates, fundStates),
      savingsRules: rules,
      categorySavings: Map.unmodifiable(savings),
      advances: advanceStates,
    );
  }
}
