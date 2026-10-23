part of '../reducer.dart';

/// OVERBUDGET settlement: close-time seizure from the owner's vault, the
/// debts left behind, and their read-model.
extension _OverbudgetSettlement on _HouseholdStateBuilder {
  /// Close settlement for one month. Each category's overflow is seized from
  /// the owner's vault first, using only funds available by that month;
  /// whatever the vault cannot cover becomes OVERBUDGET debt on the category
  /// (the intimidating monster).
  void _seizeOverspendAtClose(List<_PersonalCategoryMonth> figures) {
    for (final figure in figures) {
      if (figure.overspend == 0) {
        continue;
      }
      final ownerId = figure.ownerId;
      final available = availableVault[ownerId] ?? 0;
      final coverable = available > 0 ? available : 0;
      final seized = figure.overspend < coverable
          ? figure.overspend
          : coverable;
      if (seized > 0) {
        availableVault[ownerId] = available - seized;
        _addVault(ownerId, -seized);
      }
      final remainder = figure.overspend - seized;
      if (remainder > 0) {
        _accrueDebt(figure.config.sliceId, ownerId, remainder);
      }
    }
  }

  /// Adds [cents] of debt owed by [ownerId] under [debtKey] (a sliceId, or a
  /// `provisions:<expenseId>` key).
  void _accrueDebt(String debtKey, String ownerId, int cents) {
    debtBySlice[debtKey] = (debtBySlice[debtKey] ?? 0) + cents;
    debtAccrued[debtKey] = (debtAccrued[debtKey] ?? 0) + cents;
    debtOwner[debtKey] = ownerId;
  }

  /// Category-match rule for debt payments: money from [source] pays
  /// [sliceId]'s debt untithed only when both share a main category.
  bool _sliceMatchesCategory(String sliceId, SliceConfig source) {
    final target = slices[sliceId];
    return target?.mainCategoryId != null &&
        target!.mainCategoryId == source.mainCategoryId;
  }

  /// Every debt ever accrued, with what is still outstanding.
  Map<String, OverbudgetState> _overbudgetStates() {
    return {
      for (final sliceId in debtAccrued.keys)
        sliceId: OverbudgetState(
          sliceId: sliceId,
          ownerUserId: debtOwner[sliceId]!,
          accruedCents: debtAccrued[sliceId]!,
          outstandingCents: debtBySlice[sliceId] ?? 0,
          kind: debtKind[sliceId] ?? DebtKind.overbudget,
        ),
    };
  }
}
