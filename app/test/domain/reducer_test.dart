import 'package:duobudget/domain/event.dart';
import 'package:duobudget/domain/reducer.dart';
import 'package:duobudget/domain/state.dart';
import 'package:duobudget/domain/time.dart';
import 'package:duobudget/domain/value_types.dart';
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
    test('signed total from the latest balance per account', () {
      final s = reduce([
        AccountBalanceRecorded(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          accountId: 'chequing',
          accountName: 'Chequing',
          kind: AccountKind.cash,
          balanceCents: 500000,
        ),
        AccountBalanceRecorded(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 2),
          createdAt: day(2026, 1, 2),
          accountId: 'chequing',
          accountName: 'Chequing',
          kind: AccountKind.cash,
          balanceCents: 450000, // supersedes the earlier value
        ),
        AccountBalanceRecorded(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 3),
          createdAt: day(2026, 1, 3),
          accountId: 'card',
          accountName: 'Visa',
          kind: AccountKind.debt,
          balanceCents: 120000,
        ),
      ], asOf: day(2026, 1, 20));
      expect(s.netWorth.totalCents, 450000 - 120000);
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
}
