import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/money.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/state.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/dashboard/dashboard_model.dart';
import 'package:lootlog/game/domain/town/quest_board_view.dart';

import '../../../features/spoils/spoils_fixtures.dart';

/// October 3rd 2026: inside September's month-end window.
final DateTime boardInstant = dayOf(2026, 10, 3);
const Month october = Month(2026, 10);
const Month september = Month(2026, 9);
const names = {'alex': 'Alex', 'sam': 'Sam'};

DateTime octoberAt(int day, int hour) => DateTime.utc(2026, 10, day, hour);

void groupCategory(
  TestLedger ledger,
  String sliceId, {
  int limitCents = 30000,
}) => ledger.events.add(
  BudgetSliceSet(
    eventId: 'group-$sliceId',
    deviceId: 'd',
    userId: 'alex',
    occurredAt: setupInstant,
    createdAt: setupInstant,
    sliceId: sliceId,
    name: sliceId,
    ownership: const GroupSlice(),
    limitCents: limitCents,
    poolTithePct: 0,
    defaultLeftoverPolicy: const Discretionary(),
    taxDeductibleByDefault: false,
    mainCategoryId: 'food',
  ),
);

void boughtAt(
  TestLedger ledger,
  String purchaseId,
  String who,
  String sliceId,
  int cents,
  DateTime when, {
  String? merchant,
  bool voided = false,
}) => ledger.events.add(
  PurchaseAdded(
    eventId: 'buy-$purchaseId',
    deviceId: 'd',
    userId: who,
    occurredAt: when,
    createdAt: when,
    purchaseId: purchaseId,
    target: SliceCharge(sliceId),
    amountCents: cents,
    merchant: merchant,
  ),
);

/// Alex and Sam. Alex has Fun (overspent this month) and Food; Sam has Games
/// (overspent in September with an empty pouch, so its OVERBUDGET stands);
/// Groceries is a group category. Four goals: Jacket 50%, Canoe 10%, Boat 0%
/// and Tent (reached).
TestLedger boardLedger() {
  final ledger = TestLedger()
    ..adult('alex')
    ..adult('sam')
    ..category(
      'fun',
      owner: 'alex',
      limitCents: 20000,
      mainCategoryId: 'entertainment',
    )
    ..category('food', owner: 'alex', limitCents: 40000, mainCategoryId: 'food')
    ..category(
      'games',
      owner: 'sam',
      limitCents: 10000,
      mainCategoryId: 'entertainment',
      since: dayOf(2026, 9, 1),
    )
    ..quest('canoe', 130000, ownership: const PersonalParty('alex'))
    ..quest('jacket', 50000, pictureSha256: 'jacket-picture')
    ..quest('boat', 100000)
    ..quest('tent', 10000);
  groupCategory(ledger, 'groceries');
  ledger
    ..buy('sam', 'games', 15000, dayOf(2026, 9, 20))
    ..allocate('alex', 'fun', september, const [
      Allocation(destination: QuestDestination('canoe'), amountCents: 13000),
      Allocation(destination: Discretionary(), amountCents: 7000),
    ])
    ..allocate('alex', 'food', september, const [
      Allocation(destination: QuestDestination('jacket'), amountCents: 25000),
      Allocation(destination: QuestDestination('tent'), amountCents: 10000),
      Allocation(destination: Discretionary(), amountCents: 5000),
    ]);
  boughtAt(ledger, 'p1', 'alex', 'fun', 25000, octoberAt(1, 15));
  boughtAt(ledger, 'p2', 'alex', 'food', 10000, octoberAt(1, 16));
  boughtAt(ledger, 'p3', 'sam', 'games', 2000, octoberAt(1, 17));
  boughtAt(
    ledger,
    'p4',
    'alex',
    'groceries',
    3000,
    octoberAt(2, 15),
    merchant: 'Corner Market',
  );
  boughtAt(ledger, 'p5', 'alex', 'food', 1000, octoberAt(2, 16));
  boughtAt(ledger, 'p6', 'sam', 'groceries', 500, octoberAt(2, 17));
  return ledger;
}

QuestBoardView boardFor(HouseholdState state, {bool showOtherAdults = true}) =>
    QuestBoardView.from(
      state,
      meId: 'alex',
      month: october,
      showOtherAdults: showOtherAdults,
      names: names,
    );

void main() {
  final household = reduce(boardLedger().events, asOf: boardInstant);

  group('goals', () {
    test('incomplete goals only, by percent descending', () {
      final goals = boardFor(household).goals;
      expect(goals.map((goal) => goal.questId), ['jacket', 'canoe', 'boat']);
      expect(goals.map((goal) => goal.percent), [50, 10, 0]);
    });

    test(
      'carry the target, what is left to reach it, ownership and picture',
      () {
        final jacket = boardFor(household).goals.first;
        expect(jacket.name, 'jacket');
        expect(jacket.target, const Money(50000));
        expect(jacket.remaining, const Money(25000));
        expect(jacket.shared, isTrue);
        expect(jacket.pictureSha256, 'jacket-picture');
        final canoe = boardFor(household).goals[1];
        expect(canoe.shared, isFalse);
        expect(canoe.pictureSha256, isNull);
      },
    );

    test('an almost-reached goal reads 99%, never 100%', () {
      final ledger = TestLedger()
        ..adult('alex')
        ..category(
          'big',
          owner: 'alex',
          limitCents: 100000,
          since: dayOf(2026, 9, 1),
        )
        ..quest('kayak', 100000)
        ..allocate('alex', 'big', september, const [
          Allocation(
            destination: QuestDestination('kayak'),
            amountCents: 99600,
          ),
          Allocation(destination: Discretionary(), amountCents: 400),
        ]);
      final goals = boardFor(reduce(ledger.events, asOf: boardInstant)).goals;
      expect(goals.single.percent, 99);
      expect(goals.single.remaining, const Money(400));
    });
  });

  group('monsters', () {
    test('mine first, then group, then the other adults', () {
      final monsters = boardFor(household).monsters;
      expect(monsters.map((monster) => monster.categoryId), [
        'food',
        'fun',
        'groceries',
        'games',
      ]);
      expect(monsters.map((monster) => monster.group), [
        false,
        false,
        true,
        false,
      ]);
    });

    test(
      'remaining and limit match the Standard dashboard for the same category',
      () {
        final dashboard = buildDashboardModel(
          household,
          meUserId: 'alex',
          userNames: names,
          asOf: boardInstant,
        );
        for (final monster in boardFor(household).monsters) {
          final ring = dashboard.slices.singleWhere(
            (ring) => ring.sliceId == monster.categoryId,
          );
          expect(
            monster.remaining,
            Money(ring.remainingCents),
            reason: monster.categoryId,
          );
          expect(
            monster.limit,
            Money(ring.effectiveLimitCents),
            reason: monster.categoryId,
          );
          expect(monster.enraged, ring.overspent, reason: monster.categoryId);
          expect(
            monster.overspend,
            Money(ring.overspendCents),
            reason: monster.categoryId,
          );
        }
      },
    );

    test('an overspent category is enraged; one within its limit is calm', () {
      final monsters = {
        for (final monster in boardFor(household).monsters)
          monster.categoryId: monster,
      };
      expect(monsters['fun']!.enraged, isTrue);
      expect(monsters['fun']!.remaining, Money.zero);
      expect(monsters['food']!.enraged, isFalse);
      expect(monsters['food']!.remaining, const Money(29000));
      expect(monsters['fun']!.overspend, const Money(5000));
      expect(monsters['food']!.overspend, Money.zero);
    });

    test('carries its main category colour', () {
      final fun = boardFor(
        household,
      ).monsters.singleWhere((monster) => monster.categoryId == 'fun');
      expect(
        fun.colorArgb,
        household.mainCategories['entertainment']!.colorArgb,
      );
    });

    test(
      'hiding other adults drops their personal categories but keeps group ones',
      () {
        final monsters = boardFor(household, showOtherAdults: false).monsters;
        expect(monsters.map((monster) => monster.categoryId), [
          'food',
          'fun',
          'groceries',
        ]);
      },
    );
  });

  group('debts', () {
    test(
      'an OVERBUDGET is listed with its category and what is outstanding',
      () {
        final debts = boardFor(household).debts;
        expect(debts, hasLength(1));
        expect(debts.single.categoryId, 'games');
        expect(debts.single.name, 'games');
        expect(debts.single.outstanding, const Money(5000));
      },
    );

    test('follows the visibility preference like the Standard dashboard', () {
      expect(boardFor(household, showOtherAdults: false).debts, isEmpty);
    });

    test('no debts on a clean ledger', () {
      final clean = TestLedger()
        ..adult('alex')
        ..category('fun', owner: 'alex');
      expect(boardFor(reduce(clean.events, asOf: boardInstant)).debts, isEmpty);
    });
  });

  group('recent purchases', () {
    test('the five newest, newest first, labelled by merchant or category', () {
      final recent = boardFor(household).recent;
      expect(recent, hasLength(5));
      expect(recent.map((entry) => entry.label), [
        'groceries',
        'food',
        'Corner Market',
        'games',
        'food',
      ]);
      expect(recent.first.amount, const Money(500));
      expect(recent.first.occurredAt, octoberAt(2, 17));
      expect(recent.map((entry) => entry.occurredAt).toList(), [
        octoberAt(2, 17),
        octoberAt(2, 16),
        octoberAt(2, 15),
        octoberAt(1, 17),
        octoberAt(1, 16),
      ]);
    });

    test(
      'hiding other adults drops purchases on their personal categories',
      () {
        final recent = boardFor(household, showOtherAdults: false).recent;
        expect(recent.map((entry) => entry.occurredAt).toList(), [
          octoberAt(2, 17),
          octoberAt(2, 16),
          octoberAt(2, 15),
          octoberAt(1, 16),
          octoberAt(1, 15),
        ]);
      },
    );
  });

  group('pending writs', () {
    test('none on a ledger without proposals', () {
      expect(boardFor(household).pendingWrits, 0);
    });

    test('counts pending war-chest withdrawals and allowance advances', () {
      final ledger = boardLedger()
        ..setting('savingsRules', {
          'fromMonth': '2026-10',
          'generalTithePct': 20,
        });
      ledger.events
        ..add(
          PoolWithdrawalProposed(
            eventId: 'writ-1',
            deviceId: 'd',
            userId: 'alex',
            occurredAt: octoberAt(2, 18),
            createdAt: octoberAt(2, 18),
            proposalId: 'writ-1',
            byUserId: 'alex',
            amountCents: 1000,
            purpose: 'New boots',
            destination: const UserVaultDestination('alex'),
          ),
        )
        ..add(
          PoolWithdrawalProposed(
            eventId: 'writ-2',
            deviceId: 'd',
            userId: 'sam',
            occurredAt: octoberAt(2, 18),
            createdAt: octoberAt(2, 18),
            proposalId: 'writ-2',
            byUserId: 'sam',
            amountCents: 2000,
            purpose: 'Repairs',
            destination: const ExternalDestination(),
          ),
        )
        ..add(
          PoolWithdrawalCancelled(
            eventId: 'writ-2-cancel',
            deviceId: 'd',
            userId: 'sam',
            occurredAt: octoberAt(2, 19),
            createdAt: octoberAt(2, 19),
            proposalId: 'writ-2',
          ),
        )
        ..add(
          AllowanceAdvanceProposed(
            eventId: 'advance-1',
            deviceId: 'd',
            userId: 'sam',
            occurredAt: octoberAt(2, 18),
            createdAt: octoberAt(2, 18),
            advanceId: 'advance-1',
            byUserId: 'sam',
            sliceId: 'games',
            amountCents: 3000,
            months: 2,
          ),
        );
      final state = reduce(ledger.events, asOf: boardInstant);
      expect(boardFor(state).pendingWrits, 2);
    });
  });
}
