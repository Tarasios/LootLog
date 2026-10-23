part of '../state.dart';

/// Derived state of a savings-goal quest.
class QuestState {
  const QuestState({
    required this.questId,
    required this.name,
    required this.targetCents,
    required this.ownership,
    required this.balanceCents,
    required this.contributions,
    required this.completed,
    required this.abandoned,
    this.mainCategoryId,
    this.sliceHint,
    this.customSpriteSha256,
    this.descriptionText,
  });

  final String questId;
  final String name;
  final int targetCents;
  final PartyOwnership ownership;

  /// Total funded less quest-charged spending; clamped at zero.
  final int balanceCents;

  /// How much each user has funded (used for proportional abandonment returns).
  final Map<String, int> contributions;
  final bool completed;
  final bool abandoned;

  /// The main category this goal rolls up to; drives category-match tithing.
  final String? mainCategoryId;
  final String? sliceHint;
  final String? customSpriteSha256;

  /// The user-written character description used by text-mode adventure.
  final String? descriptionText;

  int get totalContributedCents =>
      contributions.values.fold(0, (sum, cents) => sum + cents);
}
