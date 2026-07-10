/// Tests the Budget setup view-model: personal slices grouped per member, group
/// slices separated, income surfaced, and per-slice month figures pulled through.
library;

import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/budget_setup/budget_setup_model.dart';
import 'package:flutter_test/flutter_test.dart';

int _n = 0;
String _id() => 'e${(_n++).toString().padLeft(4, '0')}';
DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

BudgetSliceSet _slice(String id, String name, SliceOwnership own, int limit) =>
    BudgetSliceSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 1, 1),
      createdAt: _day(2026, 1, 1),
      sliceId: id,
      name: name,
      ownership: own,
      limitCents: limit,
      poolTithePct: 0,
      defaultLeftoverPolicy: const Discretionary(),
      taxDeductibleByDefault: false,
    );

void main() {
  test('groups slices by member and separates group slices', () {
    final events = <Event>[
      _slice('a', 'Alex Food', const PersonalSlice('u1'), 40000),
      _slice('b', 'Sam Fun', const PersonalSlice('u2'), 20000),
      _slice('g', 'Groceries', const GroupSlice(), 60000),
      IncomeSet(
        eventId: _id(),
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _day(2026, 1, 1),
        createdAt: _day(2026, 1, 1),
        forUserId: 'u1',
        amountCents: 500000,
        month: const Month(2026, 1),
      ),
      PurchaseAdded(
        eventId: _id(),
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _day(2026, 1, 10),
        createdAt: _day(2026, 1, 10),
        purchaseId: 'p1',
        target: const SliceCharge('a'),
        amountCents: 15000,
      ),
    ];
    final state = reduce(events, asOf: _day(2026, 1, 15));
    final model = buildBudgetSetupModel(
      state,
      month: const Month(2026, 1),
      orderedUserIds: const ['u1', 'u2'],
    );

    expect(model.columns, hasLength(2));
    final u1 = model.columns[0];
    expect(u1.userId, 'u1');
    expect(u1.incomeCents, 500000);
    expect(u1.slices.single.name, 'Alex Food');
    expect(u1.slices.single.spentCents, 15000);
    expect(u1.slices.single.effectiveLimitCents, 40000);
    expect(u1.slices.single.remainingCents, 25000);

    expect(model.columns[1].slices.single.name, 'Sam Fun');
    expect(model.groupSlices.single.name, 'Groceries');
  });
}
