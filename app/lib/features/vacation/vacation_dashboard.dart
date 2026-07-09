/// Pure view-model helpers for the vacation dashboard. The heavy lifting — spend
/// per category, totals, fund balance, days remaining, daily allowance — is
/// already derived by the reducer and carried on [VacationState]; these helpers
/// only turn that state into the human-readable warnings the dashboard shows, so
/// the strings stay unit-testable away from any widget.
library;

import '../../domain/money.dart';
import '../../domain/state.dart';

String _money(int cents) => '\$${Money(cents).format()}';

/// The warnings to surface for a vacation, most urgent first: over the total
/// trip budget, then over any single category, then an over-provisioned fund.
/// Empty when the trip is comfortably within budget.
List<String> vacationWarnings(VacationState v) {
  final warnings = <String>[];
  if (v.overspent) {
    warnings.add('Over trip budget by ${_money(v.totalOverspendCents)}');
  }
  for (final c in v.categories) {
    if (c.overspent) {
      warnings.add('${c.name} over by ${_money(c.overspendCents)}');
    }
  }
  if (v.fundBalanceCents < 0) {
    warnings.add(
      'Reserving ${_money(-v.fundBalanceCents)} more than the fund holds',
    );
  }
  return warnings;
}

/// A short line describing how much can still be spent per day for the rest of
/// the trip, e.g. `"$120.00/day for 6 more days"`. Falls back gracefully once
/// the trip is over or the budget is exhausted.
String dailyAllowanceLabel(VacationState v) {
  if (v.daysRemaining <= 0) {
    return 'Trip over';
  }
  if (v.totalLeftoverCents <= 0) {
    return 'Budget spent — ${_money(0)}/day left';
  }
  final days = v.daysRemaining == 1 ? '1 more day' : '${v.daysRemaining} more days';
  return '${_money(v.dailyAllowanceRemainingCents)}/day for $days';
}
