/// The **budget change log** (audit view): a human-readable projection of the
/// *entire* event log. Unlike the activity feed — which deliberately hides
/// configuration noise and narrates only money moving — the change log shows
/// every event, because event sourcing IS the audit trail and nothing is ever
/// deletable. Corrections appear as their own compensating entries.
///
/// Pure Dart (Flutter-free): the view maps [ChangeLogKind] to an icon/tint.
library;

import '../../domain/event.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';
import '../../ui/format.dart';

/// The visual family of a change-log entry, used only to pick an icon/tint.
enum ChangeLogKind {
  purchase,
  correction,
  money,
  config,
  governance,
  receipt,
  cosmetic,
}

/// One line in the budget change log.
class ChangeLogEntry {
  const ChangeLogEntry({
    required this.eventId,
    required this.kind,
    required this.title,
    required this.occurredAt,
    required this.createdAt,
    required this.author,
    this.detail,
    this.amountCents,
  });

  final String eventId;
  final ChangeLogKind kind;
  final String title;
  final String? detail;
  final int? amountCents;

  /// The household-time the event is keyed to (user-editable).
  final DateTime occurredAt;

  /// When the event was actually recorded.
  final DateTime createdAt;

  /// Display name of the authoring member.
  final String author;
}

/// Builds the full change log, newest first. Every event type produces exactly
/// one entry — the log is complete and append-only, so it is the source the
/// "nothing here can be deleted" promise rests on.
List<ChangeLogEntry> buildChangeLog(
  HouseholdState state,
  List<Event> events, {
  required Map<String, String> userNames,
}) {
  String who(String id) => userNames[id] ?? 'Someone';
  String sliceName(String id) => state.slices[id]?.name ?? 'a category';
  String questName(String id) => state.quests[id]?.name ?? 'a goal';
  String fundName(String id) => state.emergencyFunds[id]?.name ?? 'a fund';
  String vacationName(String id) => state.vacations[id]?.name ?? 'a vacation';

  String targetLabel(ChargeTarget t) => switch (t) {
        SliceCharge(:final sliceId) => sliceName(sliceId),
        VaultCharge() => 'a vault',
        QuestCharge(:final questId) => questName(questId),
        EmergencyCharge(:final fundId) => fundName(fundId),
        VacationCharge(:final vacationId) => vacationName(vacationId),
      };

  final entries = <ChangeLogEntry>[];

  for (final e in events) {
    ChangeLogEntry entry(
      ChangeLogKind kind,
      String title, {
      String? detail,
      int? amountCents,
    }) =>
        ChangeLogEntry(
          eventId: e.eventId,
          kind: kind,
          title: title,
          detail: detail,
          amountCents: amountCents,
          occurredAt: e.occurredAt,
          createdAt: e.createdAt,
          author: who(e.userId),
        );

    entries.add(switch (e) {
      PurchaseAdded() => entry(
          ChangeLogKind.purchase,
          'Purchase on ${targetLabel(e.target)}',
          detail: [
            if (e.merchant != null) e.merchant,
            if (e.shared) 'shared',
            if (e.note != null) e.note,
          ].whereType<String>().join(' · ').ifEmptyNull(),
          amountCents: -e.amountCents,
        ),
      PurchaseVoided() => entry(
          ChangeLogKind.correction,
          'Voided a purchase',
          detail: 'correction — the original stays in the log',
        ),
      BudgetSliceSet() => entry(
          ChangeLogKind.config,
          'Set the "${e.name}" budget category',
          detail: 'limit ${money(e.limitCents)}'
              '${e.ownership is GroupSlice ? ' · group' : ''}',
        ),
      MainCategorySet() => entry(
          ChangeLogKind.config,
          'Set the "${e.name}" main category',
        ),
      RecurringExpenseSet() => entry(
          ChangeLogKind.config,
          'Set the "${e.name}" recurring expense',
          detail: '${money(e.amountCents)} · ${e.cadence.name}',
        ),
      VariableExpenseRecorded() => entry(
          ChangeLogKind.config,
          'Recorded a variable expense actual',
          detail: monthLabel(e.month.year, e.month.month),
          amountCents: -e.actualCents,
        ),
      IncomeSet() => entry(
          ChangeLogKind.money,
          'Set ${who(e.forUserId)}\'s income',
          detail: monthLabel(e.month.year, e.month.month),
          amountCents: e.amountCents,
        ),
      DefaultIncomeSet() => entry(
          ChangeLogKind.money,
          'Set ${who(e.forUserId)}\'s default income',
          detail:
              'from ${monthLabel(e.effectiveFromMonth.year, e.effectiveFromMonth.month)}',
          amountCents: e.amountCents,
        ),
      QuestSet() => entry(
          ChangeLogKind.config,
          'Set the "${e.name}" savings goal',
          detail: 'target ${money(e.targetCents)}',
        ),
      QuestAbandoned() => entry(
          ChangeLogKind.governance,
          'Abandoned ${questName(e.questId)}',
        ),
      LeftoverAllocated() => entry(
          ChangeLogKind.money,
          'Divided leftovers from ${sliceName(e.sliceId)}',
          detail: monthLabel(e.month.year, e.month.month),
          amountCents:
              e.allocations.fold<int>(0, (a, x) => a + x.amountCents),
        ),
      GiftReceived() => entry(
          ChangeLogKind.money,
          '${who(e.forUserId)} received a gift',
          detail: e.note,
          amountCents: e.amountCents,
        ),
      PoolContributionMade() => entry(
          ChangeLogKind.money,
          '${who(e.fromUserId)} fed the war chest',
          amountCents: e.amountCents,
        ),
      PoolWithdrawalProposed() => entry(
          ChangeLogKind.governance,
          '${who(e.byUserId)} proposed a war-chest withdrawal',
          detail: e.purpose,
          amountCents: -e.amountCents,
        ),
      PoolWithdrawalApproved() => entry(
          ChangeLogKind.governance,
          '${who(e.byUserId)} approved a withdrawal',
        ),
      PoolWithdrawalCancelled() => entry(
          ChangeLogKind.governance,
          'Cancelled a withdrawal',
        ),
      TaxRefundRecorded() => entry(
          ChangeLogKind.money,
          'Recorded a tax refund to the war chest',
          detail: e.note,
          amountCents: e.amountCents,
        ),
      EmergencyFundSet() => entry(
          ChangeLogKind.config,
          'Opened the "${e.name}" emergency fund',
        ),
      MemberSet() => entry(
          ChangeLogKind.config,
          e.active
              ? 'Added ${e.name} (${e.role.name}) to the party'
              : 'Retired ${e.name} from the party',
        ),
      PetSet() => entry(
          ChangeLogKind.config,
          'Added ${e.name} to the party',
        ),
      GroupShareSet() => entry(
          ChangeLogKind.config,
          'Set the group share split',
          detail: monthLabel(e.month.year, e.month.month),
        ),
      GoalSet() => entry(
          ChangeLogKind.config,
          'Set the war chest target',
          amountCents: e.targetCents,
        ),
      TrackedAccountSet() => entry(
          ChangeLogKind.config,
          'Set the "${e.name}" tracked account',
          detail: e.kind.name,
        ),
      AccountBalanceRecorded() => entry(
          ChangeLogKind.money,
          'Recorded ${e.accountName}\'s balance',
          amountCents: e.balanceCents,
        ),
      AccountTransferRecorded() => entry(
          ChangeLogKind.money,
          'Recorded an account ${e.direction.name}',
          detail: e.note,
          amountCents: e.direction == TransferDirection.deposit
              ? e.amountCents
              : -e.amountCents,
        ),
      SettingChanged() => entry(
          ChangeLogKind.config,
          'Changed a setting',
          detail: '${e.key} → ${e.value}',
        ),
      VacationSet() => entry(
          ChangeLogKind.config,
          'Set up the "${e.name}" vacation',
        ),
      VacationClosed() => entry(
          ChangeLogKind.config,
          'Closed ${vacationName(e.vacationId)}',
        ),
      ReceiptAttached() => entry(
          ChangeLogKind.receipt,
          'Attached a receipt',
        ),
      ReceiptDetached() => entry(
          ChangeLogKind.receipt,
          'Detached a receipt',
        ),
      CosmeticSet() => entry(
          ChangeLogKind.cosmetic,
          'Changed a cosmetic',
          detail: e.key,
        ),
      GameRewardGranted() => entry(
          ChangeLogKind.cosmetic,
          'Earned a reward',
          detail: e.rewardId,
        ),
    });
  }

  entries.sort((a, b) {
    final c = b.occurredAt.compareTo(a.occurredAt);
    return c != 0 ? c : b.eventId.compareTo(a.eventId);
  });
  return entries;
}

extension _EmptyToNull on String {
  String? ifEmptyNull() => isEmpty ? null : this;
}
