/// THE FIREWALL TEST — permanent, load-bearing.
///
/// The game/rewards layer may append ONLY cosmetic events ([CosmeticSet],
/// [GameRewardGranted], sprite/description references). The money reducer must
/// ignore them completely: a rich ledger reduced *with* every cosmetic event
/// and *without* any of them must produce byte-for-byte identical balances.
///
/// If this test ever fails, a cosmetic/game mechanic has leaked into the money
/// math and the invariant is broken. Do not delete or weaken it.
library;

import 'package:duobudget/domain/event.dart';
import 'package:duobudget/domain/reducer.dart';
import 'package:duobudget/domain/time.dart';
import 'package:duobudget/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

const _u1 = 'u1';
const _u2 = 'u2';

class _Seq {
  int _n = 0;
  String id() => 'e${(_n++).toString().padLeft(4, '0')}';
}

DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

void main() {
  group('firewall: cosmetic events never move a cent', () {
    final seq = _Seq();

    Event member(String id, String name, MemberRole role) => MemberSet(
          eventId: seq.id(),
          deviceId: 'd',
          userId: _u1,
          occurredAt: _day(2026, 1, 1),
          createdAt: _day(2026, 1, 1),
          memberId: id,
          name: name,
          role: role,
        );

    // A deliberately rich ledger exercising many money-moving event types.
    final domainEvents = <Event>[
      member(_u1, 'Ada', MemberRole.adult),
      member(_u2, 'Ben', MemberRole.adult),
      member('pet1', 'Rex', MemberRole.pet),
      DefaultIncomeSet(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 1),
        createdAt: _day(2026, 1, 1),
        forUserId: _u1,
        amountCents: 500000,
        effectiveFromMonth: const Month(2026, 1),
      ),
      DefaultIncomeSet(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u2,
        occurredAt: _day(2026, 1, 1),
        createdAt: _day(2026, 1, 1),
        forUserId: _u2,
        amountCents: 400000,
        effectiveFromMonth: const Month(2026, 1),
      ),
      // A personal category with a pool tithe and a discretionary default.
      BudgetSliceSet(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 1),
        createdAt: _day(2026, 1, 1),
        sliceId: 'hygiene',
        name: 'Hygiene',
        ownership: const PersonalSlice(_u1),
        mainCategoryId: 'health',
        limitCents: 20000,
        poolTithePct: 50,
        defaultLeftoverPolicy: const Discretionary(),
        taxDeductibleByDefault: false,
      ),
      // A group category funded off the top.
      BudgetSliceSet(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 1),
        createdAt: _day(2026, 1, 1),
        sliceId: 'groceries',
        name: 'Groceries',
        ownership: const GroupSlice(),
        mainCategoryId: 'food',
        limitCents: 60000,
        poolTithePct: 0,
        defaultLeftoverPolicy: const CarryInSlice(),
        taxDeductibleByDefault: false,
      ),
      // A savings-goal quest matched to Entertainment.
      QuestSet(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 1),
        createdAt: _day(2026, 1, 1),
        questId: 'console',
        name: 'Console',
        targetCents: 40000,
        ownership: const PersonalParty(_u1),
        mainCategoryId: 'entertainment',
      ),
      // An emergency fund, pet-linked.
      EmergencyFundSet(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 1),
        createdAt: _day(2026, 1, 1),
        fundId: 'vetfund',
        name: 'Vet fund',
        petId: 'pet1',
      ),
      // Purchases against slice, group, vault, quest and emergency.
      PurchaseAdded(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 10),
        createdAt: _day(2026, 1, 10),
        purchaseId: 'p1',
        target: const SliceCharge('hygiene'),
        amountCents: 10000,
        merchant: 'Pharmacy',
      ),
      PurchaseAdded(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u2,
        occurredAt: _day(2026, 1, 12),
        createdAt: _day(2026, 1, 12),
        purchaseId: 'p2',
        target: const SliceCharge('groceries'),
        amountCents: 25000,
      ),
      PurchaseAdded(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 15),
        createdAt: _day(2026, 1, 15),
        purchaseId: 'p3',
        target: const EmergencyCharge('vetfund'),
        amountCents: 8000,
        note: 'Rex checkup',
      ),
      // Gift, pool contribution, tax refund, war-chest goal.
      GiftReceived(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 20),
        createdAt: _day(2026, 1, 20),
        forUserId: _u1,
        amountCents: 5000,
        note: 'Birthday',
      ),
      PoolContributionMade(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u2,
        occurredAt: _day(2026, 1, 22),
        createdAt: _day(2026, 1, 22),
        fromUserId: _u2,
        amountCents: 15000,
      ),
      TaxRefundRecorded(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 25),
        createdAt: _day(2026, 1, 25),
        amountCents: 30000,
      ),
      GoalSet(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 1),
        createdAt: _day(2026, 1, 1),
        targetCents: 100000,
      ),
      // A withdrawal proposed by one adult, approved by the other.
      PoolWithdrawalProposed(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 26),
        createdAt: _day(2026, 1, 26),
        proposalId: 'w1',
        byUserId: _u1,
        amountCents: 4000,
        purpose: 'New pan',
        destination: const UserVaultDestination(_u1),
      ),
      PoolWithdrawalApproved(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u2,
        occurredAt: _day(2026, 1, 27),
        createdAt: _day(2026, 1, 27),
        proposalId: 'w1',
        byUserId: _u2,
      ),
      // Close January's hygiene leftover: attack the (non-matching) quest.
      LeftoverAllocated(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 31),
        createdAt: _day(2026, 2, 2),
        forUserId: _u1,
        month: const Month(2026, 1),
        sliceId: 'hygiene',
        allocations: const [
          Allocation(destination: QuestDestination('console'), amountCents: 10000),
        ],
      ),
      // A tracked net-worth account with a recorded balance.
      TrackedAccountSet(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 1),
        createdAt: _day(2026, 1, 1),
        accountId: 'sav1',
        name: 'Savings',
        kind: AccountKind.savings,
      ),
      AccountBalanceRecorded(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 5),
        createdAt: _day(2026, 1, 5),
        accountId: 'sav1',
        accountName: 'Savings',
        kind: AccountKind.savings,
        balanceCents: 250000,
      ),
    ];

    // The cosmetic events that must be inert: skin settings and every kind of
    // granted reward.
    final cosmeticEvents = <Event>[
      CosmeticSet(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 2),
        createdAt: _day(2026, 1, 2),
        key: 'skin.homestead.flavor',
        value: 'town',
      ),
      GameRewardGranted(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 31),
        createdAt: _day(2026, 1, 31),
        rewardId: 'trophy:quest:console',
        kind: RewardKind.trophy,
        sourceRef: 'console',
        grantedAt: _day(2026, 1, 31),
      ),
      GameRewardGranted(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 15),
        createdAt: _day(2026, 1, 15),
        rewardId: 'title:daily:7',
        kind: RewardKind.title,
        sourceRef: 'daily:7',
        grantedAt: _day(2026, 1, 15),
      ),
      GameRewardGranted(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 2, 2),
        createdAt: _day(2026, 2, 2),
        rewardId: 'badge:ritual:1',
        kind: RewardKind.badge,
        sourceRef: 'ritual:1',
        grantedAt: _day(2026, 2, 2),
      ),
    ];

    final asOf = _day(2026, 2, 15);

    test('stripped-cosmetic ledger reduces to identical balances', () {
      final full = [...domainEvents, ...cosmeticEvents];
      final withCosmetic = reduce(full, asOf: asOf);
      final withoutCosmetic = reduce(domainEvents, asOf: asOf);

      expect(
        withCosmetic.debugSnapshot(),
        equals(withoutCosmetic.debugSnapshot()),
      );
    });

    test('cosmetic events do not introduce ledger users or move net worth', () {
      final full = [...domainEvents, ...cosmeticEvents];
      final withCosmetic = reduce(full, asOf: asOf);
      final withoutCosmetic = reduce(domainEvents, asOf: asOf);

      expect(withCosmetic.userIds, equals(withoutCosmetic.userIds));
      expect(
        withCosmetic.warChest.balanceCents,
        equals(withoutCosmetic.warChest.balanceCents),
      );
      expect(
        withCosmetic.netWorth.totalCents,
        equals(withoutCosmetic.netWorth.totalCents),
      );
      expect(
        withCosmetic.vaultCents,
        equals(withoutCosmetic.vaultCents),
      );
    });

    test('order-independence holds with cosmetic events interleaved', () {
      final full = [...domainEvents, ...cosmeticEvents];
      final shuffled = [...full]..shuffle();
      expect(
        reduce(shuffled, asOf: asOf).debugSnapshot(),
        equals(reduce(full, asOf: asOf).debugSnapshot()),
      );
    });
  });
}
