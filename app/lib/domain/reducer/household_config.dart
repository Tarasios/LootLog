part of '../reducer.dart';

/// Read-models of the household's configuration: members and pets, main
/// categories and default incomes.
extension _HouseholdConfig on _HouseholdStateBuilder {
  /// Members. Legacy PetSet events reduce as pet members; an explicit
  /// MemberSet with the same id (last writer) overrides.
  Map<String, MemberState> _memberStates() {
    final members = <String, MemberState>{};
    for (final pet in petConfigs.values) {
      members[pet.petId] = MemberState(
        memberId: pet.petId,
        name: pet.name,
        role: MemberRole.pet,
        active: true,
        customSpriteSha256: pet.customSpriteSha256,
      );
    }
    for (final member in memberConfigs.values) {
      members[member.memberId] = MemberState(
        memberId: member.memberId,
        name: member.name,
        role: member.role,
        active: member.active,
        customSpriteSha256: member.customSpriteSha256,
        descriptionText: member.descriptionText,
        fundedByUserId: member.fundedByUserId,
      );
    }
    return members;
  }

  /// Pets are the active pet-role members (the display-level party pets).
  Map<String, PetState> _petStates(Map<String, MemberState> members) {
    return <String, PetState>{
      for (final member in members.values)
        if (member.role == MemberRole.pet && member.active)
          member.memberId: PetState(
            petId: member.memberId,
            name: member.name,
            customSpriteSha256: member.customSpriteSha256,
          ),
    };
  }

  /// Main categories: seed the documented defaults, then apply any
  /// MainCategorySet overrides/additions (last-writer-wins by id).
  Map<String, MainCategory> _mainCategories() {
    final mainCategories = <String, MainCategory>{
      for (final category in defaultMainCategories) category.id: category,
    };
    for (final config in mainCategoryConfigs.values) {
      mainCategories[config.id] = MainCategory(
        id: config.id,
        name: config.name,
        colorArgb: config.colorArgb,
        sortOrder: config.sortOrder,
      );
    }
    return mainCategories;
  }

  /// Default incomes per user, sorted ascending by the month they take effect.
  Map<String, List<DefaultIncome>> _incomeDefaultsByUser() {
    final incomeDefaultsByUser = <String, List<DefaultIncome>>{};
    for (final config in defaultIncomeConfigs.values) {
      incomeDefaultsByUser
          .putIfAbsent(config.forUserId, () => [])
          .add(
            DefaultIncome(
              effectiveFromMonth: config.effectiveFromMonth,
              amountCents: config.amountCents,
              estimatedHighCents: config.estimatedHighCents,
            ),
          );
    }
    for (final defaults in incomeDefaultsByUser.values) {
      defaults.sort(
        (first, second) =>
            first.effectiveFromMonth.compareTo(second.effectiveFromMonth),
      );
    }
    return incomeDefaultsByUser;
  }
}
