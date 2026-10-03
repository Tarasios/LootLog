import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/entry/shortfall.dart';

const me = 'u1';
var _n = 0;
String _id() => 'sf${(_n++).toString().padLeft(4, '0')}';
DateTime _day(int m, int d) => DateTime.utc(2026, m, d, 18);

SettingChanged _rules() => SettingChanged(
  eventId: _id(),
  deviceId: 'd',
  userId: me,
  occurredAt: _day(1, 1),
  createdAt: _day(1, 1),
  key: 'savingsRules',
  value: {'fromMonth': '2026-07', 'generalTithePct': 20},
);

BudgetSliceSet _slice(
  String id,
  int limit, {
  String? mainCat,
  int carry = 10,
}) => BudgetSliceSet(
  eventId: _id(),
  deviceId: 'd',
  userId: me,
  occurredAt: _day(7, 1),
  createdAt: _day(7, 1),
  sliceId: id,
  name: id == 'clothes' ? 'Clothing' : id,
  ownership: const PersonalSlice(me),
  mainCategoryId: mainCat,
  limitCents: limit,
  poolTithePct: carry,
  defaultLeftoverPolicy: const CarryInSlice(),
  taxDeductibleByDefault: false,
);

LeftoverAllocated _carryJuly(String sliceId, int cents) => LeftoverAllocated(
  eventId: _id(),
  deviceId: 'd',
  userId: me,
  occurredAt: _day(8, 1),
  createdAt: _day(8, 1),
  forUserId: me,
  month: const Month(2026, 7),
  sliceId: sliceId,
  allocations: [
    Allocation(destination: const CarryInSlice(), amountCents: cents),
  ],
);

GiftReceived _gift(int cents) => GiftReceived(
  eventId: _id(),
  deviceId: 'd',
  userId: me,
  occurredAt: _day(7, 2),
  createdAt: _day(7, 2),
  forUserId: me,
  amountCents: cents,
);

void main() {
  final at = _day(8, 10);

  test('nothing is short within allowance plus savings', () {
    final s = reduce([
      _rules(),
      _slice('clothes', 25000),
      _carryJuly('clothes', 5000),
    ], asOf: at);
    expect(
      shortfallFor(
        s,
        meUserId: me,
        target: const SliceCharge('clothes'),
        amountCents: 29000,
        at: at,
      ),
      isNull,
    );
  });

  test('a category purchase beyond allowance and savings is short', () {
    // In July itself, so no earlier month's default carry fills savings.
    final at = _day(7, 10);
    final s = reduce([
      _rules(),
      _gift(10000),
      _slice('clothes', 25000),
    ], asOf: at);
    final o = shortfallFor(
      s,
      meUserId: me,
      target: const SliceCharge('clothes'),
      amountCents: 30000,
      at: at,
    )!;
    expect(o.shortCents, 5000);
    expect(o.generalAvailableCents, 10000);
    expect(o.canBorrow, isTrue);
    expect(o.sliceId, 'clothes');
    expect(o.savingsSources, isEmpty);
  });

  test('earlier spending this month is taken into account', () {
    final at = _day(7, 10);
    final s = reduce([
      _rules(),
      _slice('clothes', 25000),
      PurchaseAdded(
        eventId: _id(),
        deviceId: 'd',
        userId: me,
        occurredAt: _day(7, 3),
        createdAt: _day(7, 3),
        purchaseId: 'shoes',
        target: const SliceCharge('clothes'),
        amountCents: 20000,
      ),
    ], asOf: at);
    final o = shortfallFor(
      s,
      meUserId: me,
      target: const SliceCharge('clothes'),
      amountCents: 8000,
      at: at,
    )!;
    expect(o.shortCents, 3000);
  });

  test('a quest goal purchase lists category savings with the tax preview', () {
    final s = reduce([
      _rules(),
      _slice('clothes', 25000, mainCat: 'misc'),
      _carryJuly('clothes', 5000), // savings 4500, paid 500
      QuestSet(
        eventId: _id(),
        deviceId: 'd',
        userId: me,
        occurredAt: _day(7, 1),
        createdAt: _day(7, 1),
        questId: 'canoe',
        name: 'Canoe',
        targetCents: 13000,
        ownership: const PersonalParty(me),
        mainCategoryId: 'outdoors',
      ),
    ], asOf: at);
    final o = shortfallFor(
      s,
      meUserId: me,
      target: const QuestCharge('canoe'),
      amountCents: 2000,
      at: at,
    )!;
    expect(o.shortCents, 2000);
    expect(o.canBorrow, isFalse);
    final src = o.savingsSources.single;
    expect(src.sliceId, 'clothes');
    expect(src.name, 'Clothing');
    // Delivering 2000 at 20% from money that already paid 10%.
    expect(src.deliveredCents, greaterThanOrEqualTo(2000));
    expect(src.moveCents - src.deliveredCents, src.taxCents);
  });

  test('nothing is offered before the savings rules apply', () {
    final s = reduce([_gift(10000), _slice('clothes', 25000)], asOf: at);
    expect(
      shortfallFor(
        s,
        meUserId: me,
        target: const SliceCharge('clothes'),
        amountCents: 30000,
        at: at,
      ),
      isNull,
    );
  });

  test('group and vault purchases are never short', () {
    final s = reduce([_rules(), _gift(100)], asOf: at);
    expect(
      shortfallFor(
        s,
        meUserId: me,
        target: const VaultCharge(),
        amountCents: 99999,
        at: at,
      ),
      isNull,
    );
  });
}
