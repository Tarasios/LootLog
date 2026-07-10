import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

const u1 = 'u1';

class Seq {
  int _n = 0;
  String id() => 'ob${(_n++).toString().padLeft(4, '0')}';
}

final _seq = Seq();

DateTime day(int year, int month, int d) => DateTime.utc(year, month, d, 18);

DateTime graceExpired(Month m) =>
    m.endInstantUtc().add(const Duration(days: 8));

BudgetSliceSet slice({
  required String id,
  required SliceOwnership ownership,
  required int limit,
  int tithePct = 0,
  LeftoverDestination policy = const Discretionary(),
  String? mainCategoryId,
}) =>
    BudgetSliceSet(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: day(2026, 1, 1),
      createdAt: day(2026, 1, 1),
      sliceId: id,
      name: id,
      ownership: ownership,
      mainCategoryId: mainCategoryId,
      limitCents: limit,
      poolTithePct: tithePct,
      defaultLeftoverPolicy: policy,
      taxDeductibleByDefault: false,
    );

PurchaseAdded buy({
  required String id,
  required ChargeTarget target,
  required int amount,
  required DateTime at,
}) =>
    PurchaseAdded(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: at,
      createdAt: at,
      purchaseId: id,
      target: target,
      amountCents: amount,
      shared: false,
    );

LeftoverAllocated allocate({
  required String sliceId,
  required Month month,
  required List<Allocation> allocations,
  required DateTime at,
}) =>
    LeftoverAllocated(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: at,
      createdAt: at,
      forUserId: u1,
      month: month,
      sliceId: sliceId,
      allocations: allocations,
    );

GiftReceived gift({required int amount, required DateTime at}) => GiftReceived(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: at,
      createdAt: at,
      forUserId: u1,
      amountCents: amount,
    );

void main() {
  const jan = Month(2026, 1);
  const feb = Month(2026, 2);

  group('overbudget settlement', () {
    test('overspend in the still-open month creates no debt yet', () {
      final events = [
        slice(id: 'a', ownership: const PersonalSlice(u1), limit: 10000),
        buy(id: 'p', target: const SliceCharge('a'), amount: 12000,
            at: day(2026, 1, 5)),
      ];
      final s = reduce(events, asOf: day(2026, 1, 20));
      expect(s.sliceMonth('a', jan)!.overspendCents, 2000);
      expect(s.overbudgets, isEmpty);
      expect(s.vaultOf(u1), 0);
    });

    test('at close the overflow is seized from the vault first', () {
      // Jan: spend 1000 of 10000, tithe 10% -> default discretionary puts
      // 8100 in the vault (900 tithe). Feb: overspend by 3000; at Feb close
      // the 3000 is seized from the vault. No debt.
      final events = [
        slice(
            id: 'a',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            tithePct: 10),
        buy(id: 'p1', target: const SliceCharge('a'), amount: 1000,
            at: day(2026, 1, 5)),
        buy(id: 'p2', target: const SliceCharge('a'), amount: 13000,
            at: day(2026, 2, 5)),
      ];
      final s = reduce(events, asOf: day(2026, 3, 2));
      expect(s.vaultOf(u1), 8100 - 3000);
      expect(s.overbudgets, isEmpty);
      expect(s.warChest.balanceCents, 900);
    });

    test('a same-month gift is available for seizure at close', () {
      final events = [
        slice(id: 'a', ownership: const PersonalSlice(u1), limit: 10000),
        gift(amount: 10000, at: day(2026, 1, 5)),
        buy(id: 'p', target: const SliceCharge('a'), amount: 14000,
            at: day(2026, 1, 10)),
      ];
      final s = reduce(events, asOf: day(2026, 2, 2));
      expect(s.vaultOf(u1), 6000);
      expect(s.overbudgets, isEmpty);
    });

    test('an insufficient vault leaves an OVERBUDGET debt', () {
      final events = [
        slice(id: 'a', ownership: const PersonalSlice(u1), limit: 10000),
        buy(id: 'p', target: const SliceCharge('a'), amount: 14000,
            at: day(2026, 1, 5)),
      ];
      final s = reduce(events, asOf: day(2026, 2, 2));
      final debt = s.overbudgets['a']!;
      expect(debt.outstandingCents, 4000);
      expect(debt.ownerUserId, u1);
      expect(debt.accruedCents, 4000);
      expect(s.vaultOf(u1), 0);
    });

    test('a gift arriving after the close does not retroactively settle', () {
      final events = [
        slice(id: 'a', ownership: const PersonalSlice(u1), limit: 10000),
        buy(id: 'p', target: const SliceCharge('a'), amount: 14000,
            at: day(2026, 1, 5)),
        gift(amount: 10000, at: day(2026, 2, 3)),
      ];
      final s = reduce(events, asOf: day(2026, 2, 4));
      expect(s.overbudgets['a']!.outstandingCents, 4000);
      expect(s.vaultOf(u1), 10000);
    });

    test('an attack from a matching main category is untithed', () {
      final events = [
        slice(
            id: 'a',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            mainCategoryId: 'food'),
        slice(
            id: 'b',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            tithePct: 50,
            mainCategoryId: 'food'),
        buy(id: 'p', target: const SliceCharge('a'), amount: 14000,
            at: day(2026, 1, 5)),
        buy(id: 'q', target: const SliceCharge('b'), amount: 4000,
            at: day(2026, 1, 6)),
        allocate(
          sliceId: 'b',
          month: jan,
          allocations: const [
            Allocation(
                destination: OverbudgetPayment('a'), amountCents: 4000),
            Allocation(destination: Discretionary(), amountCents: 2000),
          ],
          at: day(2026, 2, 2),
        ),
      ];
      final s = reduce(events, asOf: day(2026, 2, 3));
      expect(s.overbudgets['a']!.outstandingCents, 0);
      expect(s.overbudgets['a']!.paidCents, 4000);
      // Discretionary 2000 at 50% tithe: 1000 chest, 1000 vault. The attack
      // itself is untithed (matching main category).
      expect(s.warChest.balanceCents, 1000);
      expect(s.vaultOf(u1), 1000);
    });

    test('an attack from a non-matching category pays the pool tithe', () {
      final events = [
        slice(
            id: 'a',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            mainCategoryId: 'entertainment'),
        slice(
            id: 'b',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            tithePct: 25,
            mainCategoryId: 'food'),
        buy(id: 'p', target: const SliceCharge('a'), amount: 14000,
            at: day(2026, 1, 5)),
        buy(id: 'q', target: const SliceCharge('b'), amount: 6000,
            at: day(2026, 1, 6)),
        allocate(
          sliceId: 'b',
          month: jan,
          allocations: const [
            Allocation(
                destination: OverbudgetPayment('a'), amountCents: 4000),
          ],
          at: day(2026, 2, 2),
        ),
      ];
      final s = reduce(events, asOf: day(2026, 2, 3));
      // 4000 at 25%: 1000 to the chest, 3000 damage.
      expect(s.warChest.balanceCents, 1000);
      expect(s.overbudgets['a']!.outstandingCents, 1000);
    });

    test('attack beyond the outstanding debt overflows to the vault', () {
      final events = [
        slice(
            id: 'a',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            mainCategoryId: 'food'),
        slice(
            id: 'b',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            mainCategoryId: 'food'),
        buy(id: 'p', target: const SliceCharge('a'), amount: 11000,
            at: day(2026, 1, 5)),
        allocate(
          sliceId: 'b',
          month: jan,
          allocations: const [
            Allocation(
                destination: OverbudgetPayment('a'), amountCents: 4000),
          ],
          at: day(2026, 2, 2),
        ),
      ];
      final s = reduce(events, asOf: day(2026, 2, 3));
      expect(s.overbudgets['a']!.outstandingCents, 0);
      expect(s.vaultOf(u1), 3000);
    });

    test('an unpaid debt locks the category and its funding pays at close',
        () {
      final events = [
        slice(id: 'a', ownership: const PersonalSlice(u1), limit: 10000),
        buy(id: 'p', target: const SliceCharge('a'), amount: 14000,
            at: day(2026, 1, 5)),
      ];
      // As of March: Feb is closed, so Feb's funding (4000 of it) paid the
      // debt off; Feb's effective limit shrank accordingly.
      final s = reduce(events, asOf: day(2026, 3, 10));
      final febRow = s.sliceMonth('a', feb)!;
      expect(febRow.lockedCents, 4000);
      expect(febRow.effectiveLimitCents, 6000);
      expect(s.overbudgets['a']!.outstandingCents, 0);
      final marRow = s.sliceMonth('a', const Month(2026, 3))!;
      expect(marRow.effectiveLimitCents, 10000);
      expect(marRow.lockedCents, 0);
    });

    test('a debt bigger than the funding grinds down across months', () {
      final events = [
        slice(id: 'a', ownership: const PersonalSlice(u1), limit: 10000),
        buy(id: 'p', target: const SliceCharge('a'), amount: 35000,
            at: day(2026, 1, 5)),
      ];
      final s = reduce(events, asOf: day(2026, 4, 10));
      // Debt 25000 at Jan close. Feb eats 10000, Mar eats 10000; April is
      // past its ritual window (Apr 8), so its funding pays the last 5000
      // immediately and the monster leaves.
      expect(s.sliceMonth('a', feb)!.effectiveLimitCents, 0);
      expect(s.sliceMonth('a', const Month(2026, 3))!.effectiveLimitCents, 0);
      final apr = s.sliceMonth('a', const Month(2026, 4))!;
      expect(apr.lockedCents, 5000);
      expect(apr.effectiveLimitCents, 5000);
      expect(s.overbudgets['a']!.outstandingCents, 0);
    });

    test('the debt stands at full HP through the ritual window, then the '
        'next month\'s funding fells it on its own', () {
      final events = [
        slice(id: 'a', ownership: const PersonalSlice(u1), limit: 10000),
        buy(id: 'p', target: const SliceCharge('a'), amount: 14000,
            at: day(2026, 1, 5)),
      ];
      // Feb 5: inside Feb's ritual window (grace 7 days) — the monster is
      // attackable and February's budget is still whole.
      final during = reduce(events, asOf: day(2026, 2, 5));
      expect(during.overbudgets['a']!.outstandingCents, 4000);
      final febDuring = during.sliceMonth('a', feb)!;
      expect(febDuring.lockedCents, 0);
      expect(febDuring.effectiveLimitCents, 10000);
      // Feb 9: the window has passed with no attack; the budget immediately
      // loses 4000 to the OVERBUDGET and it leaves.
      final after = reduce(events, asOf: day(2026, 2, 9));
      expect(after.overbudgets['a']!.outstandingCents, 0);
      final febAfter = after.sliceMonth('a', feb)!;
      expect(febAfter.lockedCents, 4000);
      expect(febAfter.effectiveLimitCents, 6000);
    });

    test('the canonical example: \$40 debt, \$50 leftover at 10% tithe', () {
      // Entertainment OVERBUDGET of $40; the clothes budget has $50 left at a
      // 10% tithe. The whole $50 is tithed to $45, $40 pays the debt, and the
      // remaining $5 goes to discretionary. The OVERBUDGET takes no more
      // post-tithe funds than it needs.
      final events = [
        slice(
            id: 'games',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            mainCategoryId: 'entertainment'),
        slice(
            id: 'clothes',
            ownership: const PersonalSlice(u1),
            limit: 5000,
            tithePct: 10,
            mainCategoryId: 'misc'),
        buy(id: 'p', target: const SliceCharge('games'), amount: 14000,
            at: day(2026, 1, 5)),
        allocate(
          sliceId: 'clothes',
          month: jan,
          allocations: const [
            Allocation(
                destination: OverbudgetPayment('games'), amountCents: 5000),
          ],
          at: day(2026, 2, 2),
        ),
      ];
      final s = reduce(events, asOf: day(2026, 2, 3));
      expect(s.warChest.balanceCents, 500);
      expect(s.overbudgets['games']!.outstandingCents, 0);
      expect(s.vaultOf(u1), 500);
    });

    test('past grace the default allocation attacks the debt first', () {
      final events = [
        slice(
            id: 'a',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            mainCategoryId: 'food'),
        slice(
            id: 'b',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            tithePct: 10,
            mainCategoryId: 'food'),
        buy(id: 'p', target: const SliceCharge('a'), amount: 14000,
            at: day(2026, 1, 5)),
        buy(id: 'q', target: const SliceCharge('b'), amount: 4000,
            at: day(2026, 1, 6)),
      ];
      final s = reduce(events, asOf: graceExpired(jan));
      // b's leftover 6000: 4000 attacks the debt untithed (matching), the
      // remaining 2000 follows the configured default (discretionary, 10%).
      expect(s.overbudgets['a']!.outstandingCents, 0);
      expect(s.warChest.balanceCents, 200);
      expect(s.vaultOf(u1), 1800);
    });

    test('a group category overflow draws from the war chest at close', () {
      final events = [
        slice(id: 'g', ownership: const GroupSlice(), limit: 10000),
        buy(id: 'p', target: const SliceCharge('g'), amount: 15000,
            at: day(2026, 1, 5)),
      ];
      final s = reduce(events, asOf: day(2026, 2, 2));
      expect(s.warChest.balanceCents, -5000);
      expect(s.overbudgets, isEmpty);
    });

    test('reduction stays order-independent with debts in play', () {
      final events = [
        slice(
            id: 'a',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            mainCategoryId: 'food'),
        slice(
            id: 'b',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            tithePct: 20,
            mainCategoryId: 'misc'),
        gift(amount: 1500, at: day(2026, 1, 3)),
        buy(id: 'p', target: const SliceCharge('a'), amount: 14000,
            at: day(2026, 1, 5)),
        buy(id: 'q', target: const SliceCharge('b'), amount: 2000,
            at: day(2026, 1, 6)),
        allocate(
          sliceId: 'b',
          month: jan,
          allocations: const [
            Allocation(
                destination: OverbudgetPayment('a'), amountCents: 5000),
            Allocation(destination: CarryInSlice(), amountCents: 3000),
          ],
          at: day(2026, 2, 2),
        ),
      ];
      final asOf = day(2026, 3, 10);
      final sorted = reduce(events, asOf: asOf).debugSnapshot();
      final reversed =
          reduce(events.reversed.toList(), asOf: asOf).debugSnapshot();
      expect(reversed, sorted);
    });
  });
}
