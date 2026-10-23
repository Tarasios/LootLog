part of '../state.dart';

/// The general-pool tax rate a household starts with when it adopts the
/// savings rules (onboarding and the Settings adopt switch).
const int kDefaultGeneralTithePct = 20;

/// The household's savings-economy rules: active from [fromMonth] (the
/// adoption month), with the general-pool tax rate as it stood each month.
/// Months before adoption keep the legacy math exactly.
class SavingsRules {
  const SavingsRules({
    required this.fromMonth,
    required this.generalPctByFromMonth,
  });

  final Month fromMonth;

  /// General rate keyed by the 'yyyy-MM' month it takes effect from.
  final Map<String, int> generalPctByFromMonth;

  bool appliesTo(Month month) => !month.isBefore(fromMonth);

  /// The general rate in force for [month]: the entry with the latest effective
  /// month ≤ [month] (the adoption entry's rate before any later change).
  int generalRateFor(Month month) {
    Month? best;
    for (final monthKey in generalPctByFromMonth.keys) {
      final effectiveMonth = Month.parse(monthKey);
      if (!effectiveMonth.isAfter(month) &&
          (best == null || effectiveMonth.isAfter(best))) {
        best = effectiveMonth;
      }
    }
    return generalPctByFromMonth[(best ?? fromMonth).toKey()] ?? 0;
  }
}
