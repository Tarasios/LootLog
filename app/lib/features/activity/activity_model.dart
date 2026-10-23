/// The partner activity feed: the raw event log presented chronologically with
/// human attribution. This is a *projection of events*, not derived budget state
/// — it never computes balances, it just narrates what each adventurer did.
///
/// Pure Dart (Flutter-free): the view maps [ActivityKind] to an icon.
library;

import '../../domain/event.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';
import '../../ui/format.dart';
import '../../ui/glossary.dart';
import '../shared/classify_member_set.dart';

/// The visual family of an activity line, used only to pick an icon/tint.
enum ActivityKind {
  purchase,
  purchaseVoided,
  gift,
  quest,
  allocation,
  withdrawal,
  contribution,
  taxRefund,
  income,
  config,
}

/// One line in the activity feed.
class ActivityItem {
  const ActivityItem({
    required this.eventId,
    required this.kind,
    required this.userId,
    required this.title,
    required this.occurredAt,
    required this.isMine,
    this.subtitle,
    this.amountCents,
  });

  final String eventId;
  final ActivityKind kind;
  final String userId;
  final String title;
  final String? subtitle;
  final int? amountCents;
  final DateTime occurredAt;

  /// Whether the acting user is the device owner (for subtle self/partner tint).
  final bool isMine;
}

/// Builds the newest-first activity feed. Configuration noise (settings,
/// cosmetics, account balances, receipt attach/detach) is intentionally omitted;
/// the feed shows money moving and plans changing.
List<ActivityItem> buildActivityFeed(
  HouseholdState state,
  List<Event> events, {
  required Map<String, String> userNames,
  required String meUserId,
  int limit = 40,
  bool isAdventure = false,
}) {
  String who(String id) => userNames[id] ?? 'Someone';
  // Classic speaks plain budgeting English; Adventure keeps the flavor words.
  final withdrawal = Glossary.withdrawal.label(isAdventure: isAdventure);
  final vaultWord = Glossary.vaultLabel(
    isAdventure: isAdventure,
    savingsRules: state.savingsRules != null,
  );
  final goalWord = Glossary.quest.label(isAdventure: isAdventure);
  final party = Glossary.household.label(isAdventure: isAdventure);
  final supplies = Glossary.income.label(isAdventure: isAdventure);

  String sliceName(String id) => state.slices[id]?.name ?? 'a budget';
  String questName(String id) => state.quests[id]?.name ?? 'a $goalWord';
  String fundName(String id) => state.emergencyFunds[id]?.name ?? 'a fund';

  String vacationName(String id) => state.vacations[id]?.name ?? 'a vacation';

  String targetLabel(ChargeTarget target) => switch (target) {
    SliceCharge(:final sliceId) => sliceName(sliceId),
    VaultCharge() => 'their $vaultWord',
    QuestCharge(:final questId) => questName(questId),
    EmergencyCharge(:final fundId) => fundName(fundId),
    VacationCharge(:final vacationId) => vacationName(vacationId),
  };

  final items = <ActivityItem>[];
  // Tracks the last MemberSet seen per member while walking the (append-
  // ordered) log, so later events read as updates rather than adds.
  final lastMemberSet = <String, MemberSet>{};
  for (final event in events) {
    final mine = event.userId == meUserId;
    ActivityItem? item;
    switch (event) {
      case PurchaseAdded():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.purchase,
          userId: event.userId,
          title: '${who(event.userId)} spent on ${targetLabel(event.target)}',
          subtitle: [
            if (event.merchant != null) event.merchant,
            if (event.shared) 'shared',
          ].whereType<String>().join(' · ').ifEmptyNull(),
          amountCents: -event.amountCents,
          occurredAt: event.occurredAt,
          isMine: mine,
        );
      case PurchaseVoided():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.purchaseVoided,
          userId: event.userId,
          title: '${who(event.userId)} voided a purchase',
          occurredAt: event.occurredAt,
          isMine: mine,
        );
      case GiftReceived():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.gift,
          userId: event.userId,
          title: '${who(event.forUserId)} received a gift',
          subtitle: event.note,
          amountCents: event.amountCents,
          occurredAt: event.occurredAt,
          isMine: event.forUserId == meUserId,
        );
      case QuestSet():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.quest,
          userId: event.userId,
          title: '${who(event.userId)} set the $goalWord "${event.name}"',
          subtitle: 'target ${money(event.targetCents)}',
          occurredAt: event.occurredAt,
          isMine: mine,
        );
      case QuestAbandoned():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.quest,
          userId: event.userId,
          title: '${who(event.userId)} abandoned ${questName(event.questId)}',
          occurredAt: event.occurredAt,
          isMine: mine,
        );
      case LeftoverAllocated():
        final total = event.allocations.fold<int>(0, (sum, allocation) => sum + allocation.amountCents);
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.allocation,
          userId: event.userId,
          title:
              '${who(event.forUserId)} divided leftovers from ${sliceName(event.sliceId)}',
          subtitle: monthLabel(event.month.year, event.month.month),
          amountCents: total,
          occurredAt: event.occurredAt,
          isMine: event.forUserId == meUserId,
        );
      case ShortfallCovered():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.allocation,
          userId: event.userId,
          title: switch (event.source) {
            GeneralCover() =>
              '${who(event.userId)} covered part of a purchase from general savings',
            CategorySavingsCover() =>
              '${who(event.userId)} put category savings toward a goal purchase',
          },
          amountCents: -event.amountCents,
          occurredAt: event.occurredAt,
          isMine: event.userId == meUserId,
        );
      case AllowanceAdvanceProposed():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.withdrawal,
          userId: event.userId,
          title:
              '${who(event.byUserId)} asked to borrow from future months '
              '(${event.months} month${event.months == 1 ? '' : 's'})',
          amountCents: -event.amountCents,
          occurredAt: event.occurredAt,
          isMine: event.byUserId == meUserId,
        );
      case AllowanceAdvanceApproved():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.withdrawal,
          userId: event.userId,
          title: '${who(event.byUserId)} approved borrowing from future months',
          occurredAt: event.occurredAt,
          isMine: event.byUserId == meUserId,
        );
      case AllowanceAdvanceCancelled():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.withdrawal,
          userId: event.userId,
          title:
              '${who(event.userId)} cancelled a request to borrow from future '
              'months',
          occurredAt: event.occurredAt,
          isMine: event.userId == meUserId,
        );
      case PoolWithdrawalProposed():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.withdrawal,
          userId: event.userId,
          title: isAdventure
              ? '${who(event.byUserId)} proposed a war-chest writ'
              : '${who(event.byUserId)} proposed a $withdrawal',
          subtitle: event.purpose,
          amountCents: -event.amountCents,
          occurredAt: event.occurredAt,
          isMine: event.byUserId == meUserId,
        );
      case PoolWithdrawalApproved():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.withdrawal,
          userId: event.userId,
          title: isAdventure
              ? '${who(event.byUserId)} signed a writ'
              : '${who(event.byUserId)} approved a $withdrawal',
          occurredAt: event.occurredAt,
          isMine: event.byUserId == meUserId,
        );
      case PoolWithdrawalCancelled():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.withdrawal,
          userId: event.userId,
          title: '${who(event.userId)} cancelled a $withdrawal',
          occurredAt: event.occurredAt,
          isMine: mine,
        );
      case PoolContributionMade():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.contribution,
          userId: event.userId,
          title: isAdventure
              ? '${who(event.fromUserId)} fed the war chest'
              : '${who(event.fromUserId)} added to shared savings',
          amountCents: event.amountCents,
          occurredAt: event.occurredAt,
          isMine: event.fromUserId == meUserId,
        );
      case TaxRefundRecorded():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.taxRefund,
          userId: event.userId,
          title: isAdventure
              ? 'A royal rebate reached the war chest'
              : 'A tax refund went to shared savings',
          subtitle: event.note,
          amountCents: event.amountCents,
          occurredAt: event.occurredAt,
          isMine: mine,
        );
      case IncomeSet():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.income,
          userId: event.userId,
          title: '${Glossary.capitalize(supplies)} logged for ${who(event.forUserId)}',
          subtitle: monthLabel(event.month.year, event.month.month),
          amountCents: event.amountCents,
          occurredAt: event.occurredAt,
          isMine: event.forUserId == meUserId,
        );
      case DefaultIncomeSet():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.income,
          userId: event.userId,
          title: 'Standing $supplies set for ${who(event.forUserId)}',
          subtitle:
              'from ${monthLabel(event.effectiveFromMonth.year, event.effectiveFromMonth.month)}',
          amountCents: event.amountCents,
          occurredAt: event.occurredAt,
          isMine: event.forUserId == meUserId,
        );
      case BudgetSliceSet():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.config,
          userId: event.userId,
          title: '${who(event.userId)} set up the "${event.name}" budget',
          occurredAt: event.occurredAt,
          isMine: mine,
        );
      case RecurringExpenseSet():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.config,
          userId: event.userId,
          title: '${who(event.userId)} scheduled "${event.name}"',
          occurredAt: event.occurredAt,
          isMine: mine,
        );
      case EmergencyFundSet():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.config,
          userId: event.userId,
          title: '${who(event.userId)} opened the "${event.name}" '
              '${Glossary.emergencyFund.label(isAdventure: isAdventure)}',
          occurredAt: event.occurredAt,
          isMine: mine,
        );
      case PetSet():
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.config,
          userId: event.userId,
          title: '${who(event.userId)} added ${event.name} to the $party',
          occurredAt: event.occurredAt,
          isMine: mine,
        );
      case MemberSet():
        final prev = lastMemberSet[event.memberId];
        lastMemberSet[event.memberId] = event;
        final title = switch (classifyMemberSet(event, prev)) {
          MemberSetChange.retired =>
            '${who(event.userId)} retired ${event.name} from the $party',
          MemberSetChange.added =>
            '${who(event.userId)} added ${event.name} to the $party',
          MemberSetChange.portraitOnly =>
            "${who(event.userId)} updated ${event.name}'s portrait",
          MemberSetChange.updated => '${who(event.userId)} updated ${event.name}',
        };
        item = ActivityItem(
          eventId: event.eventId,
          kind: ActivityKind.config,
          userId: event.userId,
          title: title,
          occurredAt: event.occurredAt,
          isMine: mine,
        );
      // Deliberately silent: receipts, goals, accounts, settings, cosmetics,
      // share-table changes.
      case ReceiptAttached():
      case ReceiptDetached():
      case GoalSet():
      case GroupShareSet():
      case TrackedAccountSet():
      case AccountBalanceRecorded():
      case AccountTransferRecorded():
      case SettingChanged():
      case CosmeticSet():
      case GameRewardGranted():
      case NoSpendCheckedIn():
      case ReconcileCompleted():
      case UnknownEvent():
      case VariableExpenseRecorded():
      case MainCategorySet():
      case VacationSet():
      case VacationClosed():
        item = null;
    }
    if (item != null) {
      items.add(item);
    }
  }

  items.sort((first, second) {
    final comparison = second.occurredAt.compareTo(first.occurredAt);
    return comparison != 0 ? comparison : second.eventId.compareTo(first.eventId);
  });
  return items.length > limit ? items.sublist(0, limit) : items;
}

extension _EmptyToNull on String {
  String? ifEmptyNull() => isEmpty ? null : this;
}
