import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/report.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

const u1 = 'u1';
const u2 = 'u2';

int _n = 0;
String _id() => 'e${(_n++).toString().padLeft(4, '0')}';
DateTime day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

BudgetSliceSet cat({
  required String id,
  required SliceOwnership ownership,
  required int limit,
  String? mainCategoryId,
}) =>
    BudgetSliceSet(
      eventId: _id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: day(2026, 1, 1),
      createdAt: day(2026, 1, 1),
      sliceId: id,
      name: id,
      ownership: ownership,
      mainCategoryId: mainCategoryId,
      limitCents: limit,
      poolTithePct: 0,
      defaultLeftoverPolicy: const Discretionary(),
      taxDeductibleByDefault: false,
    );

PurchaseAdded buy({
  required String id,
  required String catId,
  required int amount,
  String by = u1,
}) =>
    PurchaseAdded(
      eventId: _id(),
      deviceId: 'd',
      userId: by,
      occurredAt: day(2026, 1, 10),
      createdAt: day(2026, 1, 10),
      purchaseId: id,
      target: SliceCharge(catId),
      amountCents: amount,
    );

MemberSet adult(String id) => MemberSet(
      eventId: _id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: day(2026, 1, 1),
      createdAt: day(2026, 1, 1),
      memberId: id,
      name: id,
      role: MemberRole.adult,
    );

const jan = Month(2026, 1);
final _asOf = day(2026, 1, 20);

void main() {
  group('spend by main category', () {
    test('sums categories sharing a main category and uses its colour', () {
      final s = reduce([
        adult(u1),
        cat(id: 'groceries', ownership: const PersonalSlice(u1),
            limit: 40000, mainCategoryId: 'food'),
        cat(id: 'dining', ownership: const PersonalSlice(u1),
            limit: 20000, mainCategoryId: 'food'),
        cat(id: 'bus', ownership: const PersonalSlice(u1),
            limit: 10000, mainCategoryId: 'transport'),
        buy(id: 'p1', catId: 'groceries', amount: 15000),
        buy(id: 'p2', catId: 'dining', amount: 5000),
        buy(id: 'p3', catId: 'bus', amount: 3000),
      ], asOf: _asOf);

      final report = buildMonthReport(s, jan);
      // Food (0xF28E2B, sort 1) then Transport (sort 2).
      expect(report.byMainCategory.map((m) => m.id), ['food', 'transport']);
      final food = report.byMainCategory.first;
      expect(food.spentCents, 20000);
      expect(food.colorArgb, 0xFFF28E2B);
      expect(report.byMainCategory[1].spentCents, 3000);
    });

    test('a main category with no spend is omitted from the pie', () {
      final s = reduce([
        adult(u1),
        cat(id: 'groceries', ownership: const PersonalSlice(u1),
            limit: 40000, mainCategoryId: 'food'),
        cat(id: 'gym', ownership: const PersonalSlice(u1),
            limit: 10000, mainCategoryId: 'health'),
        buy(id: 'p1', catId: 'groceries', amount: 15000),
      ], asOf: _asOf);

      final report = buildMonthReport(s, jan);
      expect(report.byMainCategory.map((m) => m.id), ['food']);
    });

    test('unassigned spend falls into the Uncategorized bucket', () {
      final s = reduce([
        adult(u1),
        cat(id: 'misc', ownership: const PersonalSlice(u1), limit: 10000),
        buy(id: 'p1', catId: 'misc', amount: 2500),
      ], asOf: _asOf);

      final report = buildMonthReport(s, jan);
      expect(report.byMainCategory.single.mainCategory, uncategorizedMainCategory);
      expect(report.byMainCategory.single.spentCents, 2500);
    });
  });

  group('budgeted / spent / leftover table', () {
    test('household totals cover every category, personal and group', () {
      final s = reduce([
        adult(u1),
        adult(u2),
        cat(id: 'groceries', ownership: const PersonalSlice(u1),
            limit: 40000, mainCategoryId: 'food'),
        cat(id: 'utilities', ownership: const GroupSlice(),
            limit: 30000, mainCategoryId: 'housing'),
        buy(id: 'p1', catId: 'groceries', amount: 15000),
        buy(id: 'p2', catId: 'utilities', amount: 10000),
      ], asOf: _asOf);

      final report = buildMonthReport(s, jan);
      expect(report.categories.map((r) => r.categoryId),
          ['groceries', 'utilities']);
      expect(report.totalBudgetedCents, 70000);
      expect(report.totalSpentCents, 25000);
      expect(report.totalLeftoverCents, 45000);
      final utilities =
          report.categories.firstWhere((r) => r.categoryId == 'utilities');
      expect(utilities.isGroup, isTrue);
    });

    test('per-adult scope excludes group and the other adult', () {
      final s = reduce([
        adult(u1),
        adult(u2),
        cat(id: 'u1cat', ownership: const PersonalSlice(u1),
            limit: 40000, mainCategoryId: 'food'),
        cat(id: 'u2cat', ownership: const PersonalSlice(u2),
            limit: 20000, mainCategoryId: 'food'),
        cat(id: 'grp', ownership: const GroupSlice(), limit: 30000),
        buy(id: 'p1', catId: 'u1cat', amount: 15000),
        buy(id: 'p2', catId: 'u2cat', amount: 8000, by: u2),
      ], asOf: _asOf);

      final report = buildMonthReport(s, jan, userId: u1);
      expect(report.isHousehold, isFalse);
      expect(report.categories.map((r) => r.categoryId), ['u1cat']);
      expect(report.totalSpentCents, 15000);
      expect(report.byMainCategory.single.spentCents, 15000);
    });

    test('overspend surfaces on the row', () {
      final s = reduce([
        adult(u1),
        cat(id: 'groceries', ownership: const PersonalSlice(u1),
            limit: 10000, mainCategoryId: 'food'),
        buy(id: 'p1', catId: 'groceries', amount: 12000),
      ], asOf: _asOf);

      final row = buildMonthReport(s, jan).categories.single;
      expect(row.overspent, isTrue);
      expect(row.leftoverCents, 0);
      expect(row.spentCents, 12000);
    });
  });
}
