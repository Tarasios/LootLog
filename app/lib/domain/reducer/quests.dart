part of '../reducer.dart';

/// Quests (savings goals): funding, category-match tithing, drawdowns,
/// completion and abandonment.
extension _QuestDerivation on _HouseholdStateBuilder {
  /// Adds [cents] of damage to [questId], attributed to [contributorId].
  void _creditQuest(String questId, String contributorId, int cents) {
    questBalance[questId] = (questBalance[questId] ?? 0) + cents;
    final contributions = questContributions.putIfAbsent(questId, () => {});
    contributions[contributorId] = (contributions[contributorId] ?? 0) + cents;
  }

  /// Category-match rule: money from [source] reaches [questId] untithed only
  /// when the quest's main category matches the source category's. A quest
  /// without a main category never matches.
  bool _questMatchesCategory(String questId, SliceConfig source) {
    final quest = questConfigs[questId];
    return quest?.mainCategoryId != null &&
        quest!.mainCategoryId == source.mainCategoryId;
  }

  /// Quests: applies drawdowns, completion, and abandonment. An abandoned
  /// quest's remaining balance returns to its funders' vaults in proportion
  /// to their contributions, minus the dissolution tithe to the war chest.
  Map<String, QuestState> _settleQuests(Map<String, int> questDrawdown) {
    final questStates = <String, QuestState>{};
    for (final config in questConfigs.values) {
      final funded = questBalance[config.questId] ?? 0;
      final drawn = questDrawdown[config.questId] ?? 0;
      var balance = funded - drawn;
      if (balance < 0) {
        balance = 0;
      }
      final contributions = Map<String, int>.from(
        questContributions[config.questId] ?? {},
      );
      final totalContributed = contributions.values.fold(
        0,
        (sum, cents) => sum + cents,
      );
      final completed =
          totalContributed >= config.targetCents && config.targetCents > 0;
      final abandoned = abandonedQuests.contains(config.questId);

      if (abandoned && balance > 0) {
        final tithe = Money.titheCents(
          balance,
          settings.dissolutionTithePct,
        ).titheCents;
        // Attribute the dissolution tithe to the abandonment month.
        _addChest(tithe, _abandonMonth(config.questId));
        final distributable = balance - tithe;
        final returns = _splitProportionally(distributable, contributions);
        returns.forEach(_addVault);
        balance = 0;
      }

      questStates[config.questId] = QuestState(
        questId: config.questId,
        name: config.name,
        targetCents: config.targetCents,
        ownership: config.ownership,
        balanceCents: balance,
        contributions: contributions,
        completed: completed,
        abandoned: abandoned,
        mainCategoryId: config.mainCategoryId,
        sliceHint: config.sliceHint,
        customSpriteSha256: config.customSpriteSha256,
        descriptionText: config.descriptionText,
      );
    }
    return questStates;
  }

  Month _abandonMonth(String questId) {
    // The abandonment occurredMonth was captured on the QuestAbandoned event;
    // fall back to the asOf month if unavailable.
    final abandonedAt = _abandonInstants[questId];
    return abandonedAt != null
        ? Month.fromInstant(abandonedAt)
        : Month.fromInstant(now);
  }
}
