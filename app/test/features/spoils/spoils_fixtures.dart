import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/state.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/spoils/spoils_model.dart';

final DateTime setupInstant = DateTime.utc(2025, 1, 1, 18);

DateTime dayOf(int year, int month, int day) => DateTime.utc(year, month, day, 18);

/// Builds a ledger event by event for tests.
class TestLedger {
  final List<Event> events = [];
  int _sequence = 0;
  String _nextId() => 'e${(_sequence++).toString().padLeft(5, '0')}';

  void adult(String memberId) => events.add(MemberSet(
        eventId: _nextId(),
        deviceId: 'd',
        userId: memberId,
        occurredAt: setupInstant,
        createdAt: setupInstant,
        memberId: memberId,
        name: memberId,
        role: MemberRole.adult,
        active: true,
      ));

  /// [since] is when the category starts budgeting; later than [setupInstant]
  /// keeps earlier months' leftovers from filling the owner's vault.
  void category(String sliceId,
          {required String owner, int limitCents = 50000, String? mainCategoryId, DateTime? since}) =>
      events.add(BudgetSliceSet(
        eventId: _nextId(),
        deviceId: 'd',
        userId: owner,
        occurredAt: since ?? setupInstant,
        createdAt: since ?? setupInstant,
        sliceId: sliceId,
        name: sliceId,
        ownership: PersonalSlice(owner),
        limitCents: limitCents,
        poolTithePct: 0,
        defaultLeftoverPolicy: const Discretionary(),
        taxDeductibleByDefault: false,
        mainCategoryId: mainCategoryId,
      ));

  void quest(String questId, int targetCents,
          {PartyOwnership ownership = const SharedParty(), String? mainCategoryId, String? pictureSha256}) =>
      events.add(QuestSet(
        eventId: _nextId(),
        deviceId: 'd',
        userId: 'alex',
        occurredAt: setupInstant,
        createdAt: setupInstant,
        questId: questId,
        name: questId,
        targetCents: targetCents,
        ownership: ownership,
        mainCategoryId: mainCategoryId,
        customSpriteSha256: pictureSha256,
      ));

  void buy(String who, String sliceId, int cents, DateTime when) => events.add(PurchaseAdded(
        eventId: _nextId(),
        deviceId: 'd',
        userId: who,
        occurredAt: when,
        createdAt: when,
        purchaseId: 'p$_sequence',
        target: SliceCharge(sliceId),
        amountCents: cents,
      ));

  void allocate(String who, String sliceId, Month month, List<Allocation> lines) {
    final when = month.next().startInstantUtc().add(const Duration(days: 1, hours: 18));
    events.add(LeftoverAllocated(
      eventId: _nextId(),
      deviceId: 'd',
      userId: who,
      occurredAt: when,
      createdAt: when,
      forUserId: who,
      month: month,
      sliceId: sliceId,
      allocations: lines,
    ));
  }
}

/// October 3rd, inside September's month-end window.
final DateTime ritualInstant = dayOf(2026, 10, 3);

SpoilsRitual _ritual(HouseholdState household) =>
    buildSpoilsRitual(household, meUserId: 'alex', userNames: const {'alex': 'Alex'}, asOf: ritualInstant)!;

/// Alex has $150 left in Fun and $100 in Food for September, and a $1,300
/// canoe goal (Entertainment) with nothing saved yet.
(HouseholdState, SpoilsRitual) ritualFixture() {
  final ledger = TestLedger()
    ..adult('alex')
    ..category('fun', owner: 'alex', limitCents: 20000, mainCategoryId: 'entertainment')
    ..category('food', owner: 'alex', limitCents: 40000, mainCategoryId: 'food')
    ..quest('canoe', 130000, ownership: const PersonalParty('alex'), mainCategoryId: 'entertainment')
    ..buy('alex', 'fun', 5000, dayOf(2026, 9, 10))
    ..buy('alex', 'food', 30000, dayOf(2026, 9, 12));
  final household = reduce(ledger.events, asOf: ritualInstant);
  return (household, _ritual(household));
}

/// As [ritualFixture] without the goal, but Fun overspent by $50 in September
/// with an empty vault (the categories only start in September), so its
/// OVERBUDGET stands during the October ritual window.
(HouseholdState, SpoilsRitual) ritualFixtureWithDebt() {
  final ledger = TestLedger()
    ..adult('alex')
    ..category('fun', owner: 'alex', limitCents: 20000, mainCategoryId: 'entertainment', since: dayOf(2026, 9, 1))
    ..category('food', owner: 'alex', limitCents: 40000, mainCategoryId: 'food', since: dayOf(2026, 9, 1))
    ..buy('alex', 'fun', 25000, dayOf(2026, 9, 10))
    ..buy('alex', 'food', 30000, dayOf(2026, 9, 12));
  final household = reduce(ledger.events, asOf: ritualInstant);
  return (household, _ritual(household));
}
