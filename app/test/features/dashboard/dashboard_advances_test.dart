/// Pending borrowing requests and open vacations surface on the Classic
/// dashboard, not only on the war-chest / vacations screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/dashboard/dashboard_model.dart';
import 'package:lootlog/features/dashboard/dashboard_view.dart';

final _t = DateTime.utc(2026, 7, 5, 18);
const _month = '2026-07';

List<Event> _ledger() => [
      for (final (id, name) in [('u1', 'Alex'), ('u2', 'Blair')])
        MemberSet(
          eventId: 'm-$id',
          deviceId: 'd',
          userId: id,
          occurredAt: _t,
          createdAt: _t,
          memberId: id,
          name: name,
          role: MemberRole.adult,
        ),
      SettingChanged(
        eventId: 'rules',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _t,
        createdAt: _t,
        key: 'savingsRules',
        value: const {'fromMonth': _month, 'generalTithePct': 20},
      ),
      BudgetSliceSet(
        eventId: 'slice',
        deviceId: 'd',
        userId: 'u2',
        occurredAt: _t,
        createdAt: _t,
        sliceId: 'clothes',
        name: 'Clothing',
        ownership: const PersonalSlice('u2'),
        limitCents: 25000,
        poolTithePct: 10,
        defaultLeftoverPolicy: const CarryInSlice(),
        taxDeductibleByDefault: false,
      ),
      AllowanceAdvanceProposed(
        eventId: 'adv',
        deviceId: 'd',
        userId: 'u2',
        occurredAt: _t,
        createdAt: _t,
        advanceId: 'a1',
        byUserId: 'u2',
        sliceId: 'clothes',
        amountCents: 5000,
        months: 2,
      ),
    ];

const _names = {'u1': 'Alex', 'u2': 'Blair'};

DashboardModel _model({
  List<PendingAdvance> advances = const [],
  List<OpenVacationCard> vacations = const [],
}) =>
    DashboardModel(
      currentMonth: const Month(2026, 7),
      meName: 'Alex',
      hero: const MonthHero(incomeCents: 0, spentCents: 0),
      netWorth: const NetWorthSummary(
        show: false,
        totalCents: 0,
        assetsCents: 0,
        debtsCents: 0,
        series: [],
      ),
      slices: const [],
      maintenance: const [],
      upcoming: const [],
      vault: const VaultCard(
        balanceCents: 0,
        inconsistent: false,
        projectedLeftoverCents: 0,
        projectedVaultCents: 0,
      ),
      quests: const [],
      warChest: const WarChestCard(
        balanceCents: 0,
        pendingForMe: [],
        otherPending: [],
        ransacks: [],
      ),
      emergencyFunds: const [],
      timeline: const SpendTimeline(
        month: Month(2026, 7),
        points: [],
        totalCents: 0,
        maxDayCents: 0,
        daysInMonth: 31,
      ),
      advances: advances,
      vacations: vacations,
      spoils: null,
    );

const _theirs = PendingAdvance(
  advanceId: 'a1',
  categoryName: 'Clothing',
  byUserName: 'Blair',
  amountCents: 5000,
  months: 2,
  mine: false,
);

const _mine = PendingAdvance(
  advanceId: 'a2',
  categoryName: 'Games',
  byUserName: 'Alex',
  amountCents: 3000,
  months: 1,
  mine: true,
);

Future<void> _pump(
  WidgetTester tester,
  DashboardModel model, {
  DashboardCallbacks callbacks = const DashboardCallbacks(),
}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: DashboardView(model: model, callbacks: callbacks)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('dashboard model', () {
    test('lists a pending request as approvable for the other adult', () {
      final m = buildDashboardModel(reduce(_ledger()),
          meUserId: 'u1', userNames: _names, asOf: _t);
      expect(m.advances, hasLength(1));
      final a = m.advances.single;
      expect(a.advanceId, 'a1');
      expect(a.categoryName, 'Clothing');
      expect(a.byUserName, 'Blair');
      expect(a.amountCents, 5000);
      expect(a.months, 2);
      expect(a.canApprove, isTrue);
    });

    test('the requester sees their own request, not approvable', () {
      final m = buildDashboardModel(reduce(_ledger()),
          meUserId: 'u2', userNames: _names, asOf: _t);
      expect(m.advances.single.mine, isTrue);
      expect(m.advances.single.canApprove, isFalse);
    });

    test('a resolved request no longer shows', () {
      final events = [
        ..._ledger(),
        AllowanceAdvanceApproved(
          eventId: 'ok',
          deviceId: 'd',
          userId: 'u1',
          occurredAt: _t,
          createdAt: _t,
          advanceId: 'a1',
          byUserId: 'u1',
        ),
      ];
      final m = buildDashboardModel(reduce(events),
          meUserId: 'u1', userNames: _names, asOf: _t);
      expect(m.advances, isEmpty);
    });
  });

  group('dashboard view', () {
    testWidgets('shows no borrowing card when nothing is pending',
        (tester) async {
      await _pump(tester, _model());
      expect(find.text('Borrowing requests'), findsNothing);
    });

    testWidgets('shows a pending request with Approve for another adult',
        (tester) async {
      await _pump(tester, _model(advances: const [_theirs]));
      expect(find.text('Borrowing requests'), findsOneWidget);
      expect(find.textContaining('from Clothing over 2 months'), findsOneWidget);
      expect(find.text('One request is waiting for your approval.'),
          findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Decline'), findsOneWidget);
    });

    testWidgets('hides Approve from the requester, who can withdraw',
        (tester) async {
      await _pump(tester, _model(advances: const [_mine]));
      expect(find.textContaining('from Games over 1 month'), findsOneWidget);
      expect(find.text('Waiting for another adult to approve.'),
          findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Approve'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Withdraw'), findsOneWidget);
    });

    testWidgets('Approve and Decline/Withdraw call the actions with the id',
        (tester) async {
      final approved = <String>[];
      final cancelled = <String>[];
      await _pump(
        tester,
        _model(advances: const [_theirs, _mine]),
        callbacks: DashboardCallbacks(
          onApproveAdvance: approved.add,
          onCancelAdvance: cancelled.add,
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.tap(find.widgetWithText(TextButton, 'Decline'));
      await tester.tap(find.widgetWithText(TextButton, 'Withdraw'));
      await tester.pump();
      expect(approved, ['a1']);
      expect(cancelled, ['a1', 'a2']);
    });

    testWidgets('an open vacation shows a card that opens vacations',
        (tester) async {
      var opened = 0;
      await _pump(
        tester,
        _model(vacations: const [
          OpenVacationCard(
            vacationId: 'v1',
            name: 'Tofino',
            spentCents: 20000,
            budgetCents: 80000,
            allowanceLabel: r'$100.00/day for 6 more days',
          ),
        ]),
        callbacks: DashboardCallbacks(onOpenVacations: () => opened++),
      );
      expect(find.text('On vacation · Tofino'), findsOneWidget);
      expect(find.textContaining(r'$100.00/day for 6 more days'),
          findsOneWidget);
      await tester.tap(find.text('On vacation · Tofino'));
      expect(opened, 1);
    });
  });
}
