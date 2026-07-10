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
    ..sort((a, b) {
      final c = a.occurredAt.compareTo(b.occurredAt);
      return c != 0 ? c : a.purchaseId.compareTo(b.purchaseId);
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
      for (final p in purchases)
        [
          XlsxCell.text(_householdDay(p.occurredAt)),
          XlsxCell.text(p.month.toKey()),
          XlsxCell.text(names[p.userId] ?? p.userId),
          XlsxCell.text(_targetLabel(state, p.target, names)),
          XlsxCell.text(p.merchant),
          XlsxCell.number(Money(p.amountCents).format()),
          XlsxCell.text(_yesNo(p.shared)),
          XlsxCell.text(_taxLabel(p.taxDeductible)),
          XlsxCell.text(_yesNo(p.voided)),
          XlsxCell.text(p.note),
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
          .where((c) => c.categoryId == categoryId)
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
    ..sort((a, b) {
      // Adults first, then dependents, then pets; ties broken by name.
      final c = a.role.index.compareTo(b.role.index);
      return c != 0 ? c : a.name.compareTo(b.name);
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
      for (final m in members)
        [
          XlsxCell.text(m.name),
          XlsxCell.text(m.role.name),
          XlsxCell.text(_yesNo(m.active)),
          if (m.isAdult && incomeMonth != null)
            XlsxCell.number(Money(state.incomeFor(m.memberId, incomeMonth)).format())
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
    ..sort((a, b) => a.name.compareTo(b.name));
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
      for (final q in quests)
        [
          XlsxCell.text(q.name),
          XlsxCell.text(_mainCategoryName(state, q.mainCategoryId)),
          XlsxCell.text(_partyLabel(q.ownership, names)),
          XlsxCell.number(Money(q.targetCents).format()),
          XlsxCell.number(Money(q.balanceCents).format()),
          XlsxCell.number(Money(_remaining(q.targetCents, q.balanceCents)).format()),
          XlsxCell.number('${_percent(q.balanceCents, q.targetCents)}'),
          XlsxCell.text(_questStatus(q)),
        ],
    ],
  );
}

// ---------------------------------------------------------------------------
// Net worth (tracked accounts)
// ---------------------------------------------------------------------------

XlsxSheet _netWorthSheet(HouseholdState state) {
  final accounts = state.netWorth.accounts.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  final rows = <List<XlsxCell>>[
    for (final a in accounts)
      [
        XlsxCell.text(a.name),
        XlsxCell.text(a.kind.name),
        XlsxCell.number(Money(a.currentValueCents).format()),
        XlsxCell.number(Money(a.balanceCents).format()),
        XlsxCell.number(Money(a.accruedInterestCents).format()),
        // APR is basis points: divide by 100 the same way cents make dollars.
        a.aprBps != null ? XlsxCell.number(Money(a.aprBps!).format()) : XlsxCell.empty,
        XlsxCell.text(_yesNo(a.stale)),
        a.minPaymentCents != null
            ? XlsxCell.number(Money(a.minPaymentCents!).format())
            : XlsxCell.empty,
        XlsxCell.number(Money(a.signedCents).format()),
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
    ..sort((a, b) => a.name.compareTo(b.name));
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
      for (final e in expenses)
        [
          XlsxCell.text(e.name),
          XlsxCell.text(_partyLabel(e.ownership, names)),
          XlsxCell.text(e.kind.name),
          XlsxCell.text(e.cadence.name),
          XlsxCell.number(Money(e.amountCents).format()),
          XlsxCell.number('${e.dueDay}'),
          e.dueMonth != null ? XlsxCell.number('${e.dueMonth}') : XlsxCell.empty,
          XlsxCell.text(e.startMonth.toKey()),
          e.endMonth != null ? XlsxCell.text(e.endMonth!.toKey()) : XlsxCell.empty,
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
  for (final p in state.purchases.values) {
    keys.add(p.month.toKey());
  }
  final months = keys.map(Month.parse).toList()..sort();
  return months;
}

/// The month used to resolve "current" income: the latest month in scope, else
/// the latest income-default effective month, else null (income shown blank).
Month? _latestIncomeMonth(HouseholdState state, List<Month> monthsInScope) {
  Month? latest = monthsInScope.isNotEmpty ? monthsInScope.last : null;
  for (final defaults in state.incomeDefaultsByUser.values) {
    for (final d in defaults) {
      if (latest == null || d.effectiveFromMonth.isAfter(latest)) {
        latest = d.effectiveFromMonth;
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
  final r = targetCents - balanceCents;
  return r > 0 ? r : 0;
}

/// Integer percent complete with truncating division — no float involved.
int _percent(int balanceCents, int targetCents) =>
    targetCents > 0 ? (balanceCents * 100) ~/ targetCents : 0;

String _questStatus(QuestState q) {
  if (q.abandoned) return 'Abandoned';
  if (q.completed) return 'Completed';
  return 'Active';
}

String _taxLabel(bool? deductible) => switch (deductible) {
      true => 'yes',
      false => 'no',
      null => '',
    };

String _yesNo(bool value) => value ? 'yes' : 'no';

String _householdDay(DateTime instant) {
  final u = instant.toUtc();
  final local = u.add(vancouverUtcOffset(u));
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
