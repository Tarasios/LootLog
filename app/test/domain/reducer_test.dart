import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/state.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

/// Household users.
const u1 = 'u1';
const u2 = 'u2';

/// A monotonically-increasing event-id / timestamp helper so tests can add
/// events tersely while keeping a deterministic total order.
class Seq {
  int _n = 0;
  String id() => 'e${(_n++).toString().padLeft(4, '0')}';
}

final _seq = Seq();

/// Instant at 18:00 UTC (== 10:00/11:00 local) on a given household-local day,
/// safely inside the day for month-keying purposes.
DateTime day(int year, int month, int d) => DateTime.utc(year, month, d, 18);

/// A read-time just past the given month's spoils grace period, landing in the
/// following (still-open) month so exactly that one month is closed & resolved.
DateTime graceExpired(Month m) =>
    m.endInstantUtc().add(const Duration(days: 8));

BudgetSliceSet slice({
  required String id,
  required SliceOwnership ownership,
  required int limit,
  int tithePct = 0,
  LeftoverDestination policy = const Discretionary(),
  bool taxDefault = false,
  String? mainCategoryId,
  EmergencyContribution? emergency,
  String? petId,
  DateTime? at,
}) =>
    BudgetSliceSet(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: at ?? day(2026, 1, 1),
      createdAt: at ?? day(2026, 1, 1),
      sliceId: id,
      name: id,
      ownership: ownership,
      mainCategoryId: mainCategoryId,
      limitCents: limit,
      poolTithePct: tithePct,
      defaultLeftoverPolicy: policy,
      taxDeductibleByDefault: taxDefault,
      emergencyContribution: emergency,
      petId: petId,
    );

PurchaseAdded buy({
  required String id,
  required ChargeTarget target,
  required int amount,
  String by = u1,
  bool shared = false,
  String? merchant,
  bool? tax,
  String? note,
  required DateTime at,
}) =>
    PurchaseAdded(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: by,
      occurredAt: at,
      createdAt: at,
      purchaseId: id,
      target: target,
      amountCents: amount,
      shared: shared,
      merchant: merchant,
      taxDeductible: tax,
      note: note,
    );

MemberSet member({
  required String id,
  required MemberRole role,
  String? name,
  bool active = true,
  String? descriptionText,
  DateTime? at,
}) =>
    MemberSet(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: at ?? day(2026, 1, 1),
      createdAt: at ?? day(2026, 1, 1),
      memberId: id,
      name: name ?? id,
      role: role,
      active: active,
      descriptionText: descriptionText,
    );

/// Two adult members, the common household shape for reducer fixtures.
List<Event> twoAdults() => [
      member(id: u1, role: MemberRole.adult),
      member(id: u2, role: MemberRole.adult),
    ];

QuestSet quest({
  required String id,
  required String name,
  required int target,
  PartyOwnership ownership = const SharedParty(),
  String? mainCategoryId,
  String? descriptionText,
  DateTime? at,
}) =>
    QuestSet(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: at ?? day(2026, 1, 1),
      createdAt: at ?? day(2026, 1, 1),
      questId: id,
      name: name,
      targetCents: target,
      ownership: ownership,
      mainCategoryId: mainCategoryId,
      descriptionText: descriptionText,
    );

LeftoverAllocated allocate({
  required String user,
  required String sliceId,
  required Month month,
  required List<Allocation> allocations,
  required DateTime at,
}) =>
    LeftoverAllocated(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: user,
      occurredAt: at,
      createdAt: at,
      forUserId: user,
      month: month,
      sliceId: sliceId,
      allocations: allocations,
    );

void main() {
  group('group slices', () {
    test('group leftover flows fully to the war chest with no allocation', () {
      final events = [
        slice(id: 'g', ownership: const GroupSlice(), limit: 60000),
        buy(id: 'p1', target: const SliceCharge('g'), amount: 20000,
            at: day(2026, 1, 10)),
      ];
      final s = reduce(events, asOf: graceExpired(const Month(2026, 1)));
      expect(s.warChest.balanceCents, 40000);
      final sm = s.sliceMonth('g', const Month(2026, 1))!;
      expect(sm.spentCents, 20000);
      expect(sm.leftoverCents, 40000);
    });
  });

  group('personal-slice leftover resolution', () {
    test('default policy applies only after the grace period', () {
      final events = [
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 10000,
          tithePct: 10,
          policy: const Discretionary(),
        ),
        buy(id: 'p', target: const SliceCharge('s'), amount: 4000,
            at: day(2026, 1, 5)),
      ];
      // Within grace: leftover is unresolved (no vault / chest movement yet).
      final within = reduce(events,
          asOf: const Month(2026, 1).endInstantUtc().add(const Duration(days: 1)));
      expect(within.sliceMonth('s', const Month(2026, 1))!.resolved, isFalse);
      expect(within.vaultOf(u1), 0);
      expect(within.warChest.balanceCents, 0);

      // Past grace: default discretionary policy fires (leftover 6000, 10%
      // tithe = 600 to chest, 5400 to vault).
      final after = reduce(events, asOf: graceExpired(const Month(2026, 1)));
      expect(after.sliceMonth('s', const Month(2026, 1))!.resolved, isTrue);
      expect(after.warChest.balanceCents, 600);
      expect(after.vaultOf(u1), 5400);
    });

    test('an allocation within grace overrides the default policy', () {
      final events = [
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 10000,
          tithePct: 10,
          policy: const Discretionary(),
        ),
        buy(id: 'p', target: const SliceCharge('s'), amount: 4000,
            at: day(2026, 1, 5)),
        allocate(
          user: u1,
          sliceId: 's',
          month: const Month(2026, 1),
          allocations: const [
            Allocation(destination: CarryInSlice(), amountCents: 6000),
          ],
          at: day(2026, 1, 20),
        ),
      ];
      final s = reduce(events,
          asOf: const Month(2026, 1).endInstantUtc().add(const Duration(days: 1)));
      // Carried, not converted: no tithe, no vault money.
      expect(s.warChest.balanceCents, 0);
      expect(s.vaultOf(u1), 0);
      expect(s.sliceMonth('s', const Month(2026, 2))!.carryInCents, 6000);
    });

    test('carry-in-slice stacks across months', () {
      final events = [
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 10000,
          policy: const CarryInSlice(),
        ),
        // No spending in Jan, Feb, Mar; default carry each month past grace.
      ];
      final s = reduce(events, asOf: day(2026, 4, 15));
      expect(s.sliceMonth('s', const Month(2026, 1))!.effectiveLimitCents, 10000);
      expect(s.sliceMonth('s', const Month(2026, 2))!.effectiveLimitCents, 20000);
      expect(s.sliceMonth('s', const Month(2026, 3))!.effectiveLimitCents, 30000);
      expect(s.sliceMonth('s', const Month(2026, 4))!.effectiveLimitCents, 40000);
    });
  });

  group('quests', () {
    test('funded from two slices then completed by a QUEST purchase', () {
      final events = [
        QuestSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          questId: 'q',
          name: 'Canoe',
          targetCents: 50000,
          ownership: const PersonalParty(u1),
        ),
        slice(id: 'a', ownership: const PersonalSlice(u1), limit: 30000),
        slice(id: 'b', ownership: const PersonalSlice(u1), limit: 30000),
        allocate(
          user: u1,
          sliceId: 'a',
          month: const Month(2026, 1),
          allocations: const [
            Allocation(destination: QuestDestination('q'), amountCents: 30000),
          ],
          at: day(2026, 1, 20),
        ),
        allocate(
          user: u1,
          sliceId: 'b',
          month: const Month(2026, 1),
          allocations: const [
            Allocation(destination: QuestDestination('q'), amountCents: 20000),
          ],
          at: day(2026, 1, 20),
        ),
        // Buying the goal draws the quest balance down.
        buy(id: 'g', target: const QuestCharge('q'), amount: 50000,
            at: day(2026, 2, 3)),
      ];
      final s = reduce(events, asOf: day(2026, 2, 10));
      final q = s.quests['q']!;
      expect(q.completed, isTrue); // funded to target
      expect(q.balanceCents, 0); // drawn down by the purchase
      // Funding a quest is untithed: no war-chest movement.
      expect(s.warChest.balanceCents, 0);
    });

    test('shared quest abandoned: proportional return minus dissolution tithe', () {
      final events = [
        QuestSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          questId: 'q',
          name: 'Trip',
          targetCents: 100000,
          ownership: const SharedParty(),
        ),
        slice(id: 'a', ownership: const PersonalSlice(u1), limit: 50000),
        slice(id: 'b', ownership: const PersonalSlice(u2), limit: 90000),
        allocate(
          user: u1,
          sliceId: 'a',
          month: const Month(2026, 1),
          allocations: const [
            Allocation(destination: QuestDestination('q'), amountCents: 40000),
          ],
          at: day(2026, 1, 20),
        ),
        allocate(
          user: u2,
          sliceId: 'b',
          month: const Month(2026, 1),
          allocations: const [
            Allocation(destination: QuestDestination('q'), amountCents: 60000),
          ],
          at: day(2026, 1, 20),
        ),
        QuestAbandoned(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 2, 1),
          createdAt: day(2026, 2, 1),
          questId: 'q',
        ),
      ];
      final s = reduce(events, asOf: day(2026, 2, 10));
      // balance 100000; 10% dissolution tithe = 10000 to chest; 90000 split
      // 40:60 -> u1 36000, u2 54000. Sums exact.
      expect(s.warChest.balanceCents, 10000);
      expect(s.vaultOf(u1), 36000);
      expect(s.vaultOf(u2), 54000);
      expect(s.vaultOf(u1) + s.vaultOf(u2) + s.warChest.balanceCents, 100000);
      expect(s.quests['q']!.abandoned, isTrue);
      expect(s.quests['q']!.balanceCents, 0);
    });

    test('dissolution split with rounding still sums exactly', () {
      final events = [
        QuestSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          questId: 'q',
          name: 'Odd',
          targetCents: 10,
          ownership: const SharedParty(),
        ),
        slice(id: 'a', ownership: const PersonalSlice(u1), limit: 100),
        slice(id: 'b', ownership: const PersonalSlice(u2), limit: 100),
        allocate(
          user: u1,
          sliceId: 'a',
          month: const Month(2026, 1),
          allocations: const [
            Allocation(destination: QuestDestination('q'), amountCents: 5),
          ],
          at: day(2026, 1, 20),
        ),
        allocate(
          user: u2,
          sliceId: 'b',
          month: const Month(2026, 1),
          allocations: const [
            Allocation(destination: QuestDestination('q'), amountCents: 5),
          ],
          at: day(2026, 1, 20),
        ),
        QuestAbandoned(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 2, 1),
          createdAt: day(2026, 2, 1),
          questId: 'q',
        ),
      ];
      final s = reduce(events, asOf: day(2026, 2, 10));
      // 10 total; tithe 1 -> chest; distributable 9, equal weights -> 5 + 4.
      expect(s.warChest.balanceCents, 1);
      expect(s.vaultOf(u1) + s.vaultOf(u2), 9);
      expect(s.vaultOf(u1) + s.vaultOf(u2) + s.warChest.balanceCents, 10);
    });
  });

  // The canonical category-match tithing invariant from CLAUDE.md: an attack
  // funded from a category whose main category MATCHES the quest's is untithed
  // (full damage); from a NON-matching category the source category's pool tithe
  // is skimmed to the war chest and only the remainder lands as damage.
  group('category-match tithing', () {
    test('non-matching source: \$100 hygiene @50% -> \$50 chest + \$50 damage',
        () {
      final events = [
        quest(
          id: 'console',
          name: 'Console',
          target: 100000,
          mainCategoryId: 'entertainment',
        ),
        slice(
          id: 'hygiene',
          ownership: const PersonalSlice(u1),
          limit: 10000,
          tithePct: 50,
          mainCategoryId: 'health',
        ),
        allocate(
          user: u1,
          sliceId: 'hygiene',
          month: const Month(2026, 1),
          allocations: const [
            Allocation(destination: QuestDestination('console'), amountCents: 10000),
          ],
          at: day(2026, 1, 20),
        ),
      ];
      final s = reduce(events, asOf: day(2026, 2, 10));
      final q = s.quests['console']!;
      // 50% of the $100 leftover is skimmed to the chest; $50 is the damage.
      expect(s.warChest.balanceCents, 5000);
      expect(q.balanceCents, 5000);
      expect(q.totalContributedCents, 5000);
      expect(q.contributions[u1], 5000);
    });

    test('matching source: \$100 entertainment @20% -> \$100 damage, \$0 tithe',
        () {
      final events = [
        quest(
          id: 'console',
          name: 'Console',
          target: 100000,
          mainCategoryId: 'entertainment',
        ),
        slice(
          id: 'games',
          ownership: const PersonalSlice(u1),
          limit: 10000,
          tithePct: 20,
          mainCategoryId: 'entertainment',
        ),
        allocate(
          user: u1,
          sliceId: 'games',
          month: const Month(2026, 1),
          allocations: const [
            Allocation(destination: QuestDestination('console'), amountCents: 10000),
          ],
          at: day(2026, 1, 20),
        ),
      ];
      final s = reduce(events, asOf: day(2026, 2, 10));
      final q = s.quests['console']!;
      // Matching main category: untithed, full damage, nothing to the chest.
      expect(s.warChest.balanceCents, 0);
      expect(q.balanceCents, 10000);
      expect(q.totalContributedCents, 10000);
      expect(q.contributions[u1], 10000);
    });

    test('a quest with no main category is always tithed off a tithed category',
        () {
      final events = [
        quest(id: 'q', name: 'Legacy', target: 100000),
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 10000,
          tithePct: 30,
          mainCategoryId: 'entertainment',
        ),
        allocate(
          user: u1,
          sliceId: 's',
          month: const Month(2026, 1),
          allocations: const [
            Allocation(destination: QuestDestination('q'), amountCents: 10000),
          ],
          at: day(2026, 1, 20),
        ),
      ];
      final s = reduce(events, asOf: day(2026, 2, 10));
      // No match (quest main category null) -> 30% to the chest, 70% damage.
      expect(s.warChest.balanceCents, 3000);
      expect(s.quests['q']!.balanceCents, 7000);
    });

    test('the mismatch tithe floors to the chest and sums exactly', () {
      final events = [
        quest(
          id: 'q',
          name: 'Odd',
          target: 100000,
          mainCategoryId: 'entertainment',
        ),
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 1005,
          tithePct: 10,
          mainCategoryId: 'health',
        ),
        allocate(
          user: u1,
          sliceId: 's',
          month: const Month(2026, 1),
          allocations: const [
            Allocation(destination: QuestDestination('q'), amountCents: 1005),
          ],
          at: day(2026, 1, 20),
        ),
      ];
      final s = reduce(events, asOf: day(2026, 2, 10));
      // 10% of 1005 -> floor 100 to chest, 905 damage; sums exactly.
      expect(s.warChest.balanceCents, 100);
      expect(s.quests['q']!.balanceCents, 905);
      expect(s.warChest.balanceCents + s.quests['q']!.balanceCents, 1005);
    });
  });

  group('tithe rounding', () {
    test('discretionary tithe floors to the chest and sums exactly', () {
      final events = [
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 1005,
          tithePct: 10,
          policy: const Discretionary(),
        ),
      ];
      final s = reduce(events, asOf: graceExpired(const Month(2026, 1)));
      // Leftover 1005; 10% -> floor 100 to chest, 905 to vault.
      expect(s.warChest.balanceCents, 100);
      expect(s.vaultOf(u1), 905);
      expect(s.warChest.balanceCents + s.vaultOf(u1), 1005);
    });
  });

  group('withdrawals', () {
    PoolWithdrawalProposed propose() => PoolWithdrawalProposed(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 10),
          createdAt: day(2026, 1, 10),
          proposalId: 'w',
          byUserId: u1,
          amountCents: 5000,
          purpose: 'tires',
          destination: const UserVaultDestination(u1),
        );

    List<Event> withPool() => [
          // Two adults, so "another adult" is a real requirement (not the
          // single-adult auto-approval path).
          ...twoAdults(),
          slice(id: 'g', ownership: const GroupSlice(), limit: 20000),
          buy(id: 'p', target: const SliceCharge('g'), amount: 0,
              at: day(2026, 1, 2)),
        ];

    test('self-approval is rejected; proposal stays pending', () {
      final events = [
        ...withPool(),
        propose(),
        PoolWithdrawalApproved(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 11),
          createdAt: day(2026, 1, 11),
          proposalId: 'w',
          byUserId: u1, // same as proposer
        ),
      ];
      final s = reduce(events, asOf: graceExpired(const Month(2026, 1)));
      expect(s.withdrawals['w']!.status, WithdrawalStatus.pending);
      expect(s.vaultOf(u1), 0);
      expect(s.warChest.balanceCents, 20000); // untouched
    });

    test('approval by the other user credits the destination vault', () {
      final events = [
        ...withPool(),
        propose(),
        PoolWithdrawalApproved(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u2,
          occurredAt: day(2026, 1, 11),
          createdAt: day(2026, 1, 11),
          proposalId: 'w',
          byUserId: u2,
        ),
      ];
      final s = reduce(events, asOf: graceExpired(const Month(2026, 1)));
      expect(s.withdrawals['w']!.status, WithdrawalStatus.approved);
      expect(s.vaultOf(u1), 5000);
      expect(s.warChest.balanceCents, 15000);
    });
  });

  group('gifts', () {
    test('gift credits the vault, untithed', () {
      final events = [
        GiftReceived(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 5),
          createdAt: day(2026, 1, 5),
          forUserId: u2,
          amountCents: 5000,
          note: 'bday',
        ),
      ];
      final s = reduce(events, asOf: day(2026, 1, 20));
      expect(s.vaultOf(u2), 5000);
      expect(s.warChest.balanceCents, 0);
    });
  });

  group('recurring expenses', () {
    test('variable expense uses estimate until an actual is recorded', () {
      RecurringExpenseSet utilities() => RecurringExpenseSet(
            eventId: _seq.id(),
            deviceId: 'd',
            userId: u1,
            occurredAt: day(2026, 1, 1),
            createdAt: day(2026, 1, 1),
            expenseId: 'r',
            name: 'Utilities',
            ownership: const PersonalParty(u1),
            kind: RecurringKind.variable,
            amountCents: 8000,
            startMonth: const Month(2026, 1),
          );

      final estimateOnly = reduce([utilities()], asOf: day(2026, 1, 20));
      expect(estimateOnly.recurringChargeFor(u1, const Month(2026, 1)), 8000);

      final withActual = reduce([
        utilities(),
        VariableExpenseRecorded(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 2, 3),
          createdAt: day(2026, 2, 3),
          expenseId: 'r',
          month: const Month(2026, 1),
          actualCents: 9500,
        ),
      ], asOf: day(2026, 2, 10));
      // Retroactive actual recomputes the (already-passed) month.
      expect(withActual.recurringChargeFor(u1, const Month(2026, 1)), 9500);
    });

    test('personal recurring hits only its owner', () {
      final s = reduce([
        RecurringExpenseSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          expenseId: 'sub',
          name: 'Patreon',
          ownership: const PersonalParty(u1),
          kind: RecurringKind.fixed,
          amountCents: 1500,
          startMonth: const Month(2026, 1),
        ),
        // Make u2 known to the household.
        slice(id: 's', ownership: const PersonalSlice(u2), limit: 100),
      ], asOf: day(2026, 1, 20));
      expect(s.recurringChargeFor(u1, const Month(2026, 1)), 1500);
      expect(s.recurringChargeFor(u2, const Month(2026, 1)), 0);
    });

    test('cancelled recurring stops at endMonth', () {
      final s = reduce([
        RecurringExpenseSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          expenseId: 'sub',
          name: 'Game',
          ownership: const PersonalParty(u1),
          kind: RecurringKind.fixed,
          amountCents: 1500,
          startMonth: const Month(2026, 1),
          endMonth: const Month(2026, 2),
        ),
      ], asOf: day(2026, 4, 20));
      expect(s.recurringChargeFor(u1, const Month(2026, 1)), 1500);
      expect(s.recurringChargeFor(u1, const Month(2026, 2)), 1500);
      expect(s.recurringChargeFor(u1, const Month(2026, 3)), 0);
      expect(s.recurringChargeFor(u1, const Month(2026, 4)), 0);
    });

    test('read-model exposes recurring configs and variable actuals', () {
      final s = reduce([
        RecurringExpenseSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          expenseId: 'rent',
          name: 'Rent',
          ownership: const SharedParty(),
          kind: RecurringKind.fixed,
          amountCents: 120000,
          startMonth: const Month(2026, 1),
        ),
        RecurringExpenseSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          expenseId: 'util',
          name: 'Utilities',
          ownership: const PersonalParty(u1),
          kind: RecurringKind.variable,
          amountCents: 8000,
          startMonth: const Month(2026, 1),
          endMonth: const Month(2026, 6),
        ),
        VariableExpenseRecorded(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 2, 3),
          createdAt: day(2026, 2, 3),
          expenseId: 'util',
          month: const Month(2026, 1),
          actualCents: 9500,
        ),
      ], asOf: day(2026, 2, 10));

      expect(s.recurringExpenses.length, 2);
      final util = s.recurringExpenses['util']!;
      expect(util.name, 'Utilities');
      expect(util.kind, RecurringKind.variable);
      expect(util.amountCents, 8000);
      expect(util.ownership, const PersonalParty(u1));
      expect(util.activeIn(const Month(2025, 12)), isFalse);
      expect(util.activeIn(const Month(2026, 1)), isTrue);
      expect(util.activeIn(const Month(2026, 6)), isTrue);
      expect(util.activeIn(const Month(2026, 7)), isFalse);

      final rent = s.recurringExpenses['rent']!;
      expect(rent.ownership, const SharedParty());
      expect(rent.activeIn(const Month(2027, 1)), isTrue); // no end month

      expect(s.variableActualFor('util', const Month(2026, 1)), 9500);
      expect(s.variableActualFor('util', const Month(2026, 2)), isNull);
      expect(s.variableActualFor('rent', const Month(2026, 1)), isNull);
    });

    RecurringExpenseSet annual({
      required int amountCents,
      int dueMonth = 2,
      int dueDay = 10,
      Month start = const Month(2026, 1),
      PartyOwnership ownership = const PersonalParty(u1),
      RecurringKind kind = RecurringKind.fixed,
    }) =>
        RecurringExpenseSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          expenseId: 'wow',
          name: 'WoW',
          ownership: ownership,
          kind: kind,
          cadence: RecurringCadence.annual,
          amountCents: amountCents,
          dueDay: dueDay,
          dueMonth: dueMonth,
          startMonth: start,
        );

    test('annual expense charges 1/12 monthly, remainder in the due month', () {
      // $131.00 / 12 = 1091 base, remainder 8 -> due month bears 1099.
      final s = reduce([annual(amountCents: 13100)], asOf: day(2026, 12, 20));
      var sum = 0;
      for (var mo = 1; mo <= 12; mo++) {
        final charge = s.recurringChargeFor(u1, Month(2026, mo));
        sum += charge;
        expect(charge, mo == 2 ? 1099 : 1091,
            reason: 'month $mo accrual');
      }
      // The twelve monthly accruals sum exactly to the annual amount.
      expect(sum, 13100);
    });

    test('a full accrual year reconciles the due month with no shortfall', () {
      // Starts a full year before the due month (Feb 2027), so the reserve is
      // exactly the annual amount when the bill lands.
      final s = reduce([
        annual(amountCents: 13100, start: const Month(2026, 3)),
      ], asOf: day(2027, 2, 20));
      final r = s.recurringExpenses['wow']!;
      final recon = r.lastReconciliation!;
      expect(recon.month, const Month(2027, 2));
      expect(recon.dueAmountCents, 13100);
      expect(recon.reserveBeforeCents, 13100);
      expect(recon.shortfallCents, 0);
      expect(recon.surplusCents, 0);
      // The bill was paid from the reserve; nothing carries into the new year.
      expect(r.reserveCents, 0);
    });

    test('a partial first year surfaces the shortfall, then self-corrects', () {
      // Starts Jan 2026, due Feb 2026: only two accruals (1091 + 1099 = 2190)
      // sit in the reserve when the $131.00 bill lands.
      final firstYear =
          reduce([annual(amountCents: 13100)], asOf: day(2026, 2, 20));
      final r1 = firstYear.recurringExpenses['wow']!;
      final recon1 = r1.lastReconciliation!;
      expect(recon1.month, const Month(2026, 2));
      expect(recon1.reserveBeforeCents, 2190);
      expect(recon1.shortfallCents, 13100 - 2190);
      expect(r1.reserveCents, 0); // emptied covering the bill

      // By the next due month (Feb 2027) a full year of accrual has built up,
      // so the second year reconciles cleanly.
      final secondYear =
          reduce([annual(amountCents: 13100)], asOf: day(2027, 2, 20));
      final recon2 = secondYear.recurringExpenses['wow']!.lastReconciliation!;
      expect(recon2.month, const Month(2027, 2));
      expect(recon2.reserveBeforeCents, 13100);
      expect(recon2.shortfallCents, 0);
    });

    test('reserve grows month over month between due dates', () {
      // Mid-year read, before the first due month: reserve is the sum of the
      // accruals so far (no reconciliation has happened yet).
      final s = reduce([
        annual(amountCents: 12000, start: const Month(2026, 1)),
      ], asOf: day(2026, 4, 20));
      final r = s.recurringExpenses['wow']!;
      // Jan..Apr = 4 * 1000 accrued; Feb is the due month.
      final recon = r.lastReconciliation!;
      expect(recon.month, const Month(2026, 2));
      // Jan(1000)+Feb(1000)=2000 reserve before the bill; shortfall paid it to 0
      // then Mar(1000)+Apr(1000) rebuild it.
      expect(r.reserveCents, 2000);
    });

    test('annual read-model carries cadence and due date', () {
      final s = reduce([annual(amountCents: 13100)], asOf: day(2026, 6, 20));
      final r = s.recurringExpenses['wow']!;
      expect(r.isAnnual, isTrue);
      expect(r.cadence, RecurringCadence.annual);
      expect(r.dueMonth, 2);
      expect(r.dueDay, 10);
      // Next Feb 10 from a June read is Feb 10 of the following year.
      expect(r.nextDueDate(DateTime(2026, 6, 20)), DateTime(2027, 2, 10));
      expect(r.daysUntilDue(DateTime(2026, 2, 5)), 5);
    });

    test('legacy recurring event reduces as a monthly expense', () {
      // A pre-cadence event: no cadence/dueDay/dueMonth in the payload.
      final legacy = Event.fromJson({
        'eventId': 'e-legacy',
        'deviceId': 'd',
        'userId': u1,
        'type': 'RecurringExpenseSet',
        'occurredAt': day(2026, 1, 1).toIso8601String(),
        'createdAt': day(2026, 1, 1).toIso8601String(),
        'payload': {
          'expenseId': 'old',
          'name': 'Netflix',
          'ownership': const PersonalParty(u1).toJson(),
          'kind': 'fixed',
          'amountCents': 1500,
          'startMonth': '2026-01',
        },
      });
      final s = reduce([legacy], asOf: day(2026, 1, 20));
      final r = s.recurringExpenses['old']!;
      expect(r.cadence, RecurringCadence.monthly);
      expect(r.isAnnual, isFalse);
      // Monthly: full amount every month, no reserve.
      expect(s.recurringChargeFor(u1, const Month(2026, 1)), 1500);
      expect(r.reserveCents, 0);
      expect(r.lastReconciliation, isNull);
    });
  });

  group('emergency funds', () {
    test('emergency contribution accrues even in an overspent month', () {
      final events = [
        EmergencyFundSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          fundId: 'f',
          name: 'Vet',
        ),
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 10000,
          emergency:
              const EmergencyContribution(fundId: 'f', amountCents: 2000),
        ),
        // Overspend the effective limit (8000) heavily.
        buy(id: 'p', target: const SliceCharge('s'), amount: 15000,
            at: day(2026, 1, 10)),
      ];
      // Read within January so only one month's contribution has accrued.
      final s = reduce(events, asOf: day(2026, 1, 20));
      expect(s.emergencyFunds['f']!.balanceCents, 2000);
      final sm = s.sliceMonth('s', const Month(2026, 1))!;
      expect(sm.effectiveLimitCents, 8000);
      expect(sm.overspent, isTrue);
    });

    test('ransack: emergency purchase over the fund balance raids the chest', () {
      final events = [
        EmergencyFundSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          fundId: 'f',
          name: 'Vet',
        ),
        // War chest filled directly by a tax refund.
        TaxRefundRecorded(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 2),
          createdAt: day(2026, 1, 2),
          amountCents: 30000,
        ),
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 5000,
          emergency:
              const EmergencyContribution(fundId: 'f', amountCents: 1000),
        ),
        buy(id: 'em', target: const EmergencyCharge('f'), amount: 5000,
            by: u1, note: 'surgery', at: day(2026, 1, 15)),
      ];
      // Read within January: one month's contribution (1000) accrued.
      final s = reduce(events, asOf: day(2026, 1, 20));
      // Fund had 1000 (one month's contribution); purchase 5000 -> excess 4000.
      expect(s.emergencyFunds['f']!.balanceCents, 0);
      expect(s.ransacks, hasLength(1));
      expect(s.ransacks.single.excessCents, 4000);
      expect(s.ransacks.single.fundId, 'f');
      expect(s.ransacks.single.purpose, 'surgery');
      // Chest was 30000 group leftover, minus 4000 ransack.
      expect(s.warChest.balanceCents, 26000);
    });

    test('contribution does not accrue for months that have not started', () {
      final events = [
        EmergencyFundSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          fundId: 'f',
          name: 'Vet',
        ),
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 10000,
          emergency:
              const EmergencyContribution(fundId: 'f', amountCents: 2000),
        ),
        // A recurring expense whose endMonth is far in the future drags the
        // reducer's month sweep out to December, but that must not conjure
        // emergency contributions for months that have not begun yet.
        RecurringExpenseSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          expenseId: 'rent',
          name: 'Rent',
          ownership: const SharedParty(),
          kind: RecurringKind.fixed,
          amountCents: 120000,
          startMonth: const Month(2026, 1),
          endMonth: const Month(2026, 12),
        ),
      ];
      // Read inside January: only January's start instant is <= asOf, so only
      // one month's contribution should have accrued (not all twelve).
      final s = reduce(events, asOf: day(2026, 1, 20));
      expect(s.emergencyFunds['f']!.balanceCents, 2000);
    });

    test('fund balance is unaffected by a future recurring endMonth', () {
      EmergencyFundSet fund() => EmergencyFundSet(
            eventId: _seq.id(),
            deviceId: 'd',
            userId: u1,
            occurredAt: day(2026, 1, 1),
            createdAt: day(2026, 1, 1),
            fundId: 'f',
            name: 'Vet',
          );
      BudgetSliceSet contributingSlice() => slice(
            id: 's',
            ownership: const PersonalSlice(u1),
            limit: 10000,
            emergency:
                const EmergencyContribution(fundId: 'f', amountCents: 2000),
          );

      // Identical inputs except one household also carries a recurring expense
      // that runs months into the future.
      final withoutRecurring = reduce(
        [fund(), contributingSlice()],
        asOf: day(2026, 1, 20),
      );
      final withFutureRecurring = reduce(
        [
          fund(),
          contributingSlice(),
          RecurringExpenseSet(
            eventId: _seq.id(),
            deviceId: 'd',
            userId: u1,
            occurredAt: day(2026, 1, 1),
            createdAt: day(2026, 1, 1),
            expenseId: 'rent',
            name: 'Rent',
            ownership: const SharedParty(),
            kind: RecurringKind.fixed,
            amountCents: 120000,
            startMonth: const Month(2026, 1),
            endMonth: const Month(2026, 12),
          ),
        ],
        asOf: day(2026, 1, 20),
      );

      expect(
        withFutureRecurring.emergencyFunds['f']!.balanceCents,
        withoutRecurring.emergencyFunds['f']!.balanceCents,
      );
      expect(withoutRecurring.emergencyFunds['f']!.balanceCents, 2000);
    });

    test('current started month still accrues off the top at month start', () {
      final events = [
        EmergencyFundSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          fundId: 'f',
          name: 'Vet',
        ),
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 10000,
          emergency:
              const EmergencyContribution(fundId: 'f', amountCents: 2000),
        ),
      ];
      // Read on January 2nd, before any spending: the contribution is present
      // from the month's start, not gated on month close.
      final s = reduce(events, asOf: day(2026, 1, 2));
      expect(s.emergencyFunds['f']!.balanceCents, 2000);
    });

    test(
        'future-dated emergency purchase is still processed as a recorded fact',
        () {
      // Documents the chosen behavior: the future-gate applies ONLY to the
      // automatic contribution schedule. A purchase is an explicitly recorded
      // event, so a future-dated emergency purchase still processes at read
      // time and surfaces a ransack now rather than being silently deferred.
      final events = [
        EmergencyFundSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          fundId: 'f',
          name: 'Vet',
        ),
        TaxRefundRecorded(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 2),
          createdAt: day(2026, 1, 2),
          amountCents: 30000,
        ),
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 5000,
          emergency:
              const EmergencyContribution(fundId: 'f', amountCents: 1000),
        ),
        // Purchase dated two months out, read in January.
        buy(id: 'em', target: const EmergencyCharge('f'), amount: 5000,
            by: u1, note: 'surgery', at: day(2026, 3, 15)),
      ];
      final s = reduce(events, asOf: day(2026, 1, 20));
      // Only January's 1000 contribution has accrued (Feb/Mar are future-
      // gated); the future purchase still fires, ransacking excess 4000.
      expect(s.emergencyFunds['f']!.balanceCents, 0);
      expect(s.ransacks, hasLength(1));
      expect(s.ransacks.single.excessCents, 4000);
      expect(s.warChest.balanceCents, 26000);
    });
  });

  group('shared purchases restore both users on void', () {
    test('voiding a shared personal-slice purchase restores slice and vault', () {
      List<Event> base({bool voided = false}) => [
            slice(id: 's', ownership: const PersonalSlice(u1), limit: 100000),
            slice(id: 'x', ownership: const PersonalSlice(u2), limit: 100000),
            buy(id: 'p', target: const SliceCharge('s'), amount: 4001,
                by: u1, shared: true, at: day(2026, 1, 10)),
            if (voided)
              PurchaseVoided(
                eventId: _seq.id(),
                deviceId: 'd',
                userId: u1,
                occurredAt: day(2026, 1, 11),
                createdAt: day(2026, 1, 11),
                purchaseId: 'p',
              ),
          ];

      final live = reduce(base(),
          asOf: const Month(2026, 1).endInstantUtc().add(const Duration(days: 1)));
      // Shared 4001: purchaser (u1) share 2001 to the slice; u2 share 2000
      // charged to u2's vault (which clamps at 0 and flags inconsistency).
      expect(live.sliceMonth('s', const Month(2026, 1))!.spentCents, 2001);
      expect(live.isVaultInconsistent(u2), isTrue);

      final voided = reduce(base(voided: true),
          asOf: const Month(2026, 1).endInstantUtc().add(const Duration(days: 1)));
      expect(voided.sliceMonth('s', const Month(2026, 1))!.spentCents, 0);
      expect(voided.isVaultInconsistent(u2), isFalse);
      expect(voided.vaultOf(u2), 0);
    });
  });

  group('membership & shares', () {
    test('legacy PetSet reduces as a pet member', () {
      final s = reduce([
        PetSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          petId: 'pet',
          name: 'Mochi',
        ),
      ], asOf: day(2026, 1, 20));
      expect(s.members['pet']!.role, MemberRole.pet);
      expect(s.members['pet']!.name, 'Mochi');
      expect(s.pets['pet']!.name, 'Mochi');
      // A pet carries no ledger: it is neither an adult nor a known user.
      expect(s.adultIds.contains('pet'), isFalse);
      expect(s.userIds.contains('pet'), isFalse);
    });

    test('adults are ledger-bearing; dependents and pets are not', () {
      final s = reduce([
        member(id: u1, role: MemberRole.adult),
        member(id: 'kid', role: MemberRole.dependent),
        member(id: 'pet', role: MemberRole.pet),
      ], asOf: day(2026, 1, 20));
      expect(s.members.keys, containsAll(<String>[u1, 'kid', 'pet']));
      expect(s.adultIds, {u1});
      expect(s.userIds, contains(u1));
      expect(s.userIds, isNot(contains('kid')));
      expect(s.userIds, isNot(contains('pet')));
    });

    test('shared personal purchase splits evenly across three adults', () {
      final s = reduce([
        member(id: 'a', role: MemberRole.adult),
        member(id: 'b', role: MemberRole.adult),
        member(id: 'c', role: MemberRole.adult),
        slice(id: 's', ownership: const PersonalSlice('a'), limit: 100000),
        // Seed vaults so co-adults' shares don't merely clamp at zero.
        GiftReceived(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          forUserId: 'b',
          amountCents: 1000,
        ),
        GiftReceived(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          forUserId: 'c',
          amountCents: 1000,
        ),
        buy(id: 'p', target: const SliceCharge('s'), amount: 100,
            by: 'a', shared: true, at: day(2026, 1, 10)),
      ], asOf: day(2026, 1, 20));
      // 100 / 3 -> 33 each, odd cent to the purchaser 'a' -> 34.
      expect(s.sliceMonth('s', const Month(2026, 1))!.spentCents, 34);
      expect(s.vaultOf('b'), 1000 - 33);
      expect(s.vaultOf('c'), 1000 - 33);
    });

    test('explicit share table weights a shared purchase; odd cent to buyer', () {
      final s = reduce([
        ...twoAdults(),
        GroupShareSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          month: const Month(2026, 1),
          shares: const {u1: 700, u2: 300},
        ),
        slice(id: 's', ownership: const PersonalSlice(u1), limit: 100000),
        GiftReceived(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          forUserId: u2,
          amountCents: 1000,
        ),
        buy(id: 'p', target: const SliceCharge('s'), amount: 1001,
            by: u1, shared: true, at: day(2026, 1, 10)),
      ], asOf: day(2026, 1, 20));
      // 1001 * 700/1000 = 700, 1001 * 300/1000 = 300, odd cent to buyer -> 701.
      expect(s.sliceMonth('s', const Month(2026, 1))!.spentCents, 701);
      expect(s.vaultOf(u2), 1000 - 300);
    });

    test('shared recurring split follows the share table and carries forward', () {
      final s = reduce([
        ...twoAdults(),
        GroupShareSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          month: const Month(2026, 1),
          shares: const {u1: 750, u2: 250},
        ),
        RecurringExpenseSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          expenseId: 'rent',
          name: 'Rent',
          ownership: const SharedParty(),
          kind: RecurringKind.fixed,
          amountCents: 1000,
          startMonth: const Month(2026, 1),
        ),
      ], asOf: day(2026, 2, 10));
      expect(s.recurringChargeFor(u1, const Month(2026, 1)), 750);
      expect(s.recurringChargeFor(u2, const Month(2026, 1)), 250);
      // February has no table of its own: January's carries forward.
      expect(s.recurringChargeFor(u1, const Month(2026, 2)), 750);
      expect(s.recurringChargeFor(u2, const Month(2026, 2)), 250);
    });

    test('retired adult drops out of the split', () {
      final s = reduce([
        member(id: u1, role: MemberRole.adult),
        member(id: u2, role: MemberRole.adult, active: false),
        slice(id: 's', ownership: const PersonalSlice(u1), limit: 100000),
        buy(id: 'p', target: const SliceCharge('s'), amount: 100,
            by: u1, shared: true, at: day(2026, 1, 10)),
      ], asOf: day(2026, 1, 20));
      // Only u1 is an active adult, so the whole shared cost lands on u1's
      // category; the retired adult is never charged.
      expect(s.sliceMonth('s', const Month(2026, 1))!.spentCents, 100);
      expect(s.isVaultInconsistent(u2), isFalse);
      expect(s.adultIds, {u1});
    });

    test('single-adult household auto-approves a withdrawal', () {
      final s = reduce([
        member(id: u1, role: MemberRole.adult),
        slice(id: 'g', ownership: const GroupSlice(), limit: 20000),
        buy(id: 'p', target: const SliceCharge('g'), amount: 0,
            at: day(2026, 1, 2)),
        PoolWithdrawalProposed(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 10),
          createdAt: day(2026, 1, 10),
          proposalId: 'w',
          byUserId: u1,
          amountCents: 5000,
          purpose: 'tires',
          destination: const UserVaultDestination(u1),
        ),
      ], asOf: graceExpired(const Month(2026, 1)));
      expect(s.withdrawals['w']!.status, WithdrawalStatus.approved);
      expect(s.vaultOf(u1), 5000);
      expect(s.warChest.balanceCents, 15000);
    });

    test('a dependent cannot satisfy a withdrawal; a second adult can', () {
      List<Event> base(String approver) => [
            member(id: u1, role: MemberRole.adult),
            member(id: u2, role: MemberRole.adult),
            member(id: 'kid', role: MemberRole.dependent),
            slice(id: 'g', ownership: const GroupSlice(), limit: 20000),
            buy(id: 'p', target: const SliceCharge('g'), amount: 0,
                at: day(2026, 1, 2)),
            PoolWithdrawalProposed(
              eventId: _seq.id(),
              deviceId: 'd',
              userId: u1,
              occurredAt: day(2026, 1, 10),
              createdAt: day(2026, 1, 10),
              proposalId: 'w',
              byUserId: u1,
              amountCents: 5000,
              purpose: 'tires',
              destination: const UserVaultDestination(u1),
            ),
            PoolWithdrawalApproved(
              eventId: _seq.id(),
              deviceId: 'd',
              userId: approver,
              occurredAt: day(2026, 1, 11),
              createdAt: day(2026, 1, 11),
              proposalId: 'w',
              byUserId: approver,
            ),
          ];
      final byKid =
          reduce(base('kid'), asOf: graceExpired(const Month(2026, 1)));
      expect(byKid.withdrawals['w']!.status, WithdrawalStatus.pending);
      expect(byKid.warChest.balanceCents, 20000);

      final byAdult =
          reduce(base(u2), asOf: graceExpired(const Month(2026, 1)));
      expect(byAdult.withdrawals['w']!.status, WithdrawalStatus.approved);
      expect(byAdult.vaultOf(u1), 5000);
      expect(byAdult.warChest.balanceCents, 15000);
    });
  });

  group('retroactivity and ordering', () {
    test('a retroactive prior-month purchase recomputes downstream spoils', () {
      List<Event> events({bool withRetro = false}) => [
            slice(
              id: 's',
              ownership: const PersonalSlice(u1),
              limit: 10000,
              tithePct: 10,
              policy: const Discretionary(),
            ),
            if (withRetro)
              buy(id: 'retro', target: const SliceCharge('s'), amount: 3000,
                  at: day(2026, 1, 9)),
          ];
      final without = reduce(events(), asOf: graceExpired(const Month(2026, 1)));
      // Leftover 10000 -> 1000 chest, 9000 vault.
      expect(without.vaultOf(u1), 9000);
      expect(without.warChest.balanceCents, 1000);

      final withRetro =
          reduce(events(withRetro: true), asOf: graceExpired(const Month(2026, 1)));
      // Leftover 7000 -> 700 chest, 6300 vault.
      expect(withRetro.vaultOf(u1), 6300);
      expect(withRetro.warChest.balanceCents, 700);
    });

    test('out-of-order events reduce identically to sorted order', () {
      final events = <Event>[
        slice(id: 'g', ownership: const GroupSlice(), limit: 40000),
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 20000,
          tithePct: 15,
          policy: const Discretionary(),
        ),
        buy(id: 'p1', target: const SliceCharge('g'), amount: 10000,
            at: day(2026, 1, 12)),
        buy(id: 'p2', target: const SliceCharge('s'), amount: 5000,
            at: day(2026, 1, 14)),
        GiftReceived(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 15),
          createdAt: day(2026, 1, 15),
          forUserId: u2,
          amountCents: 2500,
        ),
        allocate(
          user: u1,
          sliceId: 's',
          month: const Month(2026, 1),
          allocations: const [
            Allocation(destination: Discretionary(), amountCents: 15000),
          ],
          at: day(2026, 1, 25),
        ),
      ];
      final sortedState = reduce(events, asOf: day(2026, 2, 20));
      final shuffled = events.reversed.toList();
      final shuffledState = reduce(shuffled, asOf: day(2026, 2, 20));
      expect(shuffledState.debugSnapshot(), sortedState.debugSnapshot());
    });

    test('a receipt attaches regardless of its order vs. the purchase', () {
      final add = buy(
        id: 'p',
        target: const SliceCharge('g'),
        amount: 4250,
        at: day(2026, 1, 4),
      );
      final attachAfter = ReceiptAttached(
        eventId: 'zzzz-after-add', // sorts AFTER `add` by eventId
        deviceId: 'd',
        userId: u1,
        occurredAt: day(2026, 1, 4), // same instant as the purchase
        createdAt: day(2026, 1, 4),
        purchaseId: 'p',
        sha256: 'a' * 64,
        mimeType: 'image/jpeg',
        sizeBytes: 10,
      );
      final attachBefore = ReceiptAttached(
        eventId: 'aaaa-before-add', // sorts BEFORE `add` by eventId
        deviceId: 'd',
        userId: u1,
        occurredAt: day(2026, 1, 4),
        createdAt: day(2026, 1, 4),
        purchaseId: 'p',
        sha256: 'b' * 64,
        mimeType: 'image/jpeg',
        sizeBytes: 10,
      );
      final slc = slice(id: 'g', ownership: const GroupSlice(), limit: 40000);

      // Whether the attach sorts before or after the purchase, the receipt must
      // land on the purchase — the reduction is order-independent.
      final withAfter = reduce([slc, add, attachAfter], asOf: day(2026, 2, 20));
      expect(withAfter.purchases['p']!.receipts.length, 1);

      final withBefore = reduce([slc, attachBefore, add], asOf: day(2026, 2, 20));
      expect(withBefore.purchases['p']!.receipts.length, 1,
          reason: 'a receipt attached before its purchase must still bind');
    });

    test('duplicate events are idempotent', () {
      final e = slice(id: 'g', ownership: const GroupSlice(), limit: 40000);
      final p = buy(id: 'p', target: const SliceCharge('g'), amount: 10000,
          at: day(2026, 1, 12));
      final once = reduce([e, p], asOf: graceExpired(const Month(2026, 1)));
      final twice = reduce([e, p, p, e], asOf: graceExpired(const Month(2026, 1)));
      expect(twice.warChest.balanceCents, once.warChest.balanceCents);
      expect(twice.warChest.balanceCents, 30000);
    });
  });

  group('month boundary', () {
    test('a purchase near local midnight is keyed in the correct month', () {
      // 2026-03-01 07:30 UTC == Feb 28 23:30 PST -> February.
      final febEnd = reduce([
        slice(id: 's', ownership: const PersonalSlice(u1), limit: 10000),
        buy(id: 'p', target: const SliceCharge('s'), amount: 4000,
            at: DateTime.utc(2026, 3, 1, 7, 30)),
      ], asOf: day(2026, 3, 20));
      expect(febEnd.sliceMonth('s', const Month(2026, 2))!.spentCents, 4000);
      expect(febEnd.sliceMonth('s', const Month(2026, 3))!.spentCents, 0);

      // One hour later crosses into March.
      final marStart = reduce([
        slice(id: 's', ownership: const PersonalSlice(u1), limit: 10000),
        buy(id: 'p', target: const SliceCharge('s'), amount: 4000,
            at: DateTime.utc(2026, 3, 1, 8, 30)),
      ], asOf: day(2026, 3, 20));
      expect(marStart.sliceMonth('s', const Month(2026, 3))!.spentCents, 4000);
      expect(marStart.sliceMonth('s', const Month(2026, 2))!.spentCents, 0);
    });
  });

  group('net worth', () {
    AccountBalanceRecorded bal(
      String id,
      String name,
      AccountKind kind,
      int cents,
      DateTime at,
    ) =>
        AccountBalanceRecorded(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: at,
          createdAt: at,
          accountId: id,
          accountName: name,
          kind: kind,
          balanceCents: cents,
        );

    TrackedAccountSet acct(
      String id,
      String name,
      AccountKind kind, {
      int? aprBps,
      AccountCadence? accrualCadence,
      AccountCadence? updateCadence,
      int? minPaymentCents,
    }) =>
        TrackedAccountSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          accountId: id,
          name: name,
          kind: kind,
          aprBps: aprBps,
          accrualCadence: accrualCadence,
          updateCadence: updateCadence,
          minPaymentCents: minPaymentCents,
        );

    AccountTransferRecorded transfer(
      String id,
      int cents,
      TransferDirection dir,
      DateTime at,
    ) =>
        AccountTransferRecorded(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: at,
          createdAt: at,
          accountId: id,
          amountCents: cents,
          direction: dir,
        );

    test('signed total from the latest balance per account', () {
      final s = reduce([
        bal('chequing', 'Chequing', AccountKind.savings, 500000, day(2026, 1, 1)),
        // Supersedes the earlier value.
        bal('chequing', 'Chequing', AccountKind.savings, 450000, day(2026, 1, 2)),
        bal('card', 'Visa', AccountKind.debt, 120000, day(2026, 1, 3)),
      ], asOf: day(2026, 1, 20));
      expect(s.netWorth.totalCents, 450000 - 120000);
      expect(s.netWorth.assetsCents, 450000);
      expect(s.netWorth.debtsCents, 120000);
    });

    test('savings value = last balance + interest accrued since', () {
      final s = reduce([
        acct('sv', 'Savings', AccountKind.savings,
            aprBps: 1200, accrualCadence: AccountCadence.monthly),
        bal('sv', 'Savings', AccountKind.savings, 1000000, day(2026, 1, 1)),
      ], asOf: day(2026, 4, 1)); // 90 days == 3 monthly periods == quarter-year
      final a = s.netWorth.accounts['sv']!;
      expect(a.balanceCents, 1000000);
      expect(a.accruedInterestCents, 30000); // 1,000,000 * 12% * 0.25
      expect(a.currentValueCents, 1030000);
      expect(s.netWorth.totalCents, 1030000);
    });

    test('no interest before a full accrual period elapses', () {
      final s = reduce([
        acct('sv', 'Savings', AccountKind.savings,
            aprBps: 1200, accrualCadence: AccountCadence.monthly),
        bal('sv', 'Savings', AccountKind.savings, 1000000, day(2026, 1, 1)),
      ], asOf: day(2026, 1, 20)); // 19 days < one monthly period
      expect(s.netWorth.accounts['sv']!.accruedInterestCents, 0);
      expect(s.netWorth.accounts['sv']!.currentValueCents, 1000000);
    });

    test('debt accrues interest and counts negatively', () {
      final s = reduce([
        acct('card', 'Visa', AccountKind.debt,
            aprBps: 2400, accrualCadence: AccountCadence.monthly),
        bal('card', 'Visa', AccountKind.debt, 100000, day(2026, 1, 1)),
      ], asOf: day(2026, 2, 1)); // 31 days == 1 monthly period
      final a = s.netWorth.accounts['card']!;
      expect(a.accruedInterestCents, 2000); // 100,000 * 24% / 12
      expect(a.currentValueCents, 102000);
      expect(a.signedCents, -102000);
      expect(s.netWorth.totalCents, -102000);
    });

    test('investment is never auto-changed but goes stale past its cadence', () {
      final events = [
        acct('inv', 'Brokerage', AccountKind.investment,
            aprBps: 5000, // ignored: investments never accrue
            accrualCadence: AccountCadence.monthly,
            updateCadence: AccountCadence.monthly),
        bal('inv', 'Brokerage', AccountKind.investment, 800000, day(2026, 1, 1)),
      ];
      final fresh = reduce(events, asOf: day(2026, 1, 15)); // 14 days
      expect(fresh.netWorth.accounts['inv']!.stale, isFalse);
      expect(fresh.netWorth.accounts['inv']!.currentValueCents, 800000);
      expect(fresh.netWorth.staleAccounts, isEmpty);

      final stale = reduce(events, asOf: day(2026, 3, 1)); // 59 days > 30
      expect(stale.netWorth.accounts['inv']!.stale, isTrue);
      expect(stale.netWorth.accounts['inv']!.currentValueCents, 800000);
      expect(stale.netWorth.staleAccounts.single.accountId, 'inv');
    });

    test('transfers after the last recording adjust the balance', () {
      final s = reduce([
        bal('sv', 'Savings', AccountKind.savings, 100000, day(2026, 1, 10)),
        transfer('sv', 50000, TransferDirection.deposit, day(2026, 1, 12)),
        transfer('sv', 20000, TransferDirection.withdrawal, day(2026, 1, 15)),
        // A transfer before the last recording is already baked in — ignored.
        transfer('sv', 99999, TransferDirection.deposit, day(2026, 1, 5)),
      ], asOf: day(2026, 1, 20));
      expect(s.netWorth.accounts['sv']!.currentValueCents, 130000);
    });

    test('TrackedAccountSet config wins over a legacy balance name/kind', () {
      final s = reduce([
        bal('card', 'old name', AccountKind.savings, 120000, day(2026, 1, 1)),
        acct('card', 'Visa', AccountKind.debt),
      ], asOf: day(2026, 1, 20));
      final a = s.netWorth.accounts['card']!;
      expect(a.name, 'Visa');
      expect(a.kind, AccountKind.debt);
      expect(a.signedCents, -120000);
    });

    test('a declared account with no balance yet surfaces at zero', () {
      final s = reduce([
        acct('inv', 'Brokerage', AccountKind.investment,
            updateCadence: AccountCadence.monthly),
      ], asOf: day(2026, 6, 1));
      final a = s.netWorth.accounts['inv']!;
      expect(a.currentValueCents, 0);
      expect(a.stale, isFalse); // no recording ⇒ nothing to be stale about
    });

    test('debt minimum payments surface as recurring expenses', () {
      final s = reduce([
        slice(id: 's', ownership: const PersonalSlice(u1), limit: 100000),
        acct('card', 'Visa', AccountKind.debt, minPaymentCents: 25000),
      ], asOf: day(2026, 1, 20));
      final rec = s.recurringExpenses['debt:card'];
      expect(rec, isNotNull);
      expect(rec!.amountCents, 25000);
      expect(rec.isShared, isTrue);
      expect(s.recurringChargeFor(u1, const Month(2026, 1)), 25000);
    });

    test('tracked accounts never enter category math', () {
      final budget = [
        slice(id: 's', ownership: const PersonalSlice(u1), limit: 100000),
        buy(id: 'p', target: const SliceCharge('s'), amount: 40000,
            at: day(2026, 1, 10)),
      ];
      final without = reduce(budget, asOf: day(2026, 1, 20));
      final with_ = reduce([
        ...budget,
        acct('sv', 'Savings', AccountKind.savings,
            aprBps: 1200, accrualCadence: AccountCadence.monthly),
        bal('sv', 'Savings', AccountKind.savings, 999999, day(2026, 1, 1)),
        transfer('sv', 12345, TransferDirection.deposit, day(2026, 1, 5)),
      ], asOf: day(2026, 1, 20));

      // Category math and the pool are untouched by the account.
      expect(with_.sliceMonth('s', const Month(2026, 1))!.spentCents,
          without.sliceMonth('s', const Month(2026, 1))!.spentCents);
      expect(with_.sliceMonth('s', const Month(2026, 1))!.leftoverCents,
          without.sliceMonth('s', const Month(2026, 1))!.leftoverCents);
      expect(with_.warChest.balanceCents, without.warChest.balanceCents);
      expect(with_.vaultOf(u1), without.vaultOf(u1));
      expect(with_.recurringChargeFor(u1, const Month(2026, 1)), 0);
      // Only net worth reflects it.
      expect(without.netWorth.accounts, isEmpty);
      expect(with_.netWorth.accounts.containsKey('sv'), isTrue);
    });
  });

  group('tax deductible list', () {
    test('effective flag is override ?? slice default, grouped by year', () {
      final s = reduce([
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 100000,
          taxDefault: true,
        ),
        // Inherits the slice default (deductible).
        buy(id: 'p1', target: const SliceCharge('s'), amount: 3000,
            merchant: 'Depot', at: day(2026, 3, 10)),
        // Explicit override to non-deductible.
        buy(id: 'p2', target: const SliceCharge('s'), amount: 4000,
            tax: false, at: day(2026, 3, 12)),
        // Different tax year.
        buy(id: 'p3', target: const SliceCharge('s'), amount: 5000,
            at: day(2025, 12, 20)),
      ], asOf: day(2026, 4, 1));
      final y2026 = s.deductibleByYear[2026] ?? [];
      expect(y2026.map((d) => d.purchaseId), contains('p1'));
      expect(y2026.map((d) => d.purchaseId), isNot(contains('p2')));
      expect(y2026.single.merchant, 'Depot');
      final y2025 = s.deductibleByYear[2025] ?? [];
      expect(y2025.map((d) => d.purchaseId), contains('p3'));
    });
  });

  group('main categories', () {
    test('the eight documented defaults are always seeded', () {
      final s = reduce(const []);
      expect(
        s.mainCategories.keys.toSet(),
        {'housing', 'food', 'transport', 'health', 'entertainment', 'pets',
          'savings', 'misc'},
      );
      expect(s.mainCategories['food']!.name, 'Food');
      expect(s.mainCategories['misc']!.sortOrder, 7);
    });

    test('MainCategorySet overrides a default and adds new ones', () {
      final s = reduce([
        MainCategorySet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          id: 'food',
          name: 'Groceries & Dining',
          colorArgb: 0xFF112233,
          sortOrder: 1,
        ),
        MainCategorySet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          id: 'travel',
          name: 'Travel',
          colorArgb: 0xFF445566,
          sortOrder: 9,
        ),
      ]);
      expect(s.mainCategories['food']!.name, 'Groceries & Dining');
      expect(s.mainCategories['food']!.colorArgb, 0xFF112233);
      expect(s.mainCategories['travel']!.name, 'Travel');
      // Untouched defaults remain.
      expect(s.mainCategories['housing']!.name, 'Housing');
    });

    test('a category carries its mainCategoryId onto the read-model', () {
      final s = reduce([
        slice(
          id: 's',
          ownership: const PersonalSlice(u1),
          limit: 10000,
          mainCategoryId: 'food',
        ),
      ], asOf: day(2026, 2, 1));
      expect(s.slices['s']!.mainCategoryId, 'food');
    });
  });

  group('income', () {
    DefaultIncomeSet defaultIncome(String user, int amount, Month from) =>
        DefaultIncomeSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: user,
          occurredAt: from.startInstantUtc(),
          createdAt: from.startInstantUtc(),
          forUserId: user,
          amountCents: amount,
          effectiveFromMonth: from,
        );

    IncomeSet override(String user, int amount, Month month) => IncomeSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: user,
          occurredAt: month.startInstantUtc(),
          createdAt: month.startInstantUtc(),
          forUserId: user,
          amountCents: amount,
          month: month,
        );

    test('a variable earner plans at the low end of an estimated range', () {
      final withRange = DefaultIncomeSet(
        eventId: _seq.id(),
        deviceId: 'd',
        userId: u1,
        occurredAt: const Month(2026, 1).startInstantUtc(),
        createdAt: const Month(2026, 1).startInstantUtc(),
        forUserId: u1,
        amountCents: 300000,
        estimatedHighCents: 450000,
        effectiveFromMonth: const Month(2026, 1),
      );
      final s = reduce([withRange], asOf: day(2026, 2, 10));
      // Everything budget-side plans on the conservative low figure.
      expect(s.incomeFor(u1, const Month(2026, 2)), 300000);
      // The range surfaces for display ("$3,000 to $4,500, planning low").
      final d = s.effectiveIncomeDefault(u1, const Month(2026, 2))!;
      expect(d.amountCents, 300000);
      expect(d.estimatedHighCents, 450000);
      // The range survives the wire.
      final back = Event.fromJson(withRange.toJson()) as DefaultIncomeSet;
      expect(back.estimatedHighCents, 450000);
      // A month that actually paid more is a plain override.
      final s2 = reduce([
        withRange,
        override(u1, 420000, const Month(2026, 2)),
      ], asOf: day(2026, 3, 10));
      expect(s2.incomeFor(u1, const Month(2026, 2)), 420000);
      expect(s2.incomeFor(u1, const Month(2026, 3)), 300000);
    });

    test('a default carries forward to later months with no override', () {
      final s = reduce([
        defaultIncome(u1, 400000, const Month(2026, 1)),
      ], asOf: day(2026, 6, 15));
      expect(s.incomeFor(u1, const Month(2026, 1)), 400000);
      expect(s.incomeFor(u1, const Month(2026, 5)), 400000);
      // Before the default takes effect, income is zero.
      expect(s.incomeFor(u1, const Month(2025, 12)), 0);
    });

    test('the latest effective default wins', () {
      final s = reduce([
        defaultIncome(u1, 400000, const Month(2026, 1)),
        defaultIncome(u1, 450000, const Month(2026, 4)),
      ], asOf: day(2026, 6, 15));
      expect(s.incomeFor(u1, const Month(2026, 3)), 400000);
      expect(s.incomeFor(u1, const Month(2026, 4)), 450000);
      expect(s.incomeFor(u1, const Month(2026, 5)), 450000);
    });

    test('an override beats the default for that month only', () {
      final s = reduce([
        defaultIncome(u1, 400000, const Month(2026, 1)),
        override(u1, 300000, const Month(2026, 3)),
      ], asOf: day(2026, 6, 15));
      expect(s.incomeFor(u1, const Month(2026, 2)), 400000);
      expect(s.incomeFor(u1, const Month(2026, 3)), 300000);
      expect(s.incomeFor(u1, const Month(2026, 4)), 400000);
      expect(s.hasIncomeOverride(u1, const Month(2026, 3)), isTrue);
      expect(s.hasIncomeOverride(u1, const Month(2026, 2)), isFalse);
    });

    test('with no default and no override, income is zero', () {
      final s = reduce([
        override(u1, 300000, const Month(2026, 3)),
      ], asOf: day(2026, 6, 15));
      expect(s.incomeFor(u1, const Month(2026, 2)), 0);
      expect(s.incomeFor(u1, const Month(2026, 3)), 300000);
    });

    test('defaultIncomeFor resolves the carried-forward default', () {
      final s = reduce([
        defaultIncome(u1, 400000, const Month(2026, 1)),
        defaultIncome(u1, 450000, const Month(2026, 4)),
      ], asOf: day(2026, 6, 15));
      expect(s.defaultIncomeFor(u1, const Month(2026, 3)), 400000);
      expect(s.defaultIncomeFor(u1, const Month(2026, 4)), 450000);
      expect(s.defaultIncomeFor(u1, const Month(2025, 12)), isNull);
    });

    test('redefining a default for the same month is last-writer-wins', () {
      final s = reduce([
        defaultIncome(u1, 400000, const Month(2026, 1)),
        defaultIncome(u1, 420000, const Month(2026, 1)),
      ], asOf: day(2026, 6, 15));
      expect(s.incomeFor(u1, const Month(2026, 2)), 420000);
    });
  });
}
