import 'package:duobudget/domain/event.dart';
import 'package:duobudget/domain/reducer.dart';
import 'package:duobudget/domain/time.dart';
import 'package:duobudget/domain/value_types.dart';
import 'package:duobudget/game/adapter.dart';
import 'package:duobudget/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

// Two adventurers.
const me = 'u1';
const partner = 'u2';

const _names = {me: 'Robin', partner: 'Sam'};

/// Deterministic id/timestamp helper.
class _Seq {
  int _n = 0;
  String id() => 'e${(_n++).toString().padLeft(4, '0')}';
}

final _seq = _Seq();

DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

BudgetSliceSet _slice({
  required String id,
  required SliceOwnership ownership,
  required int limit,
  int tithePct = 0,
  LeftoverDestination policy = const Discretionary(),
  EmergencyContribution? emergency,
  String? emergencyFundId,
  String? petId,
  DateTime? at,
}) =>
    BudgetSliceSet(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: me,
      occurredAt: at ?? _day(2026, 1, 1),
      createdAt: at ?? _day(2026, 1, 1),
      sliceId: id,
      name: id,
      ownership: ownership,
      limitCents: limit,
      poolTithePct: tithePct,
      defaultLeftoverPolicy: policy,
      taxDeductibleByDefault: false,
      emergencyContribution: emergency,
      petId: petId,
    );

PurchaseAdded _buy({
  required String id,
  required ChargeTarget target,
  required int amount,
  String by = me,
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
    );

LeftoverAllocated _allocate({
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

MemberSet _member(String id, MemberRole role) => MemberSet(
      eventId: _seq.id(),
      deviceId: 'd',
      userId: me,
      occurredAt: _day(2026, 1, 1),
      createdAt: _day(2026, 1, 1),
      memberId: id,
      name: _names[id] ?? id,
      role: role,
    );

/// The two-adult household, so "another adult" is a real signature requirement
/// (not the single-adult auto-approval path).
List<Event> _twoAdults() => [
      _member(me, MemberRole.adult),
      _member(partner, MemberRole.adult),
    ];

GameState _game(List<Event> events, {required DateTime asOf}) =>
    buildGameState(
      reduce(events, asOf: asOf),
      meUserId: me,
      userNames: _names,
      asOf: asOf,
    );

void main() {
  group('floor number', () {
    test('counts from the earliest event month (1-based)', () {
      final events = [
        _slice(
          id: 'food',
          ownership: const PersonalSlice(me),
          limit: 40000,
          at: _day(2026, 1, 1),
        ),
      ];
      // January origin, viewed in July -> floor 7.
      final g = _game(events, asOf: _day(2026, 7, 5));
      expect(g.floorNumber, 7);
      expect(g.currentMonth, const Month(2026, 7));
    });

    test('empty household is floor 1', () {
      final g = _game([], asOf: _day(2026, 7, 5));
      expect(g.floorNumber, 1);
    });
  });

  group('monsters (personal slices)', () {
    test('maxHP is effective limit, damage is spend; mine first', () {
      final events = [
        _slice(id: 'food', ownership: const PersonalSlice(me), limit: 40000),
        _slice(id: 'gear', ownership: const PersonalSlice(partner), limit: 30000),
        _buy(id: 'p1', target: const SliceCharge('food'), amount: 25000,
            at: _day(2026, 7, 3)),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      expect(g.monsters, hasLength(2));
      // Mine ('food') sorts before partner's ('gear').
      final food = g.monsters.first;
      expect(food.name, 'food');
      expect(food.mine, isTrue);
      expect(food.maxHpCents, 40000);
      expect(food.damageCents, 25000);
      expect(food.hp.pct, 63); // 25000/40000
      expect(food.enraged, isFalse);
      expect(food.sprite.assetName, Sprites.monster);
      expect(g.monsters.last.mine, isFalse);
    });

    test('overspend enrages the monster and wounds the hero', () {
      final events = [
        _slice(id: 'fun', ownership: const PersonalSlice(me), limit: 20000),
        _buy(id: 'p1', target: const SliceCharge('fun'), amount: 22000,
            at: _day(2026, 7, 3)),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      final fun = g.monsters.single;
      expect(fun.enraged, isTrue);
      expect(fun.excessCents, 2000);
      expect(fun.sprite.assetName, Sprites.monsterEnraged);
      // Excess is dealt to the hero as HP loss.
      expect(g.heroHpLostCents, 2000);
      expect(g.heroWounded, isTrue);
    });
  });

  group('contracts (group slices)', () {
    test('group slice becomes a party contract', () {
      final events = [
        _slice(id: 'groceries', ownership: const GroupSlice(), limit: 60000),
        _buy(id: 'p1', target: const SliceCharge('groceries'), amount: 41000,
            at: _day(2026, 7, 2)),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      expect(g.monsters, isEmpty);
      final c = g.contracts.single;
      expect(c.name, 'groceries');
      expect(c.maxHpCents, 60000);
      expect(c.damageCents, 41000);
      expect(c.enraged, isFalse);
    });
  });

  group('pets (party members)', () {
    test('pet owns its linked monster and reserve cache', () {
      final events = [
        PetSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: me,
          occurredAt: _day(2026, 1, 1),
          createdAt: _day(2026, 1, 1),
          petId: 'mochi',
          name: 'Mochi',
        ),
        EmergencyFundSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: me,
          occurredAt: _day(2026, 1, 1),
          createdAt: _day(2026, 1, 1),
          fundId: 'vet',
          name: 'Vet fund',
          petId: 'mochi',
        ),
        _slice(
          id: 'petfood',
          ownership: const PersonalSlice(me),
          limit: 10000,
          petId: 'mochi',
        ),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      // The pet-linked slice does not appear as a loose monster.
      expect(g.monsters, isEmpty);
      expect(g.reserveCaches, isEmpty);
      final pet = g.party.single;
      expect(pet.name, 'Mochi');
      expect(pet.monsters.single.name, 'petfood');
      expect(pet.reserveCaches.single.name, 'Vet fund');
      expect(pet.sprite.assetName, Sprites.pet);
    });

    test('custom pet sprite is a blob reference', () {
      final events = [
        PetSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: me,
          occurredAt: _day(2026, 1, 1),
          createdAt: _day(2026, 1, 1),
          petId: 'rex',
          name: 'Rex',
          customSpriteSha256: 'abc123',
        ),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      final pet = g.party.single;
      expect(pet.sprite.isCustom, isTrue);
      expect(pet.sprite.customSpriteSha256, 'abc123');
    });
  });

  group('quest monsters', () {
    QuestSet questSet({
      required String id,
      required String name,
      required int target,
      required PartyOwnership ownership,
      String? sprite,
      String? mainCategoryId,
      String? descriptionText,
    }) =>
        QuestSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: me,
          occurredAt: _day(2026, 1, 1),
          createdAt: _day(2026, 1, 1),
          questId: id,
          name: name,
          targetCents: target,
          ownership: ownership,
          mainCategoryId: mainCategoryId,
          customSpriteSha256: sprite,
          descriptionText: descriptionText,
        );

    test('HP=target, damage=contributed, shared contributors ranked', () {
      final events = [
        questSet(
          id: 'canoe',
          name: 'Canoe',
          target: 130000,
          ownership: const SharedParty(),
        ),
        _slice(id: 'a', ownership: const PersonalSlice(me), limit: 30000),
        _slice(id: 'b', ownership: const PersonalSlice(partner), limit: 30000),
        _allocate(
          user: me,
          sliceId: 'a',
          month: const Month(2026, 6),
          allocations: const [
            Allocation(destination: QuestDestination('canoe'), amountCents: 20000),
          ],
          at: _day(2026, 6, 20),
        ),
        _allocate(
          user: partner,
          sliceId: 'b',
          month: const Month(2026, 6),
          allocations: const [
            Allocation(destination: QuestDestination('canoe'), amountCents: 10000),
          ],
          at: _day(2026, 6, 20),
        ),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      final q = g.questMonsters.single;
      expect(q.targetCents, 130000);
      expect(q.contributedCents, 30000);
      expect(q.completed, isFalse);
      expect(q.shared, isTrue);
      expect(q.hp.pct, 23);
      expect(q.contributors.map((c) => c.name).toList(), ['Robin', 'Sam']);
      expect(q.sprite.assetName, Sprites.questMonster);
    });

    test('quest monster carries its main category and description', () {
      final events = [
        questSet(
          id: 'console',
          name: 'Console',
          target: 50000,
          ownership: const PersonalParty(me),
          mainCategoryId: 'entertainment',
          descriptionText: 'A humming glass beast.',
        ),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      final q = g.questMonsters.single;
      expect(q.mainCategoryId, 'entertainment');
      expect(q.descriptionText, 'A humming glass beast.');
    });

    test('completed quest keeps its trophy state and custom sprite', () {
      final events = [
        questSet(
          id: 'jacket',
          name: 'Jacket',
          target: 20000,
          ownership: const PersonalParty(me),
          sprite: 'spritehash',
        ),
        _slice(id: 'a', ownership: const PersonalSlice(me), limit: 30000),
        _allocate(
          user: me,
          sliceId: 'a',
          month: const Month(2026, 6),
          allocations: const [
            Allocation(destination: QuestDestination('jacket'), amountCents: 20000),
          ],
          at: _day(2026, 6, 20),
        ),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      final q = g.questMonsters.single;
      expect(q.completed, isTrue);
      expect(q.sprite.isCustom, isTrue);
      expect(q.sprite.customSpriteSha256, 'spritehash');
    });

    test('abandoned quest is not hunted (excluded)', () {
      final events = [
        questSet(
          id: 'trip',
          name: 'Trip',
          target: 50000,
          ownership: const PersonalParty(me),
        ),
        _slice(id: 'a', ownership: const PersonalSlice(me), limit: 30000),
        _allocate(
          user: me,
          sliceId: 'a',
          month: const Month(2026, 6),
          allocations: const [
            Allocation(destination: QuestDestination('trip'), amountCents: 20000),
          ],
          at: _day(2026, 6, 20),
        ),
        QuestAbandoned(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: me,
          occurredAt: _day(2026, 6, 25),
          createdAt: _day(2026, 6, 25),
          questId: 'trip',
        ),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      expect(g.questMonsters, isEmpty);
    });
  });

  group('war chest', () {
    PoolWithdrawalProposed propose({required String by}) =>
        PoolWithdrawalProposed(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: by,
          occurredAt: _day(2026, 7, 2),
          createdAt: _day(2026, 7, 2),
          proposalId: 'w-$by',
          byUserId: by,
          amountCents: 20000,
          purpose: 'New tent',
          destination: const ExternalDestination(),
        );

    test('pending writ raised by the partner needs my signature', () {
      final g = _game(
        [..._twoAdults(), propose(by: partner)],
        asOf: _day(2026, 7, 5),
      );
      expect(g.warChest.writsForMe, hasLength(1));
      expect(g.warChest.writsForOther, isEmpty);
      final w = g.warChest.writsForMe.single;
      expect(w.needsMySignature, isTrue);
      expect(w.byName, 'Sam');
      expect(w.destinationLabel, 'beyond the walls');
    });

    test('pending writ I raised waits on the other adventurer', () {
      final g = _game(
        [..._twoAdults(), propose(by: me)],
        asOf: _day(2026, 7, 5),
      );
      expect(g.warChest.writsForMe, isEmpty);
      expect(g.warChest.writsForOther, hasLength(1));
      expect(g.warChest.writsForOther.single.needsMySignature, isFalse);
    });

    test('ransack surfaces a loud banner', () {
      final events = [
        _slice(id: 'grp', ownership: const GroupSlice(), limit: 40000),
        EmergencyFundSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: me,
          occurredAt: _day(2026, 1, 1),
          createdAt: _day(2026, 1, 1),
          fundId: 'f',
          name: 'Car repairs',
        ),
        // Group leftover feeds the chest so it can be ransacked.
        _buy(id: 'g1', target: const SliceCharge('grp'), amount: 10000,
            at: _day(2026, 6, 3)),
        // Emergency purchase over the (zero) fund balance raids the chest.
        PurchaseAdded(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: me,
          occurredAt: _day(2026, 7, 2),
          createdAt: _day(2026, 7, 2),
          purchaseId: 'em',
          target: const EmergencyCharge('f'),
          amountCents: 5000,
          note: 'Tow truck',
        ),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      expect(g.warChest.ransacks, hasLength(1));
      final r = g.warChest.ransacks.single;
      expect(r.cacheName, 'Car repairs');
      expect(r.excessCents, 5000);
      expect(r.purpose, 'Tow truck');
    });
  });

  group('gold pouch & provisioning', () {
    test('projected mint reflects still-open leftover net of tithe', () {
      final events = [
        // Created this floor, so no prior-month spoils have accrued.
        _slice(
          id: 's',
          ownership: const PersonalSlice(me),
          limit: 40000,
          tithePct: 10,
          at: _day(2026, 7, 1),
        ),
        _buy(id: 'p1', target: const SliceCharge('s'), amount: 30000,
            at: _day(2026, 7, 3)),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      // Leftover 10000; 10% tithe floored -> 9000 minted to pouch.
      expect(g.goldPouch.projectedMintCents, 9000);
      expect(g.goldPouch.balanceCents, 0);
      expect(g.goldPouch.clampedFlag, isFalse);
    });

    test('variable maintenance awaits the quartermaster tally', () {
      final events = [
        RecurringExpenseSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: me,
          occurredAt: _day(2026, 1, 1),
          createdAt: _day(2026, 1, 1),
          expenseId: 'util',
          name: 'Utilities',
          ownership: const SharedParty(),
          kind: RecurringKind.variable,
          amountCents: 8000,
          startMonth: const Month(2026, 1),
        ),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      final util = g.provisioning.singleWhere((p) => p.name == 'Utilities');
      expect(util.kind, ProvisionKind.variableMaintenance);
      expect(util.awaitingTally, isTrue);
      expect(util.amountCents, 8000); // estimate stands until tallied
    });

    test('annual expense reads as a provisioning contract with countdown', () {
      final events = [
        RecurringExpenseSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: me,
          occurredAt: _day(2026, 1, 1),
          createdAt: _day(2026, 1, 1),
          expenseId: 'wow',
          name: 'WoW',
          ownership: const PersonalParty(me),
          kind: RecurringKind.fixed,
          cadence: RecurringCadence.annual,
          amountCents: 13100,
          dueDay: 10,
          dueMonth: 2,
          startMonth: const Month(2026, 1),
        ),
      ];
      // Read on Feb 5 2026 (household-local): the contract comes due Feb 10.
      final g = _game(events, asOf: _day(2026, 2, 5));
      final wow = g.provisioning.singleWhere((p) => p.name == 'WoW');
      expect(wow.isAnnualContract, isTrue);
      expect(wow.contractTotalCents, 13100);
      expect(wow.amountCents, 13100 ~/ 12); // 1/12 accrued per floor
      expect(wow.dueMonth, 2);
      expect(wow.dueDay, 10);
      expect(wow.daysUntilDue, 5);
    });

    test('emergency contribution appears as provisioning', () {
      final events = [
        EmergencyFundSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: me,
          occurredAt: _day(2026, 1, 1),
          createdAt: _day(2026, 1, 1),
          fundId: 'vet',
          name: 'Vet fund',
        ),
        _slice(
          id: 's',
          ownership: const PersonalSlice(me),
          limit: 40000,
          emergencyFundId: 'vet',
          emergency:
              const EmergencyContribution(fundId: 'vet', amountCents: 5000),
        ),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      final line =
          g.provisioning.singleWhere((p) => p.name == 'Vet fund');
      expect(line.kind, ProvisionKind.emergencyProvision);
      expect(line.amountCents, 5000);
    });

    test('expedition supplies mirror my income for the floor', () {
      final events = [
        IncomeSet(
          eventId: _seq.id(),
          deviceId: 'd',
          userId: me,
          occurredAt: _day(2026, 7, 1),
          createdAt: _day(2026, 7, 1),
          forUserId: me,
          amountCents: 300000,
          month: const Month(2026, 7),
        ),
      ];
      final g = _game(events, asOf: _day(2026, 7, 5));
      expect(g.expeditionSuppliesCents, 300000);
    });
  });
}
