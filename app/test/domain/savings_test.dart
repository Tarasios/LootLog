import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/pools.dart';
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

  group('category savings', () {
    test('the canonical July→September example', () {
      final events = [
        rules(jul, 20),
        slice('clothes', 5000, carryPct: 10),
        // July: nothing spent; carry all $50 at 10%.
        allocate('clothes', jul, [line(const CarryInSlice(), 5000)]),
        // August: nothing spent; savings stay, fresh $50 to general at 20%.
        allocate('clothes', aug, [line(const Discretionary(), 5000)]),
      ];
      final s = reduce(events, asOf: day(2026, 9, 15));
      expect(s.sliceMonth('clothes', aug)!.effectiveLimitCents, 5000);
      expect(s.sliceMonth('clothes', aug)!.savingsCents, 4500);
      expect(s.categorySavings['clothes'], const TaxedBalance(4500, 500));
      expect(s.sliceMonth('clothes', sep)!.effectiveLimitCents, 5000);
      expect(s.vaultOf(u1), 4000);
      expect(s.warChest.balanceCents, 500 + 1000);
    });

    test('spending uses the allowance first, then savings', () {
      final events = [
        rules(jul, 20),
        slice('clothes', 5000, carryPct: 10),
        allocate('clothes', jul, [line(const CarryInSlice(), 5000)]),
        buy('jacket', const SliceCharge('clothes'), 7000, day(2026, 8, 10)),
      ];
      final sm = reduce(
        events,
        asOf: day(2026, 8, 20),
      ).sliceMonth('clothes', aug)!;
      expect(sm.fromSavingsCents, 2000);
      expect(sm.savingsCents, 2500);
      expect(sm.overspendCents, 0);
      expect(sm.leftoverCents, 0);
    });

    test(
      'spending beyond allowance and savings is overspend (seized at close)',
      () {
        final events = [
          rules(jul, 20),
          slice('clothes', 5000, carryPct: 10),
          buy('jacket', const SliceCharge('clothes'), 6000, day(2026, 7, 10)),
        ];
        final s = reduce(events, asOf: justClosed(jul));
        expect(s.sliceMonth('clothes', jul)!.overspendCents, 1000);
        expect(s.overbudgets['clothes']!.outstandingCents, 1000);
      },
    );

    test('moving already-taxed savings out pays only the difference', () {
      final events = [
        rules(jul, 20),
        slice('clothes', 5000, carryPct: 10),
        allocate('clothes', jul, [line(const CarryInSlice(), 5000)]),
        allocate('clothes', aug, [
          line(const CarryInSlice(), 5000),
          line(const Discretionary(), 4500, AllocationSource.savings),
        ]),
      ];
      final s = reduce(events, asOf: day(2026, 9, 15));
      expect(s.vaultOf(u1), 4000); // $45 paid $5; top-up $5 to reach 20%.
      expect(s.categorySavings['clothes'], const TaxedBalance(4500, 500));
    });

    test(
      'a matching quest attack is untaxed; a non-matching one pays general',
      () {
        QuestSet quest(String id, String? cat) => QuestSet(
          eventId: _id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 7, 1),
          createdAt: day(2026, 7, 1),
          questId: id,
          name: id,
          targetCents: 100000,
          ownership: const PersonalParty(u1),
          mainCategoryId: cat,
        );
        final events = [
          rules(jul, 20),
          slice('fun', 10000, carryPct: 10, mainCat: 'entertainment'),
          quest('console', 'entertainment'),
          quest('canoe', 'misc'),
          allocate('fun', jul, [
            line(const QuestDestination('console'), 5000),
            line(const QuestDestination('canoe'), 5000),
          ]),
        ];
        final s = reduce(events, asOf: day(2026, 8, 15));
        expect(s.quests['console']!.balanceCents, 5000);
        expect(s.quests['canoe']!.balanceCents, 4000);
      },
    );

    test('defaults after grace never touch savings', () {
      final events = [
        rules(jul, 20),
        slice('clothes', 5000, carryPct: 10, policy: const Discretionary()),
        allocate('clothes', jul, [line(const CarryInSlice(), 5000)]),
      ];
      final s = reduce(events, asOf: graceExpired(aug));
      expect(s.categorySavings['clothes']!.balanceCents, 4500);
      expect(s.vaultOf(u1), 4000); // August's $50 by default policy at 20%.
    });

    test('the adoption month honours the last legacy carry', () {
      final events = [
        rules(aug, 20),
        slice('clothes', 5000),
        allocate('clothes', jul, [line(const CarryInSlice(), 5000)]), // legacy
      ];
      final s = reduce(events, asOf: day(2026, 8, 15));
      expect(s.sliceMonth('clothes', jul)!.carryOutCents, 5000);
      expect(s.sliceMonth('clothes', aug)!.effectiveLimitCents, 10000);
    });

    test('months before adoption reduce exactly as without the rules', () {
      final base = [
        slice('clothes', 5000, carryPct: 10, policy: const Discretionary()),
        buy('b', const SliceCharge('clothes'), 1234, day(2026, 7, 9)),
        allocate('clothes', jul, [line(const Discretionary(), 3766)]),
      ];
      final legacy = reduce(base, asOf: day(2026, 8, 15));
      final adoptedLater = reduce([
        ...base,
        rules(sep, 20),
      ], asOf: day(2026, 8, 15));
      expect(adoptedLater.vaultOf(u1), legacy.vaultOf(u1));
      expect(adoptedLater.warChest.balanceCents, legacy.warChest.balanceCents);
      expect(
        adoptedLater.sliceMonth('clothes', jul)!.leftoverCents,
        legacy.sliceMonth('clothes', jul)!.leftoverCents,
      );
    });
  });

  group('shortfall covers', () {
    ShortfallCovered cover(
      String purchaseId,
      CoverSource src,
      int amt,
      DateTime at,
    ) => ShortfallCovered(
      eventId: _id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: at,
      createdAt: at,
      purchaseId: purchaseId,
      source: src,
      amountCents: amt,
    );
    GiftReceived gift(int amt) => GiftReceived(
      eventId: _id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: day(2026, 7, 1),
      createdAt: day(2026, 7, 1),
      forUserId: u1,
      amountCents: amt,
    );

    test('the general pool covers a category purchase, so no overspend', () {
      final events = [
        rules(jul, 20),
        gift(10000),
        slice('clothes', 25000),
        buy('jacket', const SliceCharge('clothes'), 30000, day(2026, 7, 10)),
        cover('jacket', const GeneralCover(), 5000, day(2026, 7, 10)),
      ];
      final s = reduce(events, asOf: justClosed(jul));
      expect(s.sliceMonth('clothes', jul)!.overspendCents, 0);
      expect(s.sliceMonth('clothes', jul)!.coveredCents, 5000);
      expect(s.vaultOf(u1), 5000);
      expect(s.overbudgets, isEmpty);
    });

    test('a voided purchase voids its cover', () {
      final events = [
        rules(jul, 20),
        gift(10000),
        slice('clothes', 25000),
        buy('jacket', const SliceCharge('clothes'), 30000, day(2026, 7, 10)),
        cover('jacket', const GeneralCover(), 5000, day(2026, 7, 10)),
        PurchaseVoided(
          eventId: _id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 7, 11),
          createdAt: day(2026, 7, 11),
          purchaseId: 'jacket',
        ),
      ];
      expect(reduce(events, asOf: justClosed(jul)).vaultOf(u1), 10000);
    });

    test(
      'buying a quest goal early with category savings pays the difference',
      () {
        final events = [
          rules(jul, 20),
          slice('fun', 10000, carryPct: 10, mainCat: 'entertainment'),
          QuestSet(
            eventId: _id(),
            deviceId: 'd',
            userId: u1,
            occurredAt: day(2026, 7, 1),
            createdAt: day(2026, 7, 1),
            questId: 'canoe',
            name: 'Canoe',
            targetCents: 13000,
            ownership: const PersonalParty(u1),
            mainCategoryId: 'misc',
          ),
          allocate('fun', jul, [
            line(const QuestDestination('canoe'), 5000), // → 4000 (20%)
            line(const CarryInSlice(), 5000), // savings 4500 paid 500
          ]),
          buy('canoeBuy', const QuestCharge('canoe'), 13000, day(2026, 8, 5)),
          // Short $90: move all $45 of savings (top-up $5 → $40 lands).
          cover(
            'canoeBuy',
            const CategorySavingsCover('fun'),
            4500,
            day(2026, 8, 5),
          ),
        ];
        final s = reduce(events, asOf: day(2026, 8, 20));
        expect(s.categorySavings['fun']!.balanceCents, 0);
        expect(s.quests['canoe']!.contributions[u1], 8000);
      },
    );

    test('covers on one purchase never exceed its amount', () {
      final events = [
        rules(jul, 20),
        gift(100000),
        slice('clothes', 25000),
        buy('jacket', const SliceCharge('clothes'), 30000, day(2026, 7, 10)),
        cover('jacket', const GeneralCover(), 20000, day(2026, 7, 10)),
        cover('jacket', const GeneralCover(), 20000, day(2026, 7, 10)),
      ];
      expect(reduce(events, asOf: justClosed(jul)).vaultOf(u1), 100000 - 30000);
    });
  });
}
