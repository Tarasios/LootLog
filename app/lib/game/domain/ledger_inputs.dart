/// The small, money-free facts the game reads off the ledger: which days a
/// person showed up, and which months they saved something. Counts and
/// months only — never an amount — so nothing here can turn a dollar figure
/// into a reward (rule 8).
///
/// Pure Dart, zero Flutter imports.
library;

import '../../domain/event.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';
import 'game_values.dart';

/// The household-local days in [month] on which [personId] logged a new
/// purchase or checked in "no spend today". Keyed by when the entry was
/// logged (`createdAt`): showing up is the habit being counted.
int loggedDaysInMonth(Iterable<Event> ledger, String personId, Month month) {
  final days = <GameDay>{};
  for (final e in ledger) {
    if (e.userId != personId) continue;
    final counts = switch (e) {
      PurchaseAdded(amendsPurchaseId: null) => true,
      NoSpendCheckedIn() => true,
      _ => false,
    };
    if (!counts) continue;
    if (Month.fromInstant(e.createdAt) != month) continue;
    days.add(GameDay.fromInstant(e.createdAt));
  }
  return days.length;
}

/// The months for which [personId] chose to save some leftover: their latest
/// `LeftoverAllocated` for a (category, month) has a positive line going
/// anywhere but an OVERBUDGET payment (carry or save in the category,
/// general savings, a quest). Only explicit choices count; a grace-period
/// default is not a choice.
Set<Month> savingsAllocationMonths(Iterable<Event> ledger, String personId) {
  final latest = <String, LeftoverAllocated>{};
  for (final e in ledger) {
    if (e is! LeftoverAllocated || e.forUserId != personId) continue;
    final key = '${e.sliceId}|${e.month.toKey()}';
    final prior = latest[key];
    if (prior == null || _orders(prior, e)) latest[key] = e;
  }
  return {
    for (final e in latest.values)
      if (e.allocations.any((a) =>
          a.amountCents > 0 && a.destination is! OverbudgetPayment))
        e.month,
  };
}

/// Whether [a] comes before [b] in canonical (occurredAt, eventId) order.
bool _orders(Event a, Event b) {
  final byTime = a.occurredAt.compareTo(b.occurredAt);
  return byTime != 0 ? byTime < 0 : a.eventId.compareTo(b.eventId) < 0;
}
