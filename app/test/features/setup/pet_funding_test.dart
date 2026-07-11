/// Pet funding attribution in the wizard's planning math: each owning pet's
/// equal share of a pet category lands on that pet's funding source.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/features/setup/onboarding_plan.dart';
import 'package:lootlog/features/setup/setup_controller.dart';

void main() {
  test('mixed pet funding splits between the group and an adult', () {
    final c = SetupController();
    final a1 = c.addMember(DraftRole.adult, 'Robin');
    final a2 = c.addMember(DraftRole.adult, 'Sam');
    c.setIncome(a1, 200000);
    c.setIncome(a2, 200000);
    final cat1 = c.addMember(DraftRole.pet, 'Mochi'); // group-funded
    final cat2 =
        c.addMember(DraftRole.pet, 'Miso', fundedByUserId: a2); // Sam's

    // Litter, $30, shared by both cats: $15 group + $15 on Sam.
    c.addCategory(DraftCategory(
        name: 'Litter',
        limitCents: 3000,
        group: true,
        petOwnerIds: [cat1, cat2]));

    expect(c.groupBurdenCents, 1500);
    expect(c.allocationFor(a2).personalBudgetCents, 1500);
    expect(c.allocationFor(a1).personalBudgetCents, 0);
    // Even shares: each adult carries half the group burden.
    expect(c.allocationFor(a1).groupShareCents, 750);
    expect(c.allocationFor(a2).groupShareCents, 750);
  });
}
