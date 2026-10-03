import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';

const u1 = 'u1';
const u2 = 'u2';
var _n = 0;
String _id() => 'sv${(_n++).toString().padLeft(5, '0')}';

DateTime day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

/// An instant safely past [m]'s grace window (so defaults would apply).
DateTime graceExpired(Month m) =>
    m.endInstantUtc().add(const Duration(days: 8));

/// An instant just after [m] closed but inside its ritual window.
DateTime justClosed(Month m) => m.endInstantUtc().add(const Duration(days: 1));

const jul = Month(2026, 7);
const aug = Month(2026, 8);
const sep = Month(2026, 9);

SettingChanged rules(Month from, int generalPct, {DateTime? at}) =>
    SettingChanged(
      eventId: _id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: at ?? day(2026, 6, 1),
      createdAt: at ?? day(2026, 6, 1),
      key: 'savingsRules',
      value: {'fromMonth': from.toKey(), 'generalTithePct': generalPct},
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

BudgetSliceSet slice(
  String id,
  int limit, {
  String owner = u1,
  int carryPct = 0,
  String? mainCat,
  LeftoverDestination policy = const CarryInSlice(),
  bool group = false,
  DateTime? at,
}) => BudgetSliceSet(
  eventId: _id(),
  deviceId: 'd',
  userId: u1,
  occurredAt: at ?? day(2026, 7, 1),
  createdAt: at ?? day(2026, 7, 1),
  sliceId: id,
  name: id,
  ownership: group ? const GroupSlice() : PersonalSlice(owner),
  mainCategoryId: mainCat,
  limitCents: limit,
  poolTithePct: carryPct,
  defaultLeftoverPolicy: policy,
  taxDeductibleByDefault: false,
);

PurchaseAdded buy(
  String id,
  ChargeTarget target,
  int amount,
  DateTime at, {
  String by = u1,
}) => PurchaseAdded(
  eventId: _id(),
  deviceId: 'd',
  userId: by,
  occurredAt: at,
  createdAt: at,
  purchaseId: id,
  target: target,
  amountCents: amount,
  shared: false,
);

LeftoverAllocated allocate(
  String sliceId,
  Month month,
  List<Allocation> lines, {
  String forUser = u1,
}) => LeftoverAllocated(
  eventId: _id(),
  deviceId: 'd',
  userId: forUser,
  occurredAt: month.endInstantUtc(),
  createdAt: month.endInstantUtc(),
  forUserId: forUser,
  month: month,
  sliceId: sliceId,
  allocations: lines,
);

Allocation line(
  LeftoverDestination d,
  int cents, [
  AllocationSource s = AllocationSource.allowance,
]) => Allocation(destination: d, amountCents: cents, source: s);

void main() {
  group('adoption', () {
    test('no savingsRules setting means no rules', () {
      expect(reduce([slice('c', 5000)]).savingsRules, isNull);
    });

    test('the earliest fromMonth adopts; rates apply from their month on', () {
      final s = reduce([rules(jul, 20), rules(sep, 25)]).savingsRules!;
      expect(s.fromMonth, jul);
      expect(s.appliesTo(const Month(2026, 6)), isFalse);
      expect(s.generalRateFor(aug), 20);
      expect(s.generalRateFor(sep), 25);
    });

    test('a malformed setting value is ignored', () {
      final bad = SettingChanged(
        eventId: _id(),
        deviceId: 'd',
        userId: u1,
        occurredAt: day(2026, 6, 1),
        createdAt: day(2026, 6, 1),
        key: 'savingsRules',
        value: 'nonsense',
      );
      expect(reduce([bad]).savingsRules, isNull);
    });
  });
}
