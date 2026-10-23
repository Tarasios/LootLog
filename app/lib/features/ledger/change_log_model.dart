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
import '../../ui/glossary.dart';
import '../shared/classify_member_set.dart';

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
  bool isAdventure = false,
}) {
  String who(String id) => userNames[id] ?? 'Someone';
  // Classic speaks plain budgeting English; Adventure keeps the flavor words.
  final chest = Glossary.warChest.label(isAdventure: isAdventure);
  final party = Glossary.household.label(isAdventure: isAdventure);
  final vaultWord = Glossary.vaultLabel(
    isAdventure: isAdventure,
    savingsRules: state.savingsRules != null,
  );
  String sliceName(String id) => state.slices[id]?.name ?? 'a category';
  String questName(String id) => state.quests[id]?.name ?? 'a goal';
  String fundName(String id) => state.emergencyFunds[id]?.name ?? 'a fund';
  String vacationName(String id) => state.vacations[id]?.name ?? 'a vacation';

  String targetLabel(ChargeTarget target) => switch (target) {
        SliceCharge(:final sliceId) => sliceName(sliceId),
        VaultCharge() => vaultWord,
        QuestCharge(:final questId) => questName(questId),
        EmergencyCharge(:final fundId) => fundName(fundId),
        VacationCharge(:final vacationId) => vacationName(vacationId),
      };

  final entries = <ChangeLogEntry>[];
  // Tracks the last MemberSet seen per member while walking the (append-
  // ordered) log, so later events read as updates rather than adds.
  final lastMemberSet = <String, MemberSet>{};

  for (final event in events) {
    ChangeLogEntry entry(
      ChangeLogKind kind,
      String title, {
      String? detail,
      int? amountCents,
    }) =>
        ChangeLogEntry(
          eventId: event.eventId,
          kind: kind,
          title: title,
          detail: detail,
          amountCents: amountCents,
          occurredAt: event.occurredAt,
          createdAt: event.createdAt,
          author: who(event.userId),
        );

    entries.add(switch (event) {
      PurchaseAdded() => entry(
          ChangeLogKind.purchase,
          'Purchase on ${targetLabel(event.target)}',
          detail: [
            if (event.merchant != null) event.merchant,
            if (event.shared) 'shared',
            if (event.note != null) event.note,
          ].whereType<String>().join(' · ').ifEmptyNull(),
          amountCents: -event.amountCents,
        ),
      PurchaseVoided() => entry(
          ChangeLogKind.correction,
          'Voided a purchase',
          detail: 'correction — the original stays in the log',
        ),
      BudgetSliceSet() => entry(
          ChangeLogKind.config,
          'Set the "${event.name}" budget category',
          detail: 'limit ${money(event.limitCents)}'
              '${event.ownership is GroupSlice ? ' · group' : ''}',
        ),
      MainCategorySet() => entry(
          ChangeLogKind.config,
          'Set the "${event.name}" main category',
        ),
      RecurringExpenseSet() => entry(
          ChangeLogKind.config,
          'Set the "${event.name}" recurring expense',
          detail: '${money(event.amountCents)} · ${event.cadence.name}',
        ),
      VariableExpenseRecorded() => entry(
          ChangeLogKind.config,
          'Recorded a variable expense actual',
          detail: monthLabel(event.month.year, event.month.month),
          amountCents: -event.actualCents,
        ),
      IncomeSet() => entry(
          ChangeLogKind.money,
          'Set ${who(event.forUserId)}\'s income',
          detail: monthLabel(event.month.year, event.month.month),
          amountCents: event.amountCents,
        ),
      DefaultIncomeSet() => entry(
          ChangeLogKind.money,
          'Set ${who(event.forUserId)}\'s default income',
          detail:
              'from ${monthLabel(event.effectiveFromMonth.year, event.effectiveFromMonth.month)}',
          amountCents: event.amountCents,
        ),
      QuestSet() => entry(
          ChangeLogKind.config,
          'Set the "${event.name}" savings goal',
          detail: 'target ${money(event.targetCents)}',
        ),
      QuestAbandoned() => entry(
          ChangeLogKind.governance,
          'Abandoned ${questName(event.questId)}',
        ),
      LeftoverAllocated() => entry(
          ChangeLogKind.money,
          'Divided leftovers from ${sliceName(event.sliceId)}',
          detail: monthLabel(event.month.year, event.month.month),
          amountCents:
              event.allocations.fold<int>(0, (sum, allocation) => sum + allocation.amountCents),
        ),
      GiftReceived() => entry(
          ChangeLogKind.money,
          '${who(event.forUserId)} received a gift',
          detail: event.note,
          amountCents: event.amountCents,
        ),
      PoolContributionMade() => entry(
          ChangeLogKind.money,
          isAdventure
              ? '${who(event.fromUserId)} fed the war chest'
              : '${who(event.fromUserId)} added to shared savings',
          amountCents: event.amountCents,
        ),
      PoolWithdrawalProposed() => entry(
          ChangeLogKind.governance,
          '${who(event.byUserId)} proposed a '
          '${Glossary.withdrawal.label(isAdventure: isAdventure)}',
          detail: event.purpose,
          amountCents: -event.amountCents,
        ),
      PoolWithdrawalApproved() => entry(
          ChangeLogKind.governance,
          '${who(event.byUserId)} approved a withdrawal',
        ),
      PoolWithdrawalCancelled() => entry(
          ChangeLogKind.governance,
          'Cancelled a withdrawal',
        ),
      ShortfallCovered() => entry(
          ChangeLogKind.money,
          switch (event.source) {
            GeneralCover() =>
              '${who(event.userId)} covered part of a purchase from general savings',
            CategorySavingsCover() =>
              '${who(event.userId)} put category savings toward a goal purchase',
          },
          amountCents: -event.amountCents,
        ),
      AllowanceAdvanceProposed() => entry(
          ChangeLogKind.governance,
          '${who(event.byUserId)} asked to borrow from future months '
          '(${event.months} month${event.months == 1 ? '' : 's'})',
          amountCents: -event.amountCents,
        ),
      AllowanceAdvanceApproved() => entry(
          ChangeLogKind.governance,
          '${who(event.byUserId)} approved borrowing from future months',
        ),
      AllowanceAdvanceCancelled() => entry(
          ChangeLogKind.governance,
          'Cancelled a request to borrow from future months',
        ),
      TaxRefundRecorded() => entry(
          ChangeLogKind.money,
          'Recorded a tax refund to $chest',
          detail: event.note,
          amountCents: event.amountCents,
        ),
      EmergencyFundSet() => entry(
          ChangeLogKind.config,
          'Opened the "${event.name}" emergency fund',
        ),
      MemberSet() => entry(
          ChangeLogKind.config,
          () {
            final prev = lastMemberSet[event.memberId];
            lastMemberSet[event.memberId] = event;
            return switch (classifyMemberSet(event, prev)) {
              MemberSetChange.retired => 'Retired ${event.name} from the $party',
              MemberSetChange.added =>
                'Added ${event.name} (${event.role.name}) to the $party',
              MemberSetChange.portraitOnly => "Updated ${event.name}'s portrait",
              MemberSetChange.updated => 'Updated ${event.name} (${event.role.name})',
            };
          }(),
        ),
      PetSet() => entry(
          ChangeLogKind.config,
          'Added ${event.name} to the $party',
        ),
      GroupShareSet() => entry(
          ChangeLogKind.config,
          'Set the group share split',
          detail: monthLabel(event.month.year, event.month.month),
        ),
      GoalSet() => entry(
          ChangeLogKind.config,
          'Set the $chest target',
          amountCents: event.targetCents,
        ),
      TrackedAccountSet() => entry(
          ChangeLogKind.config,
          'Set the "${event.name}" tracked account',
          detail: event.kind.name,
        ),
      AccountBalanceRecorded() => entry(
          ChangeLogKind.money,
          'Recorded ${event.accountName}\'s balance',
          amountCents: event.balanceCents,
        ),
      AccountTransferRecorded() => entry(
          ChangeLogKind.money,
          'Recorded an account ${event.direction.name}',
          detail: event.note,
          amountCents: event.direction == TransferDirection.deposit
              ? event.amountCents
              : -event.amountCents,
        ),
      SettingChanged() => entry(
          ChangeLogKind.config,
          'Changed a setting',
          detail: '${event.key} → ${event.value}',
        ),
      VacationSet() => entry(
          ChangeLogKind.config,
          'Set up the "${event.name}" vacation',
        ),
      VacationClosed() => entry(
          ChangeLogKind.config,
          'Closed ${vacationName(event.vacationId)}',
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
          detail: event.key,
        ),
      GameRewardGranted() => entry(
          ChangeLogKind.cosmetic,
          'Earned a reward',
          detail: event.rewardId,
        ),
      NoSpendCheckedIn() => entry(
          ChangeLogKind.purchase,
          'Checked in: nothing spent today',
        ),
      ReconcileCompleted() => entry(
          ChangeLogKind.governance,
          'Reconciled the week of ${event.weekStart.toKey()}',
        ),
      // Written by a newer version of LootLog; kept and synced untouched.
      UnknownEvent() => entry(
          ChangeLogKind.config,
          'Recorded a change from a newer version of LootLog',
          detail: event.rawType,
        ),
    });
  }

  entries.sort((first, second) {
    final comparison = second.occurredAt.compareTo(first.occurredAt);
    return comparison != 0 ? comparison : second.eventId.compareTo(first.eventId);
  });
  return entries;
}

extension _EmptyToNull on String {
  String? ifEmptyNull() => isEmpty ? null : this;
}
