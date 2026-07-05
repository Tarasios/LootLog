import 'package:duobudget/domain/event.dart';
import 'package:duobudget/domain/reducer.dart';
import 'package:duobudget/domain/time.dart';
import 'package:duobudget/domain/value_types.dart';
import 'package:duobudget/features/dashboard/dashboard_model.dart';
import 'package:duobudget/features/spoils/spoils_model.dart';
import 'package:flutter_test/flutter_test.dart';

const me = 'me';
const pa = 'pa';
const names = {me: 'Robin', pa: 'Sam'};

int _n = 0;
String _id() => 'e${(_n++).toString().padLeft(4, '0')}';
DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

BudgetSliceSet _slice({
  required String id,
  required SliceOwnership ownership,
  required int limit,
  int tithePct = 0,
  LeftoverDestination policy = const Discretionary(),
}) =>
    BudgetSliceSet(
      eventId: _id(),
      deviceId: 'd',
      userId: me,
      occurredAt: _day(2026, 1, 1),
      createdAt: _day(2026, 1, 1),
      sliceId: id,
      name: id == 'food' ? 'Food' : (id == 'gear' ? 'Gear' : id),
      ownership: ownership,
      limitCents: limit,
      poolTithePct: tithePct,
      defaultLeftoverPolicy: policy,
      taxDeductibleByDefault: false,
    );

PurchaseAdded _buy(String id, String slice, int amount, DateTime at,
        {String by = me}) =>
    PurchaseAdded(
      eventId: _id(),
      deviceId: 'd',
      userId: by,
      occurredAt: at,
      createdAt: at,
      purchaseId: id,
      target: SliceCharge(slice),
      amountCents: amount,
    );

void main() {
  final events = <Event>[
    _slice(id: 'food', ownership: const PersonalSlice(me), limit: 40000, tithePct: 20),
    _slice(id: 'gear', ownership: const PersonalSlice(pa), limit: 30000),
    RecurringExpenseSet(
      eventId: _id(),
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
    _buy('p-jun', 'food', 25000, _day(2026, 6, 10)),
    _buy('p-jul', 'food', 10000, _day(2026, 7, 3)),
  ];

  final asOf = DateTime.utc(2026, 7, 5, 18);
  final state = reduce(events, asOf: asOf);

  test('spoils ritual surfaces the closed month within grace', () {
    final ritual =
        buildSpoilsRitual(state, meUserId: me, userNames: names, asOf: asOf);
    expect(ritual, isNotNull);
    expect(ritual!.month, const Month(2026, 6));
    expect(ritual.isActionable, isTrue);

    // Variable expense awaiting its June actual.
    expect(ritual.variableTallies.map((t) => t.expenseId), ['util']);

    // My unresolved food leftover for June (40000 - 25000).
    final food = ritual.sliceLeftovers.singleWhere((s) => s.sliceId == 'food');
    expect(food.leftoverCents, 15000);
    expect(food.poolTithePct, 20);

    // The partner's slice is not mine to divide.
    expect(ritual.sliceLeftovers.any((s) => s.sliceId == 'gear'), isFalse);
  });

  test('spoils window closes after grace', () {
    final after = reduce(events, asOf: DateTime.utc(2026, 7, 20, 18));
    final ritual = buildSpoilsRitual(after,
        meUserId: me,
        userNames: names,
        asOf: DateTime.utc(2026, 7, 20, 18));
    expect(ritual, isNull);
  });

  test('dashboard model: rings, maintenance tally, projected spoils', () {
    final model =
        buildDashboardModel(state, meUserId: me, userNames: names, asOf: asOf);

    expect(model.currentMonth, const Month(2026, 7));
    expect(model.meName, 'Robin');

    final foodRing = model.slices.singleWhere((r) => r.sliceId == 'food');
    expect(foodRing.mine, isTrue);
    expect(foodRing.spentCents, 10000);
    expect(foodRing.effectiveLimitCents, 40000);

    // Utilities is variable and its June actual is unrecorded -> awaiting tally.
    final util = model.maintenance.singleWhere((m) => m.name == 'Utilities');
    expect(util.awaitingTally, isTrue);

    // July food leftover 30000; discretionary at 20% tithe -> 24000 to vault.
    expect(model.vault.projectedLeftoverCents, 30000);
    expect(model.vault.projectedVaultCents, 24000);
  });
}
