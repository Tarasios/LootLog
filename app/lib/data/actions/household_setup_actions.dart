part of '../actions.dart';

/// The household's configuration: members and pets, incomes, recurring
/// expenses, budget and main categories, emergency funds, group shares and
/// custom sprites.
mixin _HouseholdSetupActions on _HouseholdActionsCore {
  /// Sets a user's income for [month] (last-writer-wins in the reducer).
  Future<void> setIncome({
    required String forUserId,
    required Month month,
    required int amountCents,
  }) async {
    final now = DateTime.now().toUtc();
    await append(
      IncomeSet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        forUserId: forUserId,
        amountCents: amountCents,
        month: month,
      ),
    );
  }

  /// Sets a user's default monthly income, effective from [effectiveFromMonth]
  /// and carried forward until a later default supersedes it. For a variable
  /// earner, [amountCents] is the low end the budget plans on and
  /// [estimatedHighCents] the optimistic top of the range (display only).
  Future<void> setDefaultIncome({
    required String forUserId,
    required int amountCents,
    required Month effectiveFromMonth,
    int? estimatedHighCents,
  }) async {
    final now = DateTime.now().toUtc();
    await append(
      DefaultIncomeSet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        forUserId: forUserId,
        amountCents: amountCents,
        effectiveFromMonth: effectiveFromMonth,
        estimatedHighCents:
            estimatedHighCents != null && estimatedHighCents > amountCents
            ? estimatedHighCents
            : null,
      ),
    );
  }

  /// Creates or amends a recurring expense. Reuse [expenseId] to edit; pass
  /// [endMonth] to schedule a cancellation.
  Future<String> setRecurringExpense({
    String? expenseId,
    required String name,
    required PartyOwnership ownership,
    required RecurringKind kind,
    required int amountCents,
    required Month startMonth,
    Month? endMonth,
    RecurringCadence cadence = RecurringCadence.monthly,
    int dueDay = 1,
    int? dueMonth,
  }) async {
    final now = DateTime.now().toUtc();
    final id = expenseId ?? uuidv7();
    await append(
      RecurringExpenseSet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        expenseId: id,
        name: name,
        ownership: ownership,
        kind: kind,
        cadence: cadence,
        amountCents: amountCents,
        dueDay: dueDay,
        dueMonth: dueMonth,
        startMonth: startMonth,
        endMonth: endMonth,
      ),
    );
    return id;
  }

  /// Creates or amends a budget category (last-writer-wins by [sliceId]; the
  /// wire event stays `BudgetSliceSet`).
  Future<String> setSlice({
    String? sliceId,
    required String name,
    required SliceOwnership ownership,
    required int limitCents,
    required int poolTithePct,
    required LeftoverDestination defaultLeftoverPolicy,
    required bool taxDeductibleByDefault,
    String? mainCategoryId,
    EmergencyContribution? emergencyContribution,
    String? petId,
    List<String> petOwnerIds = const [],
    SlicePriority priority = SlicePriority.important,
  }) async {
    final now = DateTime.now().toUtc();
    final id = sliceId ?? uuidv7();
    await append(
      BudgetSliceSet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        sliceId: id,
        name: name,
        ownership: ownership,
        mainCategoryId: mainCategoryId,
        limitCents: limitCents,
        poolTithePct: poolTithePct,
        defaultLeftoverPolicy: defaultLeftoverPolicy,
        taxDeductibleByDefault: taxDeductibleByDefault,
        emergencyContribution: emergencyContribution,
        petId: petId,
        petOwnerIds: petOwnerIds,
        priority: priority,
      ),
    );
    return id;
  }

  /// Creates or amends a main category (last-writer-wins by [id]).
  Future<String> setMainCategory({
    required String id,
    required String name,
    required int colorArgb,
    required int sortOrder,
  }) async {
    final now = DateTime.now().toUtc();
    await append(
      MainCategorySet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        id: id,
        name: name,
        colorArgb: colorArgb,
        sortOrder: sortOrder,
      ),
    );
    return id;
  }

  /// Creates or renames an emergency fund (last-writer-wins by [fundId]).
  Future<String> setEmergencyFund({
    String? fundId,
    required String name,
    String? petId,
  }) async {
    final now = DateTime.now().toUtc();
    final id = fundId ?? uuidv7();
    await append(
      EmergencyFundSet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        fundId: id,
        name: name,
        petId: petId,
      ),
    );
    return id;
  }

  /// Creates or renames a pet party member (last-writer-wins by [petId]).
  Future<String> setPet({
    String? petId,
    required String name,
    String? customSpriteSha256,
  }) async {
    final now = DateTime.now().toUtc();
    final id = petId ?? uuidv7();
    await append(
      PetSet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        petId: id,
        name: name,
        customSpriteSha256: customSpriteSha256,
      ),
    );
    return id;
  }

  /// Creates, amends, or retires a household member (last-writer-wins by
  /// [memberId]). Pass `active: false` to retire without deleting history.
  Future<String> setMember({
    String? memberId,
    required String name,
    required MemberRole role,
    bool active = true,
    String? customSpriteSha256,
    String? descriptionText,
    String? fundedByUserId,
  }) async {
    final now = DateTime.now().toUtc();
    final id = memberId ?? uuidv7();
    await append(
      MemberSet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        memberId: id,
        name: name,
        role: role,
        active: active,
        customSpriteSha256: customSpriteSha256,
        descriptionText: descriptionText,
        fundedByUserId: role == MemberRole.pet ? fundedByUserId : null,
      ),
    );
    return id;
  }

  /// Sets the per-adult share table for [month] (permille per adult id). Absent,
  /// shared costs split evenly.
  Future<void> setGroupShares({
    required Month month,
    required Map<String, int> shares,
  }) async {
    final now = DateTime.now().toUtc();
    await append(
      GroupShareSet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        month: month,
        shares: shares,
      ),
    );
  }

  /// Ingests a custom sprite PNG into the blob store, returning its sha256 for
  /// reference from a [PetSet] / [QuestSet]. Throws [SpriteRejected] if invalid.
  Future<String> ingestSpriteBytes(Uint8List pngBytes) async {
    final ingested = await ingestSprite(pngBytes, blobs);
    return ingested.sha256;
  }
}
