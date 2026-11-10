/// Standard screens render under the Adventure theme too, whose primary is
/// ribbon red. Healthy money — a goal filling, a finished goal, spending still
/// inside its budget, a rising balance — must never be drawn in that red, or
/// it reads as overspending. These screens take their gain colour from
/// [MoneyTones] instead.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/providers.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/dashboard/dashboard_model.dart';
import 'package:lootlog/features/dashboard/dashboard_view.dart';
import 'package:lootlog/features/networth/networth_screen.dart';
import 'package:lootlog/features/vacation/vacation_screen.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/ui/widgets/progress_ring.dart';

final Color _ribbonRed = AdventureTheme.build().colorScheme.primary;

/// The hue of [color], in degrees.
double _hueOf(Color color) => HSLColor.fromColor(color).hue;

/// Whether [color] sits within 30° of the ribbon red's hue: it would read as
/// red even if it is a tint or shade of it.
bool _readsRed(Color color) {
  final distance = (_hueOf(color) - _hueOf(_ribbonRed)).abs() % 360;
  return (distance > 180 ? 360 - distance : distance) < 30;
}

int _eventNumber = 0;

({String eventId, String deviceId, String userId, DateTime occurredAt, DateTime createdAt})
    _header(DateTime at) => (
          eventId: 'e${(_eventNumber++).toString().padLeft(4, '0')}',
          deviceId: 'd',
          userId: 'robin',
          occurredAt: at,
          createdAt: at,
        );

final DateTime _today = DateTime.utc(2026, 6, 12, 18);

DateTime get _june1 => DateTime.utc(2026, 6, 1, 18);

Event _robin() {
  final header = _header(_june1);
  return MemberSet(
    eventId: header.eventId,
    deviceId: header.deviceId,
    userId: header.userId,
    occurredAt: header.occurredAt,
    createdAt: header.createdAt,
    memberId: 'robin',
    name: 'Robin',
    role: MemberRole.adult,
  );
}

Event _travelFund() {
  final header = _header(_june1);
  return EmergencyFundSet(
    eventId: header.eventId,
    deviceId: header.deviceId,
    userId: header.userId,
    occurredAt: header.occurredAt,
    createdAt: header.createdAt,
    fundId: 'travel',
    name: 'Travel fund',
  );
}

/// An open trip, two days in on [_today], with nothing spent yet.
Event _coastTrip() {
  final header = _header(_june1);
  return VacationSet(
    eventId: header.eventId,
    deviceId: header.deviceId,
    userId: header.userId,
    occurredAt: header.occurredAt,
    createdAt: header.createdAt,
    vacationId: 'coast',
    name: 'Coast trip',
    fund: const VacationFundEmergency('travel'),
    startDate: DateTime.utc(2026, 6, 10),
    endDate: DateTime.utc(2026, 6, 17),
    categories: const [
      VacationCategory(categoryId: 'food', name: 'Food', limitCents: 40000),
    ],
  );
}

/// A dashboard with a war-chest goal under way, a finished goal, and one
/// in-budget category of mine with no main category (the fallback colour).
DashboardModel _dashboard() => const DashboardModel(
      currentMonth: Month(2026, 6),
      meName: 'Robin',
      hero: MonthHero(incomeCents: 300000, spentCents: 100000),
      netWorth: NetWorthSummary(
        show: false,
        totalCents: 0,
        assetsCents: 0,
        debtsCents: 0,
        series: [],
      ),
      slices: [
        SliceRing(
          sliceId: 'odds',
          name: 'Odds and ends',
          isGroup: false,
          spentCents: 1000,
          effectiveLimitCents: 5000,
          overspendCents: 0,
          mine: true,
          ownerName: 'Robin',
        ),
      ],
      maintenance: [],
      upcoming: [],
      vault: VaultCard(
        balanceCents: 0,
        inconsistent: false,
        projectedLeftoverCents: 0,
        projectedVaultCents: 0,
      ),
      quests: [
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
        pendingForMe: [],
        otherPending: [],
        ransacks: [],
      ),
      emergencyFunds: [],
      timeline: SpendTimeline(
        month: Month(2026, 6),
        points: [],
        totalCents: 0,
        maxDayCents: 0,
        daysInMonth: 30,
      ),
      spoils: null,
    );

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen,
  List<Event> events,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        householdStateProvider
            .overrideWith((ref) => Stream.value(reduce(events, asOf: _today))),
        eventLogProvider.overrideWith((ref) => Stream.value(events)),
      ],
      child: MaterialApp(theme: AdventureTheme.build(), home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the dashboard draws goal progress, trophies and in-budget '
      'categories without the ribbon red', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AdventureTheme.build(),
        home: Scaffold(
          body: DashboardView(model: _dashboard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fills = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.color)
        .whereType<Color>();
    expect(fills, isNot(contains(_ribbonRed)),
        reason: 'the war-chest goal and finished-goal bars are gains');

    final trophy = tester.widget<Icon>(find.byIcon(Icons.emoji_events));
    expect(trophy.color, isNot(_ribbonRed));

    final ring = tester.widget<ProgressRing>(find.byType(ProgressRing));
    expect(_readsRed(ring.color), isFalse,
        reason: 'an in-budget category without a main category is not red');
  });

  testWidgets('a vacation draws its daily allowance and in-budget rings '
      'without the ribbon red', (tester) async {
    final events = <Event>[_robin(), _travelFund(), _coastTrip()];
    await _pumpScreen(tester, const VacationScreen(), events);

    final allowance = tester.widget<Text>(find.textContaining('/day for'));
    expect(allowance.style?.color, isNot(_ribbonRed));

    final ring = tester.widget<ProgressRing>(find.byType(ProgressRing));
    expect(ring.color, isNot(_ribbonRed));
  });

  testWidgets('net worth draws assets and balance sparklines without the '
      'ribbon red', (tester) async {
    Event balance(int cents, DateTime at) {
      final header = _header(at);
      return AccountBalanceRecorded(
        eventId: header.eventId,
        deviceId: header.deviceId,
        userId: header.userId,
        occurredAt: header.occurredAt,
        createdAt: header.createdAt,
        accountId: 'savings',
        accountName: 'Savings',
        kind: AccountKind.savings,
        balanceCents: cents,
      );
    }

    final settingHeader = _header(DateTime.utc(2026, 1, 1, 18));
    final events = <Event>[
      SettingChanged(
        eventId: settingHeader.eventId,
        deviceId: settingHeader.deviceId,
        userId: settingHeader.userId,
        occurredAt: settingHeader.occurredAt,
        createdAt: settingHeader.createdAt,
        key: 'showNetWorth',
        value: true,
      ),
      balance(500000, DateTime.utc(2026, 4, 1, 18)),
      balance(650000, DateTime.utc(2026, 5, 1, 18)),
      balance(700000, DateTime.utc(2026, 6, 1, 18)),
    ];
    await _pumpScreen(tester, const NetWorthScreen(), events);

    final assetsValue = tester.widget<Text>(find.text('\$7000.00'));
    expect(assetsValue.style?.color, isNot(_ribbonRed));

    final sparklines = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .where((painter) => painter.runtimeType.toString() == '_SparklinePainter');
    expect(sparklines, isNotEmpty);
    for (final painter in sparklines) {
      expect((painter as dynamic).color, isNot(_ribbonRed));
    }
  });
}
