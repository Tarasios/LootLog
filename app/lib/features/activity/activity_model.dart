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
}) {
  String who(String id) => userNames[id] ?? 'Someone';

  String sliceName(String id) => state.slices[id]?.name ?? 'a budget';
  String questName(String id) => state.quests[id]?.name ?? 'a quest';
  String fundName(String id) => state.emergencyFunds[id]?.name ?? 'a fund';

  String vacationName(String id) => state.vacations[id]?.name ?? 'a vacation';

  String targetLabel(ChargeTarget t) => switch (t) {
        SliceCharge(:final sliceId) => sliceName(sliceId),
        VaultCharge() => 'their vault',
        QuestCharge(:final questId) => questName(questId),
        EmergencyCharge(:final fundId) => fundName(fundId),
        VacationCharge(:final vacationId) => vacationName(vacationId),
      };

  final items = <ActivityItem>[];
  // Tracks the last MemberSet seen per member while walking the (append-
  // ordered) log, so later events read as updates rather than adds.
  final lastMemberSet = <String, MemberSet>{};
  for (final e in events) {
    final mine = e.userId == meUserId;
    ActivityItem? item;
    switch (e) {
      case PurchaseAdded():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.purchase,
          userId: e.userId,
          title: '${who(e.userId)} spent on ${targetLabel(e.target)}',
          subtitle: [
            if (e.merchant != null) e.merchant,
            if (e.shared) 'shared',
          ].whereType<String>().join(' · ').ifEmptyNull(),
          amountCents: -e.amountCents,
          occurredAt: e.occurredAt,
          isMine: mine,
        );
      case PurchaseVoided():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.purchaseVoided,
          userId: e.userId,
          title: '${who(e.userId)} voided a purchase',
          occurredAt: e.occurredAt,
          isMine: mine,
        );
      case GiftReceived():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.gift,
          userId: e.userId,
          title: '${who(e.forUserId)} received a gift',
          subtitle: e.note,
          amountCents: e.amountCents,
          occurredAt: e.occurredAt,
          isMine: e.forUserId == meUserId,
        );
      case QuestSet():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.quest,
          userId: e.userId,
          title: '${who(e.userId)} set the quest "${e.name}"',
          subtitle: 'target ${money(e.targetCents)}',
          occurredAt: e.occurredAt,
          isMine: mine,
        );
      case QuestAbandoned():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.quest,
          userId: e.userId,
          title: '${who(e.userId)} abandoned ${questName(e.questId)}',
          occurredAt: e.occurredAt,
          isMine: mine,
        );
      case LeftoverAllocated():
        final total =
            e.allocations.fold<int>(0, (a, x) => a + x.amountCents);
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.allocation,
          userId: e.userId,
          title:
              '${who(e.forUserId)} divided leftovers from ${sliceName(e.sliceId)}',
          subtitle: monthLabel(e.month.year, e.month.month),
          amountCents: total,
          occurredAt: e.occurredAt,
          isMine: e.forUserId == meUserId,
        );
      case PoolWithdrawalProposed():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.withdrawal,
          userId: e.userId,
          title: '${who(e.byUserId)} proposed a war-chest writ',
          subtitle: e.purpose,
          amountCents: -e.amountCents,
          occurredAt: e.occurredAt,
          isMine: e.byUserId == meUserId,
        );
      case PoolWithdrawalApproved():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.withdrawal,
          userId: e.userId,
          title: '${who(e.byUserId)} signed a writ',
          occurredAt: e.occurredAt,
          isMine: e.byUserId == meUserId,
        );
      case PoolWithdrawalCancelled():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.withdrawal,
          userId: e.userId,
          title: '${who(e.userId)} cancelled a writ',
          occurredAt: e.occurredAt,
          isMine: mine,
        );
      case PoolContributionMade():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.contribution,
          userId: e.userId,
          title: '${who(e.fromUserId)} fed the war chest',
          amountCents: e.amountCents,
          occurredAt: e.occurredAt,
          isMine: e.fromUserId == meUserId,
        );
      case TaxRefundRecorded():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.taxRefund,
          userId: e.userId,
          title: 'A royal rebate reached the war chest',
          subtitle: e.note,
          amountCents: e.amountCents,
          occurredAt: e.occurredAt,
          isMine: mine,
        );
      case IncomeSet():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.income,
          userId: e.userId,
          title: 'Expedition supplies logged for ${who(e.forUserId)}',
          subtitle: monthLabel(e.month.year, e.month.month),
          amountCents: e.amountCents,
          occurredAt: e.occurredAt,
          isMine: e.forUserId == meUserId,
        );
      case DefaultIncomeSet():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.income,
          userId: e.userId,
          title: 'Standing expedition supplies set for ${who(e.forUserId)}',
          subtitle:
              'from ${monthLabel(e.effectiveFromMonth.year, e.effectiveFromMonth.month)}',
          amountCents: e.amountCents,
          occurredAt: e.occurredAt,
          isMine: e.forUserId == meUserId,
        );
      case BudgetSliceSet():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.config,
          userId: e.userId,
          title: '${who(e.userId)} set up the "${e.name}" budget',
          occurredAt: e.occurredAt,
          isMine: mine,
        );
      case RecurringExpenseSet():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.config,
          userId: e.userId,
          title: '${who(e.userId)} scheduled "${e.name}"',
          occurredAt: e.occurredAt,
          isMine: mine,
        );
      case EmergencyFundSet():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.config,
          userId: e.userId,
          title: '${who(e.userId)} opened the "${e.name}" reserve',
          occurredAt: e.occurredAt,
          isMine: mine,
        );
      case PetSet():
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.config,
          userId: e.userId,
          title: '${who(e.userId)} added ${e.name} to the party',
          occurredAt: e.occurredAt,
          isMine: mine,
        );
      case MemberSet():
        final prev = lastMemberSet[e.memberId];
        lastMemberSet[e.memberId] = e;
        final title = switch (classifyMemberSet(e, prev)) {
          MemberSetChange.retired =>
            '${who(e.userId)} retired ${e.name} from the party',
          MemberSetChange.added =>
            '${who(e.userId)} added ${e.name} to the party',
          MemberSetChange.portraitOnly =>
            "${who(e.userId)} updated ${e.name}'s portrait",
          MemberSetChange.updated => '${who(e.userId)} updated ${e.name}',
        };
        item = ActivityItem(
          eventId: e.eventId,
          kind: ActivityKind.config,
          userId: e.userId,
          title: title,
          occurredAt: e.occurredAt,
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

  items.sort((a, b) {
    final c = b.occurredAt.compareTo(a.occurredAt);
    return c != 0 ? c : b.eventId.compareTo(a.eventId);
  });
  return items.length > limit ? items.sublist(0, limit) : items;
}

extension _EmptyToNull on String {
  String? ifEmptyNull() => isEmpty ? null : this;
}
