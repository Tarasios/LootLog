/// Tests the offline budget workbook builder: the six documented sheets, in
/// order, with money rendered as cents-derived decimals.
library;

import 'package:duobudget/data/export/budget_workbook.dart';
import 'package:duobudget/data/export/xlsx.dart';
import 'package:duobudget/domain/event.dart';
import 'package:duobudget/domain/reducer.dart';
import 'package:duobudget/domain/time.dart';
import 'package:duobudget/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

int _n = 0;
String _id() => 'e${(_n++).toString().padLeft(4, '0')}';
DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

const _names = {'u1': 'Alex', 'u2': 'Sam'};

/// Finds the first data row whose first cell text equals [first].
List<XlsxCell> _row(XlsxSheet sheet, String first) =>
    sheet.rows.firstWhere((r) => r.first.value == first);

void main() {
  final events = <Event>[
    MemberSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 1, 1),
      createdAt: _day(2026, 1, 1),
      memberId: 'u1',
      name: 'Alex',
      role: MemberRole.adult,
    ),
    MemberSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 1, 1),
      createdAt: _day(2026, 1, 1),
      memberId: 'u2',
      name: 'Sam',
      role: MemberRole.adult,
    ),
    MemberSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 1, 1),
      createdAt: _day(2026, 1, 1),
      memberId: 'pet1',
      name: 'Rex',
      role: MemberRole.pet,
    ),
    DefaultIncomeSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 1, 1),
      createdAt: _day(2026, 1, 1),
      forUserId: 'u1',
      amountCents: 500000,
      effectiveFromMonth: const Month(2026, 1),
    ),
    BudgetSliceSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 1, 1),
      createdAt: _day(2026, 1, 1),
      sliceId: 'groceries',
      name: 'Groceries',
      ownership: const PersonalSlice('u1'),
      limitCents: 40000,
      poolTithePct: 0,
      defaultLeftoverPolicy: const Discretionary(),
      taxDeductibleByDefault: false,
      mainCategoryId: 'food',
    ),
    BudgetSliceSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 1, 1),
      createdAt: _day(2026, 1, 1),
      sliceId: 'rent',
      name: 'Rent',
      ownership: const GroupSlice(),
      limitCents: 120000,
      poolTithePct: 0,
      defaultLeftoverPolicy: const CarryInSlice(),
      taxDeductibleByDefault: false,
      mainCategoryId: 'housing',
    ),
    PurchaseAdded(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 3, 4),
      createdAt: _day(2026, 3, 4),
      purchaseId: 'p1',
      target: const SliceCharge('groceries'),
      amountCents: 12345,
      merchant: 'Corner Store',
      note: 'weekly shop',
    ),
    QuestSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 1, 5),
      createdAt: _day(2026, 1, 5),
      questId: 'canoe',
      name: 'Canoe',
      targetCents: 130000,
      ownership: const SharedParty(),
      mainCategoryId: 'savings',
    ),
    RecurringExpenseSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 1, 1),
      createdAt: _day(2026, 1, 1),
      expenseId: 'wow',
      name: 'WoW subscription',
      ownership: const PersonalParty('u1'),
      kind: RecurringKind.fixed,
      cadence: RecurringCadence.annual,
      amountCents: 15600,
      startMonth: const Month(2026, 1),
      dueDay: 10,
      dueMonth: 2,
    ),
    TrackedAccountSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 3, 1),
      createdAt: _day(2026, 3, 1),
      accountId: 'sav',
      name: 'Rainy Day',
      kind: AccountKind.savings,
      aprBps: 500,
    ),
    AccountBalanceRecorded(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 3, 1),
      createdAt: _day(2026, 3, 1),
      accountId: 'sav',
      accountName: 'Rainy Day',
      kind: AccountKind.savings,
      balanceCents: 250000,
    ),
  ];

  final state = reduce(events, asOf: DateTime.utc(2026, 3, 5, 18));
  final workbook = buildBudgetWorkbook(state, userNames: _names);

  test('the workbook has the six documented sheets, in order', () {
    expect(
      workbook.sheets.map((s) => s.name).toList(),
      const [
        'Transactions',
        'Monthly summary',
        'Members & income',
        'Savings goals',
        'Net worth',
        'Recurring expenses',
      ],
    );
  });

  test('Transactions renders the purchase with a cents-derived decimal', () {
    final sheet = workbook.sheet('Transactions')!;
    final row = _row(sheet, '2026-03-04');
    expect(row[2].value, 'Alex'); // member
    expect(row[3].value, 'Groceries'); // charged to
    expect(row[4].value, 'Corner Store'); // merchant
    expect(row[5].value, '123.45'); // amount
    expect(row[5].isNumber, isTrue);
    expect(row[6].value, 'no'); // shared
    expect(row[9].value, 'weekly shop'); // note
  });

  test('Monthly summary carries budgeted/spent/leftover per category', () {
    final sheet = workbook.sheet('Monthly summary')!;
    final groceries = sheet.rows.firstWhere(
      (r) => r[0].value == '2026-03' && r[1].value == 'Groceries',
    );
    expect(groceries[2].value, 'Food'); // main category
    expect(groceries[3].value, 'Alex'); // owner
    expect(groceries[4].value, '400.00'); // budgeted
    expect(groceries[5].value, '123.45'); // spent
    expect(groceries[6].value, '276.55'); // leftover
  });

  test('Members & income lists members and adult income', () {
    final sheet = workbook.sheet('Members & income')!;
    final alex = _row(sheet, 'Alex');
    expect(alex[1].value, 'adult');
    expect(alex[2].value, 'yes');
    expect(alex[3].value, '5000.00'); // resolved monthly income
    final rex = _row(sheet, 'Rex');
    expect(rex[1].value, 'pet');
    expect(rex[3].isBlank, isTrue); // pets have no income
  });

  test('Savings goals lists the quest with target and percent', () {
    final sheet = workbook.sheet('Savings goals')!;
    final canoe = _row(sheet, 'Canoe');
    expect(canoe[1].value, 'Savings');
    expect(canoe[2].value, 'Shared');
    expect(canoe[3].value, '1300.00'); // target
    expect(canoe[4].value, '0.00'); // balance
    expect(canoe[5].value, '1300.00'); // remaining
    expect(canoe[6].value, '0'); // percent complete
    expect(canoe[7].value, 'Active');
  });

  test('Net worth lists the account, APR as a decimal, and a total row', () {
    final sheet = workbook.sheet('Net worth')!;
    final rainy = _row(sheet, 'Rainy Day');
    expect(rainy[1].value, 'savings');
    expect(rainy[3].value, '2500.00'); // recorded balance
    expect(rainy[5].value, '5.00'); // APR (500 bps)
    final total = _row(sheet, 'Total (net worth)');
    expect(total.last.value, '2500.00');
  });

  test('Recurring expenses lists the annual bill', () {
    final sheet = workbook.sheet('Recurring expenses')!;
    final wow = _row(sheet, 'WoW subscription');
    expect(wow[1].value, 'Alex'); // owner
    expect(wow[2].value, 'fixed');
    expect(wow[3].value, 'annual');
    expect(wow[4].value, '156.00'); // amount
    expect(wow[5].value, '10'); // due day
    expect(wow[6].value, '2'); // due month
    expect(wow[7].value, '2026-01'); // start month
  });

  test('the whole workbook encodes to a valid xlsx', () {
    final bytes = encodeXlsx(workbook);
    expect(bytes.length, greaterThan(0));
  });
}
