/// Tax-on-move math for savings pools — the single place it lives.
///
/// Every pool balance remembers how much tax its money has already paid, so a
/// move only charges the difference between the destination's rate and what
/// was already paid ("taxed once, then only the difference"). Pure Dart.
library;

/// A pool balance and the tax its money has already paid.
class TaxedBalance {
  const TaxedBalance(this.balanceCents, [this.taxPaidCents = 0]);

  static const zero = TaxedBalance(0);

  final int balanceCents;
  final int taxPaidCents;

  TaxedBalance operator +(TaxedBalance other) => TaxedBalance(
    balanceCents + other.balanceCents,
    taxPaidCents + other.taxPaidCents,
  );

  @override
  bool operator ==(Object other) =>
      other is TaxedBalance &&
      other.balanceCents == balanceCents &&
      other.taxPaidCents == taxPaidCents;

  @override
  int get hashCode => Object.hash(balanceCents, taxPaidCents);

  @override
  String toString() => 'TaxedBalance($balanceCents, paid $taxPaidCents)';
}

/// The outcome of moving money out of a pool.
class MoveResult {
  const MoveResult({
    required this.remaining,
    required this.delivered,
    required this.topUpCents,
  });

  /// What stays in the source pool.
  final TaxedBalance remaining;

  /// What lands in the destination, with the tax it has now paid.
  final TaxedBalance delivered;

  /// Tax charged by this move (goes to the war chest).
  final int topUpCents;
}

int _paidShare(TaxedBalance from, int amount) => from.balanceCents == 0
    ? 0
    : from.taxPaidCents * amount ~/ from.balanceCents;

/// Moves [amountCents] (0 ≤ amount ≤ balance) out of [from] to a destination
/// taxed at [destRatePct]. The moved money's pre-tax value is its amount plus
/// its share of tax already paid; the destination rate applies to that value,
/// minus what was already paid. Never refunds. `delivered + topUp == amount`.
MoveResult moveTaxed(TaxedBalance from, int amountCents, int destRatePct) {
  assert(amountCents >= 0 && amountCents <= from.balanceCents);
  final paid = _paidShare(from, amountCents);
  final gross = amountCents + paid;
  final owed = gross * destRatePct ~/ 100;
  var topUp = owed - paid;
  if (topUp < 0) topUp = 0;
  if (topUp > amountCents) topUp = amountCents;
  return MoveResult(
    remaining: TaxedBalance(
      from.balanceCents - amountCents,
      from.taxPaidCents - paid,
    ),
    delivered: TaxedBalance(amountCents - topUp, paid + topUp),
    topUpCents: topUp,
  );
}

/// Spends [amountCents] (≤ balance) from [from]: the balance drops and the
/// spent money's share of tax paid leaves with it.
TaxedBalance spendFrom(TaxedBalance from, int amountCents) {
  assert(amountCents >= 0 && amountCents <= from.balanceCents);
  final paid = _paidShare(from, amountCents);
  return TaxedBalance(
    from.balanceCents - amountCents,
    from.taxPaidCents - paid,
  );
}

/// The smallest amount to move out of [from] so at least
/// [targetDeliveredCents] lands at a destination taxed at [destRatePct];
/// the whole balance when the target is out of reach. Delivery is
/// non-decreasing in the amount moved, so a binary search is exact.
int grossToDeliver(
  TaxedBalance from,
  int targetDeliveredCents,
  int destRatePct,
) {
  if (targetDeliveredCents <= 0) return 0;
  int delivered(int x) =>
      moveTaxed(from, x, destRatePct).delivered.balanceCents;
  if (delivered(from.balanceCents) < targetDeliveredCents) {
    return from.balanceCents;
  }
  var lo = 0;
  var hi = from.balanceCents;
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (delivered(mid) >= targetDeliveredCents) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  return lo;
}

/// An advance of [amountCents] repaid over [months] (≥ 1): an even split with
/// the remainder cents in the first month.
List<int> advanceTrimSchedule(int amountCents, int months) {
  final n = months < 1 ? 1 : months;
  final base = amountCents ~/ n;
  final rem = amountCents - base * n;
  return [for (var i = 0; i < n; i++) base + (i == 0 ? rem : 0)];
}
