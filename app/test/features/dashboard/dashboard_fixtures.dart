/// Deterministic fixtures for the dashboard and spoils goldens: a fully
/// populated [DashboardModel] (every card kind exercised) and the matching
/// [SpoilsRitual], plus a short activity feed. Built directly from the pure
/// view-model constructors so the goldens are stable and self-contained.
library;

import 'package:duobudget/domain/time.dart';
import 'package:duobudget/domain/value_types.dart';
import 'package:duobudget/features/activity/activity_model.dart';
import 'package:duobudget/features/dashboard/dashboard_model.dart';
import 'package:duobudget/features/spoils/spoils_model.dart';

const _july = Month(2026, 7);
const _june = Month(2026, 6);

final _asOf = DateTime.utc(2026, 7, 5, 12);
final _graceDeadline = DateTime.utc(2026, 7, 8, 14); // -> 3 days remaining

SpoilsRitual sampleSpoilsRitual() => SpoilsRitual(
      month: _june,
      forUserId: 'me',
      graceDeadline: _graceDeadline,
      asOf: _asOf,
      variableTallies: const [
        VariableTally(
          expenseId: 'util',
          name: 'Utilities',
          estimateCents: 8000,
          isShared: true,
        ),
      ],
      sliceLeftovers: const [
        SliceLeftover(
          sliceId: 'food',
          name: 'Food',
          leftoverCents: 15000,
          poolTithePct: 20,
          defaultPolicy: Discretionary(),
          petName: 'Mochi',
          questOptions: [
            QuestOption(
              questId: 'canoe',
              name: 'Canoe',
              balanceCents: 30000,
              targetCents: 130000,
              totalContributedCents: 30000,
            ),
            QuestOption(
              questId: 'house',
              name: 'House fund',
              balanceCents: 200000,
              targetCents: 2000000,
              totalContributedCents: 200000,
            ),
          ],
        ),
        SliceLeftover(
          sliceId: 'fun',
          name: 'Fun',
          leftoverCents: 15000,
          poolTithePct: 0,
          defaultPolicy: CarryInSlice(),
          questOptions: [
            QuestOption(
              questId: 'canoe',
              name: 'Canoe',
              balanceCents: 30000,
              targetCents: 130000,
              totalContributedCents: 30000,
            ),
          ],
        ),
      ],
      groupFlows: const [
        GroupFlow(name: 'Groceries', leftoverCents: 19000),
      ],
      emergencyContribs: const [
        EmergencyContribLine(fundName: 'Vet fund', amountCents: 5000),
      ],
    );

DashboardModel sampleDashboardModel() => DashboardModel(
      currentMonth: _july,
      meName: 'Robin',
      slices: const [
        SliceRing(
          sliceId: 'food',
          name: 'Food',
          isGroup: false,
          spentCents: 25000,
          effectiveLimitCents: 40000,
          overspendCents: 0,
          mine: true,
          ownerName: 'Robin',
          petName: 'Mochi',
        ),
        SliceRing(
          sliceId: 'fun',
          name: 'Fun',
          isGroup: false,
          spentCents: 18000,
          effectiveLimitCents: 20000,
          overspendCents: 0,
          mine: true,
          ownerName: 'Robin',
        ),
        SliceRing(
          sliceId: 'gear',
          name: 'Gear',
          isGroup: false,
          spentCents: 12000,
          effectiveLimitCents: 30000,
          overspendCents: 0,
          mine: false,
          ownerName: 'Sam',
        ),
        SliceRing(
          sliceId: 'groceries',
          name: 'Groceries',
          isGroup: true,
          spentCents: 41000,
          effectiveLimitCents: 60000,
          overspendCents: 0,
          mine: false,
        ),
        SliceRing(
          sliceId: 'petcare',
          name: 'Pet care',
          isGroup: true,
          spentCents: 22000,
          effectiveLimitCents: 20000,
          overspendCents: 2000,
          mine: false,
          petName: 'Rex',
        ),
      ],
      maintenance: const [
        MaintenanceItem(
          name: 'Rent',
          kind: RecurringKind.fixed,
          amountCents: 120000,
          isShared: true,
          awaitingTally: false,
        ),
        MaintenanceItem(
          name: 'Patreon',
          kind: RecurringKind.fixed,
          amountCents: 1500,
          isShared: false,
          awaitingTally: false,
          ownerName: 'Robin',
        ),
        MaintenanceItem(
          name: 'Utilities',
          kind: RecurringKind.variable,
          amountCents: 8000,
          isShared: true,
          awaitingTally: true,
        ),
      ],
      upcoming: const [
        UpcomingPayment(
          name: 'Rent',
          amountCents: 120000,
          isAnnual: false,
          isShared: true,
          dueDay: 31,
          daysUntilDue: 3,
        ),
        UpcomingPayment(
          name: 'WoW',
          amountCents: 13100,
          isAnnual: true,
          isShared: false,
          dueDay: 10,
          dueMonth: 2,
          daysUntilDue: 217,
        ),
      ],
      vault: const VaultCard(
        balanceCents: 8850,
        inconsistent: false,
        projectedLeftoverCents: 46000,
        projectedVaultCents: 40000,
      ),
      quests: const [
        QuestCard(
          questId: 'canoe',
          name: 'Canoe',
          targetCents: 130000,
          balanceCents: 30000,
          totalContributedCents: 30000,
          completed: false,
          isShared: true,
          contributors: [
            ContributorShare(name: 'Robin', cents: 20000),
            ContributorShare(name: 'Sam', cents: 10000),
          ],
        ),
        QuestCard(
          questId: 'jacket',
          name: 'Winter jacket',
          targetCents: 50000,
          balanceCents: 50000,
          totalContributedCents: 50000,
          completed: true,
          isShared: false,
          contributors: [],
        ),
      ],
      warChest: WarChestCard(
        balanceCents: 214000,
        targetCents: 500000,
        pctComplete: 214000 / 500000,
        estMonthsRemaining: 6.2,
        pendingForMe: const [
          WithdrawalCard(
            proposalId: 'w1',
            byUserName: 'Sam',
            amountCents: 20000,
            purpose: 'New tent',
            destinationLabel: 'external',
            mineToApprove: true,
          ),
        ],
        otherPending: const [],
        ransacks: [
          RansackCard(
            fundName: 'Car repairs',
            excessCents: 15000,
            purpose: 'Tow truck',
            occurredAt: DateTime.utc(2026, 7, 2, 18),
          ),
        ],
      ),
      emergencyFunds: const [
        EmergencyFundCard(
          name: 'Vet fund',
          balanceCents: 50000,
          petName: 'Mochi',
        ),
        EmergencyFundCard(name: 'Car repairs', balanceCents: 0),
      ],
      timeline: _sampleTimeline(),
      spoils: sampleSpoilsRitual(),
    );

SpendTimeline _sampleTimeline() {
  const daysInMonth = 31;
  final spend = <int, int>{1: 3200, 2: 15400, 3: 900, 4: 6100, 5: 4300};
  final points = <SpendPoint>[];
  var total = 0;
  var maxDay = 0;
  for (var d = 1; d <= daysInMonth; d++) {
    final c = spend[d] ?? 0;
    total += c;
    if (c > maxDay) maxDay = c;
    points.add(SpendPoint(day: d, cents: c));
  }
  return SpendTimeline(
    month: _july,
    points: points,
    totalCents: total,
    maxDayCents: maxDay,
    daysInMonth: daysInMonth,
  );
}

List<ActivityItem> sampleActivity() => [
      ActivityItem(
        eventId: 'a3',
        kind: ActivityKind.purchase,
        userId: 'pa',
        title: 'Sam spent on Groceries',
        subtitle: 'Safeway',
        amountCents: -4210,
        occurredAt: DateTime.utc(2026, 7, 5, 17),
        isMine: false,
      ),
      ActivityItem(
        eventId: 'a2',
        kind: ActivityKind.gift,
        userId: 'me',
        title: 'Robin received a gift',
        subtitle: 'Birthday',
        amountCents: 5000,
        occurredAt: DateTime.utc(2026, 7, 4, 15),
        isMine: true,
      ),
      ActivityItem(
        eventId: 'a1',
        kind: ActivityKind.withdrawal,
        userId: 'pa',
        title: 'Sam proposed a war-chest writ',
        subtitle: 'New tent',
        amountCents: -20000,
        occurredAt: DateTime.utc(2026, 7, 3, 9),
        isMine: false,
      ),
    ];
