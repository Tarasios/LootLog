import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/money.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/domain/town/town_ledger.dart';

import '../../../features/spoils/spoils_fixtures.dart';

/// October 3rd 2026, 11:00 in Vancouver.
final DateTime ledgerInstant = dayOf(2026, 10, 3);
const names = {'alex': 'Alex', 'sam': 'Sam'};

void bill(
  TestLedger ledger,
  String name, {
  required int dueDay,
  String? owner,
}) => ledger.events.add(
  RecurringExpenseSet(
    eventId: 'bill-$name',
    deviceId: 'd',
    userId: owner ?? 'alex',
    occurredAt: setupInstant,
    createdAt: setupInstant,
    expenseId: name,
    name: name,
    ownership: owner == null ? const SharedParty() : PersonalParty(owner),
    kind: RecurringKind.fixed,
    amountCents: 5000,
    startMonth: const Month(2026, 1),
    dueDay: dueDay,
  ),
);

/// Alex has $70 saved to the pouch from September's Fun and a Canoe goal;
/// four bills fall due 0, 1, 3 and 17 days from now.
TestLedger townLedgerFixture() {
  final ledger = TestLedger()
    ..adult('alex')
    ..adult('sam')
    ..category('fun', owner: 'alex', limitCents: 20000, since: dayOf(2026, 9, 1))
    ..quest('canoe', 130000, ownership: const PersonalParty('alex'))
    ..allocate('alex', 'fun', const Month(2026, 9), const [
      Allocation(destination: QuestDestination('canoe'), amountCents: 13000),
      Allocation(destination: Discretionary(), amountCents: 7000),
    ]);
  bill(ledger, 'gym', dueDay: 3, owner: 'sam');
  bill(ledger, 'rent', dueDay: 4, owner: 'alex');
  bill(ledger, 'internet', dueDay: 6);
  bill(ledger, 'insurance', dueDay: 20);
  return ledger;
}

void main() {
  final household = reduce(townLedgerFixture().events, asOf: ledgerInstant);

  TownLedger ledgerFor({bool showOtherAdults = true}) => TownLedger.from(
    household,
    meId: 'alex',
    names: names,
    showOtherAdults: showOtherAdults,
    now: ledgerInstant,
  );

  test('the gold pouch and war chest are the reducer figures', () {
    final ledger = ledgerFor();
    expect(ledger.goldPouch, Money(household.vaultOf('alex')));
    expect(ledger.goldPouch!.cents, greaterThan(0));
    expect(ledger.warChest, Money(household.warChest.balanceCents));
  });

  test('the board carries the goals', () {
    final goals = ledgerFor().board.goals;
    expect(goals.single.name, 'canoe');
    expect(goals.single.percent, 10);
  });

  test('bills due within three days, soonest first, with their owner', () {
    final bills = ledgerFor().bills;
    expect(bills.map((bill) => bill.name), ['gym', 'rent', 'internet']);
    expect(bills.map((bill) => bill.daysUntilDue), [0, 1, 3]);
    expect(bills.map((bill) => bill.ownerId), ['sam', 'alex', null]);
  });

  test("hiding other adults' budgets hides their personal bills", () {
    final bills = ledgerFor(showOtherAdults: false).bills;
    expect(bills.map((bill) => bill.name), ['rent', 'internet']);
  });

  test('the empty ledger shows nothing yet', () {
    expect(TownLedger.empty.goldPouch, isNull);
    expect(TownLedger.empty.board.goals, isEmpty);
    expect(TownLedger.empty.bills, isEmpty);
  });
}
