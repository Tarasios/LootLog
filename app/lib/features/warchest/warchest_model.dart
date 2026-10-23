/// Pure model for war-chest governance: an itemized ledger of every flow into or
/// out of the shared pool, reconstructed from the derived state and the event log
/// using the same arithmetic as the reducer (so tithes and dissolution tithes
/// match to the cent).
library;

import '../../domain/event.dart';
import '../../domain/money.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';
import '../../ui/glossary.dart';

String _cap(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

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
  bool isAdventure = false,
}) {
  final entries = <ChestEntry>[];
  String nameOf(String id) => userNames[id] ?? id;

  // Slice tithes: each Discretionary leftover line pays its slice's pool tithe.
  // Uses the slice's current tithe %, matching the reducer's read-time policy.
  for (final event in events.whereType<LeftoverAllocated>()) {
    final sliceConfig = state.slices[event.sliceId];
    if (sliceConfig == null) continue;
    for (final allocation in event.allocations) {
      if (allocation.destination is Discretionary) {
        final tithe = Money.titheCents(
          allocation.amountCents,
          sliceConfig.poolTithePct,
        ).titheCents;
        if (tithe > 0) {
          entries.add(
            ChestEntry(
              kind: ChestEntryKind.sliceTithe,
              label: '${sliceConfig.name} savings cut (${event.month.toKey()})',
              amountCents: tithe,
              occurredAt: event.occurredAt,
            ),
          );
        }
      }
    }
  }

  // Dissolution tithes: on each abandoned quest, the tithe taken off the
  // pre-abandon balance (funded − drawn).
  final funded = <String, int>{};
  for (final event in events.whereType<LeftoverAllocated>()) {
    for (final allocation in event.allocations) {
      final destination = allocation.destination;
      if (destination is QuestDestination) {
        funded[destination.questId] = (funded[destination.questId] ?? 0) + allocation.amountCents;
      }
    }
  }
  final drawn = <String, int>{};
  for (final purchase in state.purchases.values) {
    if (purchase.voided) continue;
    final target = purchase.target;
    if (target is QuestCharge) {
      drawn[target.questId] = (drawn[target.questId] ?? 0) + purchase.amountCents;
    }
  }
  for (final event in events.whereType<QuestAbandoned>()) {
    final quest = state.quests[event.questId];
    final balanceBefore = (funded[event.questId] ?? 0) - (drawn[event.questId] ?? 0);
    if (balanceBefore <= 0) continue;
    final tithe = Money.titheCents(
      balanceBefore,
      state.settings.dissolutionTithePct,
    ).titheCents;
    if (tithe > 0) {
      entries.add(
        ChestEntry(
          kind: ChestEntryKind.dissolutionTithe,
          label: '${quest?.name ?? 'Goal'} cancellation fee',
          amountCents: tithe,
          occurredAt: event.occurredAt,
        ),
      );
    }
  }

  // Group-slice leftovers flow entirely to the chest, once the month is closed.
  for (final sliceMonth in state.sliceMonths.values) {
    if (!sliceMonth.isGroup || !sliceMonth.resolved || sliceMonth.leftoverCents <= 0) continue;
    final sliceConfig = state.slices[sliceMonth.sliceId];
    entries.add(
      ChestEntry(
        kind: ChestEntryKind.groupLeftover,
        label: '${sliceConfig?.name ?? 'Group'} leftover (${sliceMonth.month.toKey()})',
        amountCents: sliceMonth.leftoverCents,
        occurredAt: sliceMonth.month.endInstantUtc(),
      ),
    );
  }

  // Direct contributions from a vault.
  for (final event in events.whereType<PoolContributionMade>()) {
    entries.add(
      ChestEntry(
        kind: ChestEntryKind.contribution,
        label: '${nameOf(event.fromUserId)} contribution',
        amountCents: event.amountCents,
        occurredAt: event.occurredAt,
      ),
    );
  }

  // Tax refunds (royal rebate).
  for (final event in events.whereType<TaxRefundRecorded>()) {
    entries.add(
      ChestEntry(
        kind: ChestEntryKind.taxRefund,
        label: event.note == null || event.note!.isEmpty
            ? 'Tax refund'
            : 'Tax refund — ${event.note}',
        amountCents: event.amountCents,
        occurredAt: event.occurredAt,
      ),
    );
  }

  // Approved withdrawals (writs), as outflows.
  for (final withdrawal in state.withdrawals.values) {
    if (withdrawal.status != WithdrawalStatus.approved) continue;
    entries.add(
      ChestEntry(
        kind: ChestEntryKind.withdrawal,
        label: 'Withdrawal — ${withdrawal.purpose}',
        amountCents: -withdrawal.amountCents,
        occurredAt: _proposalInstant(events, withdrawal.proposalId),
      ),
    );
  }

  // Ransacks: emergency overflow drawn from the chest.
  for (final ransack in state.ransacks) {
    final fund = state.emergencyFunds[ransack.fundId];
    entries.add(
      ChestEntry(
        kind: ChestEntryKind.ransack,
        label: '${_cap(Glossary.ransack.label(isAdventure: isAdventure))} — '
            '${fund?.name ?? ransack.fundId}',
        amountCents: -ransack.excessCents,
        occurredAt: ransack.occurredAt,
      ),
    );
  }

  entries.sort((first, second) => second.occurredAt.compareTo(first.occurredAt));
  return entries;
}

DateTime _proposalInstant(Iterable<Event> events, String proposalId) {
  for (final event in events) {
    if (event is PoolWithdrawalProposed && event.proposalId == proposalId) {
      return event.occurredAt;
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
