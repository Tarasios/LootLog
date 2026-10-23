part of '../event.dart';

class QuestSet extends Event {
  const QuestSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.questId,
    required this.name,
    required this.targetCents,
    required this.ownership,
    this.mainCategoryId,
    this.sliceHint,
    this.customSpriteSha256,
    this.descriptionText,
  });

  final String questId;
  final String name;
  final int targetCents;
  final PartyOwnership ownership;

  /// The main category this savings goal rolls up to (see [MainCategorySet]).
  /// Drives category-match tithing: an attack funded from a budget category
  /// whose main category matches this is untithed; from a non-matching category
  /// the source's pool tithe applies. Optional for wire compatibility with
  /// pre-main-category quests (they behave as non-matching, i.e. always tithed).
  final String? mainCategoryId;
  final String? sliceHint;
  final String? customSpriteSha256;

  /// The user-written character description used by text-mode adventure.
  final String? descriptionText;

  @override
  String get type => 'QuestSet';

  @override
  Map<String, dynamic> payload() => {
    'questId': questId,
    'name': name,
    'targetCents': targetCents,
    'ownership': ownership.toJson(),
    if (mainCategoryId != null) 'mainCategoryId': mainCategoryId,
    if (sliceHint != null) 'sliceHint': sliceHint,
    if (customSpriteSha256 != null) 'customSpriteSha256': customSpriteSha256,
    if (descriptionText != null) 'descriptionText': descriptionText,
  };
}

class QuestAbandoned extends Event {
  const QuestAbandoned({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.questId,
  });

  final String questId;

  @override
  String get type => 'QuestAbandoned';

  @override
  Map<String, dynamic> payload() => {'questId': questId};
}
