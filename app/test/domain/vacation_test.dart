import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

const u1 = 'u1';
const u2 = 'u2';

class Seq {
  int _n = 0;
  String id() => 'v${(_n++).toString().padLeft(4, '0')}';
}

final _seq = Seq();

DateTime day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

MemberSet member(String id) => MemberSet(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: day(2026, 1, 1),
      createdAt: day(2026, 1, 1),
      memberId: id,
      name: id,
      role: MemberRole.adult,
    );

/// A slice that contributes a fixed emergency amount off the top each active
/// month. Created in the trip month so exactly one month accrues before the
/// reads below — a terse way to seed a known emergency fund balance.
BudgetSliceSet fundingSlice({
  required String fundId,
  required int contribution,
  int limit = 100000,
  DateTime? at,
}) =>
    BudgetSliceSet(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: at ?? day(2026, 6, 1),
      createdAt: at ?? day(2026, 6, 1),
      sliceId: 'funder_$fundId',
      name: 'funder',
      ownership: const GroupSlice(),
      limitCents: limit,
      poolTithePct: 0,
      defaultLeftoverPolicy: const Discretionary(),
      taxDeductibleByDefault: false,
      emergencyContribution:
          EmergencyContribution(fundId: fundId, amountCents: contribution),
    );

EmergencyFundSet fund(String id, String name) => EmergencyFundSet(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: day(2026, 1, 1),
      createdAt: day(2026, 1, 1),
      fundId: id,
      name: name,
    );

VacationSet vacation({
  required String id,
  String name = 'Trip',
  required VacationFund source,
  required DateTime start,
  required DateTime end,
  required List<VacationCategory> categories,
  DateTime? at,
}) =>
    VacationSet(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: at ?? day(2026, 6, 1),
      createdAt: at ?? day(2026, 6, 1),
      vacationId: id,
      name: name,
      fund: source,
      startDate: start,
      endDate: end,
      categories: categories,
    );

VacationClosed close(String id, {DateTime? at}) => VacationClosed(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: u1,
      occurredAt: at ?? day(2026, 7, 1),
      createdAt: at ?? day(2026, 7, 1),
      vacationId: id,
    );

PurchaseAdded buyVacation({
  required String id,
  required String vacationId,
  required String categoryId,
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
      target: VacationCharge(vacationId, categoryId),
      amountCents: amount,
    );

void main() {
  group('vacation tracking', () {
    test('per-category and total spend accumulate from vacation charges', () {
      final events = [
        member(u1),
        fund('f', 'Travel fund'),
        fundingSlice(fundId: 'f', contribution: 200000),
        vacation(
          id: 'v',
          source: const VacationFundEmergency('f'),
          start: day(2026, 6, 10),
          end: day(2026, 6, 17),
          categories: const [
            VacationCategory(categoryId: 'food', name: 'Food', limitCents: 40000),
            VacationCategory(
                categoryId: 'stay', name: 'Lodging', limitCents: 80000),
          ],
        ),
        buyVacation(
            id: 'p1',
            vacationId: 'v',
            categoryId: 'food',
            amount: 12000,
            at: day(2026, 6, 11)),
        buyVacation(
            id: 'p2',
            vacationId: 'v',
            categoryId: 'food',
            amount: 3000,
            at: day(2026, 6, 12)),
        buyVacation(
            id: 'p3',
            vacationId: 'v',
            categoryId: 'stay',
            amount: 80000,
            at: day(2026, 6, 10)),
      ];
      final s = reduce(events, asOf: day(2026, 6, 13));
      final v = s.vacations['v']!;
      expect(v.isOpen, isTrue);
      expect(v.totalLimitCents, 120000);
      expect(v.totalSpentCents, 95000);
      final food = v.categories.firstWhere((c) => c.categoryId == 'food');
      final stay = v.categories.firstWhere((c) => c.categoryId == 'stay');
      expect(food.spentCents, 15000);
      expect(food.leftoverCents, 25000);
      expect(food.overspent, isFalse);
      expect(stay.spentCents, 80000);
      expect(stay.leftoverCents, 0);
    });

    test('a category overspend is surfaced without touching other budgets', () {
      final events = [
        member(u1),
        fund('f', 'Travel fund'),
        fundingSlice(fundId: 'f', contribution: 200000),
        vacation(
          id: 'v',
          source: const VacationFundEmergency('f'),
          start: day(2026, 6, 10),
          end: day(2026, 6, 12),
          categories: const [
            VacationCategory(categoryId: 'food', name: 'Food', limitCents: 5000),
          ],
        ),
        buyVacation(
            id: 'p1',
            vacationId: 'v',
            categoryId: 'food',
            amount: 8000,
            at: day(2026, 6, 11)),
      ];
      final s = reduce(events, asOf: day(2026, 6, 11));
      final v = s.vacations['v']!;
      expect(v.overspent, isTrue);
      expect(v.totalOverspendCents, 3000);
      // The overspend is confined to the vacation: no vault or war-chest hit.
      expect(s.vaultOf(u1), 0);
      expect(s.warChest.balanceCents, 0);
    });
  });

  group('emergency-fund-backed vacation reservation', () {
    List<Event> base() => [
          member(u1),
          fund('f', 'Travel fund'),
          // A single accrued month contributes 200000 to the fund.
          fundingSlice(fundId: 'f', contribution: 200000),
        ];

    test('an open vacation reserves its full budget off the fund', () {
      final events = [
        ...base(),
        vacation(
          id: 'v',
          source: const VacationFundEmergency('f'),
          start: day(2026, 6, 10),
          end: day(2026, 6, 17),
          categories: const [
            VacationCategory(categoryId: 'a', name: 'A', limitCents: 30000),
            VacationCategory(categoryId: 'b', name: 'B', limitCents: 20000),
          ],
        ),
        buyVacation(
            id: 'p1',
            vacationId: 'v',
            categoryId: 'a',
            amount: 12000,
            at: day(2026, 6, 11)),
      ];
      // June has accrued one contribution (fund = 200000) by the read instant.
      final s = reduce(events, asOf: day(2026, 6, 15));
      final v = s.vacations['v']!;
      expect(v.reservedFromFundCents, 50000); // full budget while open
      // Fund shows 200000 − 50000 reserved.
      expect(s.emergencyFunds['f']!.balanceCents, 150000);
      expect(v.fundBalanceCents, 150000);
    });

    test('closing returns the leftover to the source fund', () {
      final open = [
        ...base(),
        vacation(
          id: 'v',
          source: const VacationFundEmergency('f'),
          start: day(2026, 6, 10),
          end: day(2026, 6, 17),
          categories: const [
            VacationCategory(categoryId: 'a', name: 'A', limitCents: 30000),
            VacationCategory(categoryId: 'b', name: 'B', limitCents: 20000),
          ],
        ),
        buyVacation(
            id: 'p1',
            vacationId: 'v',
            categoryId: 'a',
            amount: 12000,
            at: day(2026, 6, 11)),
      ];
      final closed = [...open, close('v', at: day(2026, 6, 18))];
      final s = reduce(closed, asOf: day(2026, 6, 20));
      final v = s.vacations['v']!;
      expect(v.isOpen, isFalse);
      // Only the 12000 actually spent leaves the fund; the 38000 leftover
      // returns. Fund = 200000 − 12000.
      expect(v.reservedFromFundCents, 12000);
      expect(s.emergencyFunds['f']!.balanceCents, 188000);
    });
  });

  group('quest-backed vacation reservation', () {
    test('an open vacation draws its budget down the backing quest', () {
      // Fund a quest via a matching-category leftover allocation.
      final events = <Event>[
        member(u1),
        BudgetSliceSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          sliceId: 's',
          name: 'Savings slice',
          ownership: const PersonalSlice(u1),
          mainCategoryId: 'savings',
          limitCents: 100000,
          poolTithePct: 0,
          defaultLeftoverPolicy: const Discretionary(),
          taxDeductibleByDefault: false,
        ),
        QuestSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 1),
          createdAt: day(2026, 1, 1),
          questId: 'q',
          name: 'Trip fund',
          targetCents: 200000,
          ownership: const PersonalParty(u1),
          mainCategoryId: 'savings',
        ),
        // Whole limit becomes leftover and attacks the quest (matching main
        // category ⇒ untithed): quest funded 100000.
        LeftoverAllocated(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: u1,
          occurredAt: day(2026, 1, 20),
          createdAt: day(2026, 1, 20),
          forUserId: u1,
          month: const Month(2026, 1),
          sliceId: 's',
          allocations: const [
            Allocation(destination: QuestDestination('q'), amountCents: 100000),
          ],
        ),
        vacation(
          id: 'v',
          source: const VacationFundQuest('q'),
          start: day(2026, 3, 10),
          end: day(2026, 3, 13),
          categories: const [
            VacationCategory(categoryId: 'a', name: 'A', limitCents: 40000),
          ],
          at: day(2026, 3, 1),
        ),
      ];
      final s = reduce(events, asOf: day(2026, 3, 11));
      expect(s.quests['q']!.balanceCents, 60000); // 100000 − 40000 reserved
      expect(s.vacations['v']!.fundBalanceCents, 60000);
    });
  });

  group('daily allowance', () {
    List<Event> trip({required int limit}) => [
          member(u1),
          fund('f', 'Fund'),
          fundingSlice(fundId: 'f', contribution: 200000),
          vacation(
            id: 'v',
            source: const VacationFundEmergency('f'),
            // A 10-day trip, June 10..19 inclusive.
            start: DateTime.utc(2026, 6, 10),
            end: DateTime.utc(2026, 6, 19),
            categories: [
              VacationCategory(categoryId: 'a', name: 'A', limitCents: limit),
            ],
            at: day(2026, 6, 1),
          ),
        ];

    test('before the trip, the full budget spreads across all days', () {
      final s = reduce(trip(limit: 100000), asOf: day(2026, 6, 5));
      final v = s.vacations['v']!;
      expect(v.daysTotal, 10);
      expect(v.daysRemaining, 10);
      expect(v.dailyAllowanceRemainingCents, 10000);
      expect(v.dailyAllowanceBaselineCents, 10000);
    });

    test('mid-trip, remaining budget spreads across the days left', () {
      // On June 14 (inclusive), 6 days remain (14..19). Spent 40000 so far.
      final events = [
        ...trip(limit: 100000),
        buyVacation(
            id: 'p1',
            vacationId: 'v',
            categoryId: 'a',
            amount: 40000,
            at: day(2026, 6, 11)),
      ];
      final s = reduce(events, asOf: day(2026, 6, 14));
      final v = s.vacations['v']!;
      expect(v.daysRemaining, 6);
      expect(v.totalLeftoverCents, 60000);
      expect(v.dailyAllowanceRemainingCents, 10000);
    });

    test('after the trip, no days remain and the allowance is zero', () {
      final s = reduce(trip(limit: 100000), asOf: day(2026, 6, 25));
      final v = s.vacations['v']!;
      expect(v.daysRemaining, 0);
      expect(v.dailyAllowanceRemainingCents, 0);
    });
  });

  group('open-vacation surfacing', () {
    test('openVacations lists only the open trips, sorted by name', () {
      final events = [
        member(u1),
        fund('f', 'Fund'),
        fundingSlice(fundId: 'f', contribution: 500000),
        vacation(
          id: 'v1',
          name: 'Zermatt',
          source: const VacationFundEmergency('f'),
          start: day(2026, 6, 10),
          end: day(2026, 6, 12),
          categories: const [
            VacationCategory(categoryId: 'a', name: 'A', limitCents: 1000),
          ],
        ),
        vacation(
          id: 'v2',
          name: 'Banff',
          source: const VacationFundEmergency('f'),
          start: day(2026, 6, 10),
          end: day(2026, 6, 12),
          categories: const [
            VacationCategory(categoryId: 'a', name: 'A', limitCents: 1000),
          ],
        ),
        close('v1', at: day(2026, 6, 13)),
      ];
      final s = reduce(events, asOf: day(2026, 6, 20));
      expect(s.openVacations.map((v) => v.name), ['Banff']);
    });
  });
}
