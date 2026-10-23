part of '../reducer.dart';

/// Vault (general savings) and war-chest flows outside the month sweep:
/// gifts, pool contributions, tax refunds, the zero clamp and goal progress.
extension _VaultsAndWarChest on _HouseholdStateBuilder {
  /// Month-buckets gifts and pool contributions for the availability model
  /// (their actual vault application happens after the sweep,
  /// order-independent).
  void _bucketGiftAndContributionFlows() {
    for (final gift in gifts) {
      _recordVaultFlow(gift.forUserId, gift.occurredMonth, gift.amountCents);
    }
    for (final contribution in contributions) {
      _recordVaultFlow(
        contribution.fromUserId,
        contribution.occurredMonth,
        -contribution.amountCents,
      );
    }
  }

  /// Gifts credit vaults, untithed; pool contributions move vault -> war
  /// chest; tax refunds land in the war chest.
  void _applyGiftsContributionsAndRefunds() {
    for (final gift in gifts) {
      _addVault(gift.forUserId, gift.amountCents);
    }
    for (final contribution in contributions) {
      _addVault(contribution.fromUserId, -contribution.amountCents);
      _addChest(contribution.amountCents, contribution.occurredMonth);
    }
    for (final refund in taxRefunds) {
      _addChest(refund.amountCents, refund.occurredMonth);
    }
  }

  /// Clamps vaults at zero, flagging the users whose vault went negative.
  ({Map<String, int> clampedVaults, Set<String> inconsistentVaults})
  _clampVaults() {
    final clampedVaults = <String, int>{};
    final inconsistentVaults = <String>{};
    for (final entry in vault.entries) {
      if (entry.value < 0) {
        inconsistentVaults.add(entry.key);
        clampedVaults[entry.key] = 0;
      } else {
        clampedVaults[entry.key] = entry.value;
      }
    }
    return (
      clampedVaults: clampedVaults,
      inconsistentVaults: inconsistentVaults,
    );
  }

  /// War chest goal progress: estimated months remaining comes from the
  /// trailing three months' average net inflow (null when it is not
  /// positive). Null without a target or without any swept months.
  GoalProgress? _warChestGoal((Month, Month)? range) {
    if (goalTarget == null || range == null) {
      return null;
    }
    final target = goalTarget!;
    final remaining = warChest < target ? target - warChest : 0;
    final asOfMonth = Month.fromInstant(now);
    final trailing = [asOfMonth, asOfMonth.prev(), asOfMonth.prev().prev()];
    final trailingNet = trailing.fold(
      0,
      (sum, month) => sum + (chestMonthlyNet[month.toKey()] ?? 0),
    );
    final averageInflow = trailingNet / 3.0;
    return GoalProgress(
      targetCents: target,
      pctComplete: target == 0 ? 1.0 : warChest / target,
      remainingCents: remaining,
      avgNetInflowCents: averageInflow,
      estMonthsRemaining: averageInflow > 0 ? remaining / averageInflow : null,
    );
  }
}
