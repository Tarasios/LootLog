/// Pure model for the net-worth feature: per-account balance history (for the
/// sparklines) reconstructed from the event log, with the latest name/kind
/// winning. The signed total comes straight from [HouseholdState.netWorth].
library;

import '../../domain/event.dart';
import '../../domain/value_types.dart';

/// One dated balance sample.
class BalancePoint {
  const BalancePoint({required this.at, required this.balanceCents});
  final DateTime at;
  final int balanceCents;
}

/// The full recorded history of one manual account.
class AccountHistory {
  const AccountHistory({
    required this.accountId,
    required this.name,
    required this.kind,
    required this.points,
  });

  final String accountId;
  final String name;
  final AccountKind kind;

  /// Balance samples in chronological order.
  final List<BalancePoint> points;

  int get latestCents => points.isEmpty ? 0 : points.last.balanceCents;

  int get signedLatestCents =>
      kind == AccountKind.debt ? -latestCents : latestCents;
}

/// Builds per-account histories from the log, ordered chronologically within
/// each account and returned sorted by account name.
List<AccountHistory> buildAccountHistories(Iterable<Event> events) {
  final byAccount = <String, List<AccountBalanceRecorded>>{};
  for (final e in events) {
    if (e is AccountBalanceRecorded) {
      byAccount.putIfAbsent(e.accountId, () => []).add(e);
    }
  }
  final out = <AccountHistory>[];
  for (final entry in byAccount.entries) {
    final recs = entry.value
      ..sort((a, b) {
        final c = a.occurredAt.compareTo(b.occurredAt);
        return c != 0 ? c : a.eventId.compareTo(b.eventId);
      });
    final latest = recs.last;
    out.add(AccountHistory(
      accountId: entry.key,
      name: latest.accountName,
      kind: latest.kind,
      points: [
        for (final r in recs)
          BalancePoint(at: r.occurredAt, balanceCents: r.balanceCents),
      ],
    ));
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}
