/// Round-2 wizard features: per-category tithe %, customizable main
/// categories, the even income split, and the over-allocation guard.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/state.dart'
    show MainCategory, defaultMainCategories;
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/features/setup/onboarding_plan.dart';
import 'package:lootlog/features/setup/setup_controller.dart';

String Function() _counter() {
  var n = 0;
  return () => 'e${(n++).toString().padLeft(4, '0')}';
}

OnboardingPlan _plan(OnboardingInput input) => buildOnboardingEvents(
      input,
      deviceId: 'device-1',
      startMonth: const Month(2026, 7),
      now: DateTime.utc(2026, 7, 9, 18),
      idGen: _counter(),
    );

const _adult = DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Robin');

void main() {
  test('a category tithe % lands on the BudgetSliceSet', () {
    final plan = _plan(const OnboardingInput(
      members: [_adult],
      meLocalId: 'a1',
      categories: [
        DraftCategory(
            name: 'Games',
            limitCents: 5000,
            group: false,
            ownerLocalId: 'a1',
            tithePct: 25),
      ],
    ));
    final slice = plan.events.whereType<BudgetSliceSet>().single;
    expect(slice.poolTithePct, 25);
  });

  test('unchanged default main categories write no events', () {
    final plan = _plan(OnboardingInput(
      members: const [_adult],
      meLocalId: 'a1',
      mainCategories: defaultMainCategories,
    ));
    expect(plan.events.whereType<MainCategorySet>(), isEmpty);
  });

  test('renamed and added main categories write MainCategorySet events', () {
    final renamed = defaultMainCategories.first.copyWith(name: 'Shelter');
    const added = MainCategory(
        id: 'custom-1', name: 'Gifts', colorArgb: 0xFF123456, sortOrder: 8);
    final plan = _plan(OnboardingInput(
      members: const [_adult],
      meLocalId: 'a1',
      mainCategories: [renamed, ...defaultMainCategories.skip(1), added],
    ));
    final sets = plan.events.whereType<MainCategorySet>().toList();
    expect(sets, hasLength(2));
    expect(sets.first.id, defaultMainCategories.first.id);
    expect(sets.first.name, 'Shelter');
    expect(sets.last.id, 'custom-1');
    expect(sets.last.name, 'Gifts');
  });

  group('SetupController', () {
    SetupController seeded() {
      final c = SetupController();
      final a = c.addMember(DraftRole.adult, 'Robin');
      c.setIncome(a, 300000); // $3000
      c.addCategory(DraftCategory(
          name: 'Food', limitCents: 0, group: false, ownerLocalId: a));
      c.addCategory(DraftCategory(
          name: 'Fun', limitCents: 0, group: false, ownerLocalId: a));
      c.addCategory(DraftCategory(
          name: 'Stuff', limitCents: 0, group: false, ownerLocalId: a));
      return c;
    }

    test('splitEvenlyFor divides income remainder across personal categories',
        () {
      final c = seeded();
      final a = c.adults.single.localId;
      c.addFixedExpense(DraftFixedExpense(
          name: 'Rent', shared: false, ownerLocalId: a, amountCents: 100000));
      c.splitEvenlyFor(a);
      final limits = [
        for (final cat in c.categories)
          if (!cat.group) cat.limitCents
      ];
      // $3000 - $1000 rent = $2000 across 3: 66667 + 66667 + 66666.
      expect(limits.reduce((x, y) => x + y), 200000);
      expect(limits, [66667, 66667, 66666]);
      expect(c.allocationFor(a).unallocatedCents, 0);
      expect(c.anyOverAllocated, isFalse);
    });

    test('anyOverAllocated flags a plan that exceeds income', () {
      final c = seeded();
      final a = c.adults.single.localId;
      c.updateCategory(0, c.categories[0].copyWith(limitCents: 400000));
      expect(c.allocationFor(a).unallocatedCents, lessThan(0));
      expect(c.anyOverAllocated, isTrue);
    });

    test('rename and add main categories feed buildInput', () {
      final c = seeded();
      c.renameMainCategory('housing', 'Shelter');
      c.addMainCategory('Gifts');
      final input = c.buildInput();
      expect(input.mainCategories.first.name, 'Shelter');
      expect(input.mainCategories.last.name, 'Gifts');
      expect(input.mainCategories.length, defaultMainCategories.length + 1);
    });
  });
}
