part of '../actions.dart';

/// Savings-goal quests: creating, amending and abandoning them.
mixin _QuestActions on _HouseholdActionsCore {
  /// Creates or amends a savings-goal quest (last-writer-wins by [questId]).
  Future<String> setQuest({
    String? questId,
    required String name,
    required int targetCents,
    required PartyOwnership ownership,
    String? mainCategoryId,
    String? sliceHint,
    String? customSpriteSha256,
    String? descriptionText,
  }) async {
    final now = DateTime.now().toUtc();
    final id = questId ?? uuidv7();
    await append(
      QuestSet(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        questId: id,
        name: name,
        targetCents: targetCents,
        ownership: ownership,
        mainCategoryId: mainCategoryId,
        sliceHint: sliceHint,
        customSpriteSha256: customSpriteSha256,
        descriptionText: descriptionText,
      ),
    );
    return id;
  }

  /// Abandons a quest, returning its balance to funders (post dissolution tithe).
  Future<void> abandonQuest(String questId) async {
    final now = DateTime.now().toUtc();
    await append(
      QuestAbandoned(
        eventId: uuidv7(),
        deviceId: deviceId,
        userId: meUserId,
        occurredAt: now,
        createdAt: now,
        questId: questId,
      ),
    );
  }
}
