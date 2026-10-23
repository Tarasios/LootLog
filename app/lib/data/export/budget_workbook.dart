/// Builds the offline `.xlsx` budget workbook — a pure projection over the
/// derived [HouseholdState], one sheet per the documented export contents:
/// Transactions, Monthly summary, Members & income, Savings goals, Net worth,
/// and Recurring expenses.
///
/// Like every LootLog read model this computes nothing itself: the reducer
/// already did the money math, and this only groups and labels it. Every money
/// figure is emitted with [Money.format] as a cents-derived decimal string, so
/// no amount is ever carried as a `double`.
///
/// Pure Dart, zero Flutter imports: the whole thing is unit-testable end to end.
library;

import '../../domain/money.dart';
import '../../domain/report.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';
import 'xlsx.dart';

/// The six workbook sheet names, in export order.
const String kTransactionsSheet = 'Transactions';
const String kMonthlySummarySheet = 'Monthly summary';
const String kMembersIncomeSheet = 'Members & income';
const String kSavingsGoalsSheet = 'Savings goals';
const String kNetWorthSheet = 'Net worth';
const String kRecurringSheet = 'Recurring expenses';

/// Builds the full budget workbook from [state]. [userNames] maps adult user ids
/// to display names for the human-readable columns. [asOfMonth] fixes the month
/// used to resolve each adult's "current" income; when null it is derived from
/// the latest month present in the data (falling back to the latest income
/// default), keeping the output a deterministic function of the ledger.
XlsxWorkbook buildBudgetWorkbook(
  HouseholdState state, {
  required Map<String, String> userNames,
  Month? asOfMonth,
}) {
  final months = _monthsInScope(state);
  final incomeMonth = asOfMonth ?? _latestIncomeMonth(state, months);
  return XlsxWorkbook([
    _transactionsSheet(state, userNames),
    _monthlySummarySheet(state, userNames, months),
    _membersIncomeSheet(state, userNames, incomeMonth),
    _savingsGoalsSheet(state, userNames),
    _netWorthSheet(state),
    _recurringSheet(state, userNames),
  ]);
}

// ---------------------------------------------------------------------------
// Transactions
// ---------------------------------------------------------------------------

XlsxSheet _transactionsSheet(
  HouseholdState state,
  Map<String, String> names,
) {
  final purchases = state.purchases.values.toList()
    ..sort((first, second) {
      final byTime = first.occurredAt.compareTo(second.occurredAt);
      return byTime != 0 ? byTime : first.purchaseId.compareTo(second.purchaseId);
    });
  return XlsxSheet(
    name: kTransactionsSheet,
    header: const [
      'Date',
      'Month',
      'Member',
      'Charged to',
      'Merchant',
      'Amount',
      'Shared',
      'Tax deductible',
      'Voided',
      'Note',
    ],
    rows: [
      for (final purchase in purchases)
        [
          XlsxCell.text(_householdDay(purchase.occurredAt)),
          XlsxCell.text(purchase.month.toKey()),
          XlsxCell.text(names[purchase.userId] ?? purchase.userId),
          XlsxCell.text(_targetLabel(state, purchase.target, names)),
          XlsxCell.text(purchase.merchant),
          XlsxCell.number(Money(purchase.amountCents).format()),
          XlsxCell.text(_yesNo(purchase.shared)),
          XlsxCell.text(_taxLabel(purchase.taxDeductible)),
          XlsxCell.text(_yesNo(purchase.voided)),
          XlsxCell.text(purchase.note),
        ],
    ],
  );
}

String _targetLabel(
  HouseholdState state,
  ChargeTarget target,
  Map<String, String> names,
) {
  switch (target) {
    case SliceCharge(:final sliceId):
      return state.slices[sliceId]?.name ?? sliceId;
    case VaultCharge():
      return 'Vault';
    case QuestCharge(:final questId):
      return state.quests[questId]?.name ?? questId;
    case EmergencyCharge(:final fundId):
      return state.emergencyFunds[fundId]?.name ?? fundId;
    case VacationCharge(:final vacationId, :final categoryId):
      final vac = state.vacations[vacationId];
      final cat = vac?.categories
          .where((category) => category.categoryId == categoryId)
          .firstOrNull;
      final vacName = vac?.name ?? vacationId;
      final catName = cat?.name ?? categoryId;
      return 'Vacation: $vacName / $catName';
  }
}

// ---------------------------------------------------------------------------
// Monthly summary (per category budgeted / spent / leftover)
// ---------------------------------------------------------------------------

XlsxSheet _monthlySummarySheet(
  HouseholdState state,
  Map<String, String> names,
  List<Month> months,
) {
  final rows = <List<XlsxCell>>[];
  for (final month in months) {
    final report = buildMonthReport(state, month);
    for (final row in report.categories) {
      rows.add([
        XlsxCell.text(month.toKey()),
        XlsxCell.text(row.name),
        XlsxCell.text(_mainCategoryName(state, row.mainCategoryId)),
        XlsxCell.text(_scopeLabel(row.isGroup, row.ownerUserId, names)),
        XlsxCell.number(Money(row.budgetedCents).format()),
        XlsxCell.number(Money(row.spentCents).format()),
        XlsxCell.number(Money(row.leftoverCents).format()),
      ]);
    }
  }
  return XlsxSheet(
    name: kMonthlySummarySheet,
    header: const [
      'Month',
      'Category',
      'Main category',
      'Owner',
      'Budgeted',
      'Spent',
      'Leftover',
    ],
    rows: rows,
  );
}

// ---------------------------------------------------------------------------
// Members & income
// ---------------------------------------------------------------------------

XlsxSheet _membersIncomeSheet(
  HouseholdState state,
  Map<String, String> names,
  Month? incomeMonth,
) {
  final members = state.members.values.toList()
    ..sort((first, second) {
      // Adults first, then dependents, then pets; ties broken by name.
      final byRole = first.role.index.compareTo(second.role.index);
      return byRole != 0 ? byRole : first.name.compareTo(second.name);
    });
  return XlsxSheet(
    name: kMembersIncomeSheet,
    header: const [
      'Member',
      'Role',
      'Active',
      'Monthly income',
    ],
    rows: [
      for (final member in members)
        [
          XlsxCell.text(member.name),
          XlsxCell.text(member.role.name),
          XlsxCell.text(_yesNo(member.active)),
          if (member.isAdult && incomeMonth != null)
            XlsxCell.number(Money(state.incomeFor(member.memberId, incomeMonth)).format())
          else
            XlsxCell.empty,
        ],
    ],
  );
}

// ---------------------------------------------------------------------------
// Savings goals (quests)
// ---------------------------------------------------------------------------

XlsxSheet _savingsGoalsSheet(
  HouseholdState state,
  Map<String, String> names,
) {
  final quests = state.quests.values.toList()
    ..sort((first, second) => first.name.compareTo(second.name));
  return XlsxSheet(
    name: kSavingsGoalsSheet,
    header: const [
      'Goal',
      'Main category',
      'Owner',
      'Target',
      'Balance',
      'Remaining',
      'Percent complete',
      'Status',
    ],
    rows: [
      for (final quest in quests)
        [
          XlsxCell.text(quest.name),
          XlsxCell.text(_mainCategoryName(state, quest.mainCategoryId)),
          XlsxCell.text(_partyLabel(quest.ownership, names)),
          XlsxCell.number(Money(quest.targetCents).format()),
          XlsxCell.number(Money(quest.balanceCents).format()),
          XlsxCell.number(Money(_remaining(quest.targetCents, quest.balanceCents)).format()),
          XlsxCell.number('${_percent(quest.balanceCents, quest.targetCents)}'),
          XlsxCell.text(_questStatus(quest)),
        ],
    ],
  );
}

// ---------------------------------------------------------------------------
// Net worth (tracked accounts)
// ---------------------------------------------------------------------------

XlsxSheet _netWorthSheet(HouseholdState state) {
  final accounts = state.netWorth.accounts.values.toList()
    ..sort((first, second) => first.name.compareTo(second.name));
  final rows = <List<XlsxCell>>[
    for (final account in accounts)
      [
        XlsxCell.text(account.name),
        XlsxCell.text(account.kind.name),
        XlsxCell.number(Money(account.currentValueCents).format()),
        XlsxCell.number(Money(account.balanceCents).format()),
        XlsxCell.number(Money(account.accruedInterestCents).format()),
        // APR is basis points: divide by 100 the same way cents make dollars.
        account.aprBps != null ? XlsxCell.number(Money(account.aprBps!).format()) : XlsxCell.empty,
        XlsxCell.text(_yesNo(account.stale)),
        account.minPaymentCents != null
            ? XlsxCell.number(Money(account.minPaymentCents!).format())
            : XlsxCell.empty,
        XlsxCell.number(Money(account.signedCents).format()),
      ],
  ];
  // A closing total row: the signed household net worth.
  rows.add([
    XlsxCell.text('Total (net worth)', bold: true),
    XlsxCell.empty,
    XlsxCell.empty,
    XlsxCell.empty,
    XlsxCell.empty,
    XlsxCell.empty,
    XlsxCell.empty,
    XlsxCell.empty,
    XlsxCell.number(Money(state.netWorth.totalCents).format(), bold: true),
  ]);
  return XlsxSheet(
    name: kNetWorthSheet,
    header: const [
      'Account',
      'Kind',
      'Current value',
      'Recorded balance',
      'Accrued interest',
      'APR %',
      'Stale',
      'Minimum payment',
      'Net worth contribution',
    ],
    rows: rows,
  );
}

// ---------------------------------------------------------------------------
// Recurring expenses
// ---------------------------------------------------------------------------

XlsxSheet _recurringSheet(
  HouseholdState state,
  Map<String, String> names,
) {
  final expenses = state.recurringExpenses.values.toList()
    ..sort((first, second) => first.name.compareTo(second.name));
  return XlsxSheet(
    name: kRecurringSheet,
    header: const [
      'Name',
      'Owner',
      'Kind',
      'Cadence',
      'Amount',
      'Due day',
      'Due month',
      'Start month',
      'End month',
    ],
    rows: [
      for (final expense in expenses)
        [
          XlsxCell.text(expense.name),
          XlsxCell.text(_partyLabel(expense.ownership, names)),
          XlsxCell.text(expense.kind.name),
          XlsxCell.text(expense.cadence.name),
          XlsxCell.number(Money(expense.amountCents).format()),
          XlsxCell.number('${expense.dueDay}'),
          expense.dueMonth != null ? XlsxCell.number('${expense.dueMonth}') : XlsxCell.empty,
          XlsxCell.text(expense.startMonth.toKey()),
          expense.endMonth != null ? XlsxCell.text(expense.endMonth!.toKey()) : XlsxCell.empty,
        ],
    ],
  );
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Every month with derived slice-month or purchase activity, sorted ascending.
List<Month> _monthsInScope(HouseholdState state) {
  final keys = <String>{};
  for (final key in state.sliceMonths.keys) {
    final month = key.split('|').last;
    keys.add(month);
  }
  for (final purchase in state.purchases.values) {
    keys.add(purchase.month.toKey());
  }
  final months = keys.map(Month.parse).toList()..sort();
  return months;
}

/// The month used to resolve "current" income: the latest month in scope, else
/// the latest income-default effective month, else null (income shown blank).
Month? _latestIncomeMonth(HouseholdState state, List<Month> monthsInScope) {
  Month? latest = monthsInScope.isNotEmpty ? monthsInScope.last : null;
  for (final defaults in state.incomeDefaultsByUser.values) {
    for (final defaultIncome in defaults) {
      if (latest == null || defaultIncome.effectiveFromMonth.isAfter(latest)) {
        latest = defaultIncome.effectiveFromMonth;
      }
    }
  }
  return latest;
}

String _mainCategoryName(HouseholdState state, String? mainCategoryId) {
  if (mainCategoryId == null) return uncategorizedMainCategory.name;
  return state.mainCategories[mainCategoryId]?.name ??
      uncategorizedMainCategory.name;
}

String _scopeLabel(bool isGroup, String? ownerUserId, Map<String, String> names) {
  if (isGroup) return 'Group';
  if (ownerUserId == null) return 'Group';
  return names[ownerUserId] ?? ownerUserId;
}

String _partyLabel(PartyOwnership ownership, Map<String, String> names) {
  switch (ownership) {
    case SharedParty():
      return 'Shared';
    case PersonalParty(:final userId):
      return names[userId] ?? userId;
  }
}

int _remaining(int targetCents, int balanceCents) {
  final remaining = targetCents - balanceCents;
  return remaining > 0 ? remaining : 0;
}

/// Integer percent complete with truncating division — no float involved.
int _percent(int balanceCents, int targetCents) =>
    targetCents > 0 ? (balanceCents * 100) ~/ targetCents : 0;

String _questStatus(QuestState quest) {
  if (quest.abandoned) return 'Abandoned';
  if (quest.completed) return 'Completed';
  return 'Active';
}

String _taxLabel(bool? deductible) => switch (deductible) {
      true => 'yes',
      false => 'no',
      null => '',
    };

String _yesNo(bool value) => value ? 'yes' : 'no';

String _householdDay(DateTime instant) {
  final utc = instant.toUtc();
  final local = utc.add(vancouverUtcOffset(utc));
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
