/// Pet-owned budgets: the wire fields (`BudgetSliceSet.petOwnerIds`,
/// `MemberSet.fundedByUserId`) round-trip through JSON and reduce into state.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/value_types.dart';

DateTime get _at => DateTime.utc(2026, 7, 1, 18);

void main() {
  test('petOwnerIds and fundedByUserId round-trip through JSON', () {
    final slice = BudgetSliceSet(
      eventId: 'e1',
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _at,
      createdAt: _at,
      sliceId: 's1',
      name: 'Litter',
      ownership: const GroupSlice(),
      limitCents: 3000,
      poolTithePct: 0,
      defaultLeftoverPolicy: const CarryInSlice(),
      taxDeductibleByDefault: false,
      petOwnerIds: const ['cat1', 'cat2'],
    );
    final pet = MemberSet(
      eventId: 'e2',
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _at,
      createdAt: _at,
      memberId: 'cat2',
      name: 'Miso',
      role: MemberRole.pet,
      fundedByUserId: 'u2',
    );

    final slice2 = Event.fromJson(slice.toJson()) as BudgetSliceSet;
    expect(slice2.petOwnerIds, ['cat1', 'cat2']);
    final pet2 = Event.fromJson(pet.toJson()) as MemberSet;
    expect(pet2.fundedByUserId, 'u2');

    // Old events without the fields still parse (wire compatibility).
    final legacyJson = slice.toJson()..['payload'].remove('petOwnerIds');
    expect((Event.fromJson(legacyJson) as BudgetSliceSet).petOwnerIds, isEmpty);
  });

  test('the reducer carries both fields into state', () {
    final events = <Event>[
      MemberSet(
        eventId: 'e1',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _at,
        createdAt: _at,
        memberId: 'u1',
        name: 'Robin',
        role: MemberRole.adult,
      ),
      MemberSet(
        eventId: 'e2',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _at,
        createdAt: _at,
        memberId: 'cat1',
        name: 'Mochi',
        role: MemberRole.pet,
        fundedByUserId: 'u1',
      ),
      BudgetSliceSet(
        eventId: 'e3',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _at,
        createdAt: _at,
        sliceId: 's1',
        name: 'Cat food',
        ownership: const GroupSlice(),
        limitCents: 6000,
        poolTithePct: 0,
        defaultLeftoverPolicy: const CarryInSlice(),
        taxDeductibleByDefault: false,
        petOwnerIds: const ['cat1'],
      ),
    ];
    final s = reduce(events, asOf: _at.add(const Duration(days: 1)));
    expect(s.slices['s1']!.petOwnerIds, ['cat1']);
    expect(s.members['cat1']!.fundedByUserId, 'u1');
  });
}
