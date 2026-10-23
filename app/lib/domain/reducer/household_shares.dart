part of '../reducer.dart';

/// Who the household's ledger-bearing adults are, and how shared costs split
/// between them.
extension _HouseholdShares on _HouseholdStateBuilder {
  /// The ledger-bearing adults. Explicit active adult members win; absent any,
  /// every known user is treated as an adult (legacy / dependents-only history).
  Set<String> _adultIds() {
    final declared = {
      for (final member in memberConfigs.values)
        if (member.role == MemberRole.adult && member.active) member.memberId,
    };
    return declared.isNotEmpty ? declared : userIds;
  }

  bool _isAdult(String id) => _adultIds().contains(id);

  /// The permille weight per adult for shared costs in [month]: the latest share
  /// table with month ≤ [month] (carried forward), else an even split among the
  /// current adults.
  Map<String, int> _sharesFor(Month month) {
    GroupShareSet? best;
    for (final shareSet in shareSets.values) {
      if (!shareSet.month.isAfter(month) &&
          (best == null || shareSet.month.isAfter(best.month))) {
        best = shareSet;
      }
    }
    if (best != null && best.shares.isNotEmpty) {
      return best.shares;
    }
    return {for (final adultId in _adultIds()) adultId: 1};
  }
}

/// Splits [amount] across [weights] with floor rounding. Any leftover cents go
/// to [oddTo] (the purchaser) when given; otherwise they are distributed by
/// largest remainder so the parts always sum exactly to [amount].
Map<String, int> _splitShares(
  int amount,
  Map<String, int> weights, {
  String? oddTo,
}) {
  final totalWeight = weights.values.fold(0, (sum, weight) => sum + weight);
  if (amount == 0 || totalWeight <= 0) {
    return {?oddTo: amount};
  }
  final parts = <String, int>{};
  final remainders = <String, int>{};
  var assigned = 0;
  for (final entry in weights.entries) {
    final numerator = amount * entry.value;
    final share = numerator ~/ totalWeight;
    parts[entry.key] = share;
    remainders[entry.key] = numerator % totalWeight;
    assigned += share;
  }
  var leftover = amount - assigned;
  if (oddTo != null) {
    parts[oddTo] = (parts[oddTo] ?? 0) + leftover;
    return parts;
  }
  final byLargestRemainder = _keysByLargestRemainder(weights, remainders);
  var i = 0;
  while (leftover > 0 && byLargestRemainder.isNotEmpty) {
    final recipient = byLargestRemainder[i % byLargestRemainder.length];
    parts[recipient] = parts[recipient]! + 1;
    leftover--;
    i++;
  }
  return parts;
}

/// Splits [amount] across recipients proportionally to their [weights],
/// using largest-remainder so the parts sum exactly to [amount].
Map<String, int> _splitProportionally(int amount, Map<String, int> weights) {
  final totalWeight = weights.values.fold(0, (sum, weight) => sum + weight);
  if (amount <= 0 || totalWeight <= 0) {
    return {for (final recipient in weights.keys) recipient: 0};
  }
  final parts = <String, int>{};
  final remainders = <String, int>{}; // numerator of the fractional part
  var assigned = 0;
  for (final entry in weights.entries) {
    final numerator = amount * entry.value;
    final share = numerator ~/ totalWeight;
    parts[entry.key] = share;
    remainders[entry.key] = numerator % totalWeight;
    assigned += share;
  }
  var leftover = amount - assigned;
  for (final recipient in _keysByLargestRemainder(weights, remainders)) {
    if (leftover <= 0) {
      break;
    }
    parts[recipient] = parts[recipient]! + 1;
    leftover--;
  }
  return parts;
}

/// The keys of [weights] ordered by descending fractional [remainders], ties
/// broken by key so the order is deterministic.
List<String> _keysByLargestRemainder(
  Map<String, int> weights,
  Map<String, int> remainders,
) {
  return weights.keys.toList()..sort((first, second) {
    final byRemainder = remainders[second]!.compareTo(remainders[first]!);
    return byRemainder != 0 ? byRemainder : first.compareTo(second);
  });
}
