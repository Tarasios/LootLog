/// Pure helpers for the quests feature: the abandon preview (exact dissolution
/// tithe and per-funder returns, matching the reducer) and the per-quest funding
/// history derived from the event log.
library;

import '../../domain/event.dart';
import '../../domain/money.dart';
import '../../domain/value_types.dart';

/// The outcome the reducer would produce on abandoning a quest right now.
class AbandonPreview {
  const AbandonPreview({
    required this.balanceCents,
    required this.titheCents,
    required this.returnsByUser,
  });

  final int balanceCents;

  /// The dissolution tithe taken off the top into the war chest.
  final int titheCents;

  /// What each funder gets back, in proportion to their contributions.
  final Map<String, int> returnsByUser;

  int get totalReturnedCents =>
      returnsByUser.values.fold<int>(0, (a, b) => a + b);
}

/// Computes the abandon preview for a quest [balanceCents] funded by
/// [contributions], applying [dissolutionTithePct] the same way the reducer does
/// (floored tithe to the chest; the remainder split by largest-remainder so the
/// parts sum exactly).
AbandonPreview previewAbandon(
  int balanceCents,
  Map<String, int> contributions,
  int dissolutionTithePct,
) {
  if (balanceCents <= 0) {
    return AbandonPreview(
      balanceCents: 0,
      titheCents: 0,
      returnsByUser: {for (final k in contributions.keys) k: 0},
    );
  }
  final tithe = Money.titheCents(balanceCents, dissolutionTithePct).titheCents;
  final distributable = balanceCents - tithe;
  final returns = _proportional(distributable, contributions);
  return AbandonPreview(
    balanceCents: balanceCents,
    titheCents: tithe,
    returnsByUser: returns,
  );
}

/// One funding of a quest (a `QuestDestination` line in a `LeftoverAllocated`).
class QuestFunding {
  const QuestFunding({
    required this.userId,
    required this.month,
    required this.amountCents,
    required this.occurredAt,
  });

  final String userId;
  final String month;
  final int amountCents;
  final DateTime occurredAt;
}

/// Extracts the funding history for [questId] from the event log, newest first.
List<QuestFunding> questFundings(Iterable<Event> events, String questId) {
  final out = <QuestFunding>[];
  for (final e in events) {
    if (e is! LeftoverAllocated) continue;
    for (final a in e.allocations) {
      final dest = a.destination;
      if (dest is QuestDestination && dest.questId == questId) {
        out.add(QuestFunding(
          userId: e.forUserId,
          month: e.month.toKey(),
          amountCents: a.amountCents,
          occurredAt: e.occurredAt,
        ));
      }
    }
  }
  out.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return out;
}

/// Largest-remainder proportional split, identical to the reducer's, so the
/// preview and the applied result always agree.
Map<String, int> _proportional(int amount, Map<String, int> weights) {
  final totalWeight = weights.values.fold<int>(0, (a, b) => a + b);
  if (amount <= 0 || totalWeight <= 0) {
    return {for (final k in weights.keys) k: 0};
  }
  final base = <String, int>{};
  final remainders = <String, int>{};
  var assigned = 0;
  for (final entry in weights.entries) {
    final numerator = amount * entry.value;
    final share = numerator ~/ totalWeight;
    base[entry.key] = share;
    remainders[entry.key] = numerator % totalWeight;
    assigned += share;
  }
  var leftover = amount - assigned;
  final order = weights.keys.toList()
    ..sort((a, b) {
      final c = remainders[b]!.compareTo(remainders[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  for (final k in order) {
    if (leftover <= 0) break;
    base[k] = base[k]! + 1;
    leftover--;
  }
  return base;
}
