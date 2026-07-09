/// Pure model for war-chest governance: an itemized ledger of every flow into or
/// out of the shared pool, reconstructed from the derived state and the event log
/// using the same arithmetic as the reducer (so tithes and dissolution tithes
/// match to the cent).
library;

import '../../domain/event.dart';
import '../../domain/money.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';

/// The kind of a war-chest ledger line, for iconography and grouping.
enum ChestEntryKind {
  sliceTithe,
  dissolutionTithe,
  groupLeftover,
  contribution,
  taxRefund,
  withdrawal,
  ransack,
}

/// One line in the war-chest ledger. [amountCents] is signed: inflows positive,
/// withdrawals and ransacks negative.
class ChestEntry {
  const ChestEntry({
    required this.kind,
    required this.label,
    required this.amountCents,
    required this.occurredAt,
  });

  final ChestEntryKind kind;
  final String label;
  final int amountCents;
  final DateTime occurredAt;
}

/// Builds the war-chest ledger newest-first. [userNames] resolves ids to display
/// names for withdrawal/contribution labels.
List<ChestEntry> buildWarChestLedger(
  HouseholdState state,
  Iterable<Event> events, {
  required Map<String, String> userNames,
}) {
  final entries = <ChestEntry>[];
  String nameOf(String id) => userNames[id] ?? id;

  // Slice tithes: each Discretionary leftover line pays its slice's pool tithe.
  // Uses the slice's current tithe %, matching the reducer's read-time policy.
  for (final e in events.whereType<LeftoverAllocated>()) {
    final cfg = state.slices[e.sliceId];
    if (cfg == null) continue;
    for (final a in e.allocations) {
      if (a.destination is Discretionary) {
        final tithe = Money.titheCents(a.amountCents, cfg.poolTithePct).titheCents;
        if (tithe > 0) {
          entries.add(ChestEntry(
            kind: ChestEntryKind.sliceTithe,
            label: '${cfg.name} savings cut (${e.month.toKey()})',
            amountCents: tithe,
            occurredAt: e.occurredAt,
          ));
        }
      }
    }
  }

  // Dissolution tithes: on each abandoned quest, the tithe taken off the
  // pre-abandon balance (funded − drawn).
  final funded = <String, int>{};
  for (final e in events.whereType<LeftoverAllocated>()) {
    for (final a in e.allocations) {
      final d = a.destination;
      if (d is QuestDestination) {
        funded[d.questId] = (funded[d.questId] ?? 0) + a.amountCents;
      }
    }
  }
  final drawn = <String, int>{};
  for (final p in state.purchases.values) {
    if (p.voided) continue;
    final t = p.target;
    if (t is QuestCharge) {
      drawn[t.questId] = (drawn[t.questId] ?? 0) + p.amountCents;
    }
  }
  for (final e in events.whereType<QuestAbandoned>()) {
    final q = state.quests[e.questId];
    final pre = (funded[e.questId] ?? 0) - (drawn[e.questId] ?? 0);
    if (pre <= 0) continue;
    final tithe =
        Money.titheCents(pre, state.settings.dissolutionTithePct).titheCents;
    if (tithe > 0) {
      entries.add(ChestEntry(
        kind: ChestEntryKind.dissolutionTithe,
        label: '${q?.name ?? 'Goal'} cancellation fee',
        amountCents: tithe,
        occurredAt: e.occurredAt,
      ));
    }
  }

  // Group-slice leftovers flow entirely to the chest, once the month is closed.
  for (final sm in state.sliceMonths.values) {
    if (!sm.isGroup || !sm.resolved || sm.leftoverCents <= 0) continue;
    final cfg = state.slices[sm.sliceId];
    entries.add(ChestEntry(
      kind: ChestEntryKind.groupLeftover,
      label: '${cfg?.name ?? 'Group'} leftover (${sm.month.toKey()})',
      amountCents: sm.leftoverCents,
      occurredAt: sm.month.endInstantUtc(),
    ));
  }

  // Direct contributions from a vault.
  for (final e in events.whereType<PoolContributionMade>()) {
    entries.add(ChestEntry(
      kind: ChestEntryKind.contribution,
      label: '${nameOf(e.fromUserId)} contribution',
      amountCents: e.amountCents,
      occurredAt: e.occurredAt,
    ));
  }

  // Tax refunds (royal rebate).
  for (final e in events.whereType<TaxRefundRecorded>()) {
    entries.add(ChestEntry(
      kind: ChestEntryKind.taxRefund,
      label: e.note == null || e.note!.isEmpty
          ? 'Tax refund'
          : 'Tax refund — ${e.note}',
      amountCents: e.amountCents,
      occurredAt: e.occurredAt,
    ));
  }

  // Approved withdrawals (writs), as outflows.
  for (final w in state.withdrawals.values) {
    if (w.status != WithdrawalStatus.approved) continue;
    entries.add(ChestEntry(
      kind: ChestEntryKind.withdrawal,
      label: 'Withdrawal — ${w.purpose}',
      amountCents: -w.amountCents,
      occurredAt: _proposalInstant(events, w.proposalId),
    ));
  }

  // Ransacks: emergency overflow drawn from the chest.
  for (final r in state.ransacks) {
    final fund = state.emergencyFunds[r.fundId];
    entries.add(ChestEntry(
      kind: ChestEntryKind.ransack,
      label: 'Ransack — ${fund?.name ?? r.fundId}',
      amountCents: -r.excessCents,
      occurredAt: r.occurredAt,
    ));
  }

  entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return entries;
}

DateTime _proposalInstant(Iterable<Event> events, String proposalId) {
  for (final e in events) {
    if (e is PoolWithdrawalProposed && e.proposalId == proposalId) {
      return e.occurredAt;
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
