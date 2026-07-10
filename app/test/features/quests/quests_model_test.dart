/// Tests that the quest abandon preview matches the reducer to the cent, and
/// that funding history is extracted correctly from the log.
library;

import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/quests/quests_model.dart';
import 'package:flutter_test/flutter_test.dart';

int _n = 0;
String _id() => 'e${(_n++).toString().padLeft(4, '0')}';
DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

void main() {
  test('previewAbandon matches the reducer (tithe + proportional returns)', () {
    const questId = 'q1';
    final events = <Event>[
      // A personal slice per user, funding the shared quest via discretionary…
      // simpler: fund the quest directly through leftover allocations.
      QuestSet(
        eventId: _id(),
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _day(2026, 1, 1),
        createdAt: _day(2026, 1, 1),
        questId: questId,
        name: 'Canoe',
        targetCents: 130000,
        ownership: const SharedParty(),
      ),
      // u1 funds 700, u2 funds 300 (via a slice each). Model both as slices with
      // leftover attacked into the quest.
      BudgetSliceSet(
        eventId: _id(),
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _day(2026, 1, 1),
        createdAt: _day(2026, 1, 1),
        sliceId: 's1',
        name: 'S1',
        ownership: const PersonalSlice('u1'),
        limitCents: 700,
        poolTithePct: 0,
        defaultLeftoverPolicy: Discretionary(),
        taxDeductibleByDefault: false,
      ),
      BudgetSliceSet(
        eventId: _id(),
        deviceId: 'd',
        userId: 'u2',
        occurredAt: _day(2026, 1, 1),
        createdAt: _day(2026, 1, 1),
        sliceId: 's2',
        name: 'S2',
        ownership: const PersonalSlice('u2'),
        limitCents: 300,
        poolTithePct: 0,
        defaultLeftoverPolicy: Discretionary(),
        taxDeductibleByDefault: false,
      ),
      LeftoverAllocated(
        eventId: _id(),
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _day(2026, 2, 2),
        createdAt: _day(2026, 2, 2),
        forUserId: 'u1',
        month: const Month(2026, 1),
        sliceId: 's1',
        allocations: [
          Allocation(destination: QuestDestination(questId), amountCents: 700),
        ],
      ),
      LeftoverAllocated(
        eventId: _id(),
        deviceId: 'd',
        userId: 'u2',
        occurredAt: _day(2026, 2, 2),
        createdAt: _day(2026, 2, 2),
        forUserId: 'u2',
        month: const Month(2026, 1),
        sliceId: 's2',
        allocations: [
          Allocation(destination: QuestDestination(questId), amountCents: 300),
        ],
      ),
    ];

    // Read within February (the open month) so only January is closed and no
    // later month's default policy perturbs the vaults.
    final before = reduce(events, asOf: _day(2026, 2, 6));
    final quest = before.quests[questId]!;
    expect(quest.balanceCents, 1000);

    final preview = previewAbandon(
      quest.balanceCents,
      quest.contributions,
      before.settings.dissolutionTithePct, // default 10%
    );
    // 10% of 1000 = 100 tithe; 900 split 70/30 -> 630 / 270.
    expect(preview.titheCents, 100);
    expect(preview.returnsByUser['u1'], 630);
    expect(preview.returnsByUser['u2'], 270);

    // Now actually abandon and confirm the reducer agrees.
    final afterEvents = [
      ...events,
      QuestAbandoned(
        eventId: _id(),
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _day(2026, 2, 5),
        createdAt: _day(2026, 2, 5),
        questId: questId,
      ),
    ];
    final after = reduce(afterEvents, asOf: _day(2026, 2, 6));
    expect(after.warChest.balanceCents, 100);
    expect(after.vaultOf('u1'), 630);
    expect(after.vaultOf('u2'), 270);
  });

  test('questFundings extracts quest allocations newest-first', () {
    const questId = 'q1';
    final events = <Event>[
      LeftoverAllocated(
        eventId: _id(),
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _day(2026, 2, 2),
        createdAt: _day(2026, 2, 2),
        forUserId: 'u1',
        month: const Month(2026, 1),
        sliceId: 's1',
        allocations: [
          Allocation(destination: QuestDestination(questId), amountCents: 500),
          Allocation(destination: const CarryInSlice(), amountCents: 100),
        ],
      ),
      LeftoverAllocated(
        eventId: _id(),
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _day(2026, 3, 2),
        createdAt: _day(2026, 3, 2),
        forUserId: 'u1',
        month: const Month(2026, 2),
        sliceId: 's1',
        allocations: [
          Allocation(destination: QuestDestination(questId), amountCents: 800),
        ],
      ),
    ];
    final fundings = questFundings(events, questId);
    expect(fundings, hasLength(2));
    expect(fundings.first.amountCents, 800); // newest first
    expect(fundings.last.amountCents, 500);
  });
}
