import 'package:lootlog/domain/time.dart';
import 'package:lootlog/features/dashboard/dashboard_model.dart';
import 'package:lootlog/features/dashboard/dashboard_view.dart';
import 'package:lootlog/features/sync/sync_status.dart';
import 'package:lootlog/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dashboard_fixtures.dart';

Widget _host(Widget child, {required ThemeData theme}) => MaterialApp(
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    );

/// A brand-new household: no budgets, no goals, no income — exercises the
/// empty-state path (get-started card, zero-income hero, empty cards).
DashboardModel _emptyModel() => const DashboardModel(
      currentMonth: Month(2026, 7),
      meName: 'Robin',
      hero: MonthHero(incomeCents: 0, spentCents: 0),
      netWorth: NetWorthSummary(
        show: true,
        totalCents: 0,
        assetsCents: 0,
        debtsCents: 0,
        series: [],
      ),
      slices: [],
      maintenance: [],
      upcoming: [],
      vault: VaultCard(
        balanceCents: 0,
        inconsistent: false,
        projectedLeftoverCents: 0,
        projectedVaultCents: 0,
      ),
      quests: [],
      warChest: WarChestCard(
        balanceCents: 0,
        pendingForMe: [],
        otherPending: [],
        ransacks: [],
      ),
      emergencyFunds: [],
      timeline: SpendTimeline(
        month: Month(2026, 7),
        points: [],
        totalCents: 0,
        maxDayCents: 0,
        daysInMonth: 31,
      ),
      spoils: null,
    );

void main() {
  testWidgets('dashboard golden (phone)', (tester) async {
    tester.view.physicalSize = const Size(390, 2900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(
      DashboardView(
        model: sampleDashboardModel(),
        activityItems: sampleActivity(),
        syncStatus: SyncStatus.localOnly,
      ),
      theme: AppTheme.light(),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DashboardView),
      matchesGoldenFile('goldens/dashboard_phone.png'),
    );
  });

  testWidgets('dashboard golden (phone, dark)', (tester) async {
    tester.view.physicalSize = const Size(390, 2900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(
      DashboardView(
        model: sampleDashboardModel(),
        activityItems: sampleActivity(),
        syncStatus: SyncStatus.synced,
      ),
      theme: AppTheme.dark(),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DashboardView),
      matchesGoldenFile('goldens/dashboard_phone_dark.png'),
    );
  });

  testWidgets('dashboard golden (desktop pane)', (tester) async {
    // On desktop the dashboard pane sits beside the activity pane, so it renders
    // without the inline activity section at a wider width — triggering the
    // two-column layout.
    tester.view.physicalSize = const Size(760, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(
      DashboardView(
        model: sampleDashboardModel(),
        syncStatus: SyncStatus.synced,
        showActivity: false,
      ),
      theme: AppTheme.light(),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DashboardView),
      matchesGoldenFile('goldens/dashboard_desktop.png'),
    );
  });

  testWidgets('dashboard golden (empty state)', (tester) async {
    tester.view.physicalSize = const Size(390, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(
      DashboardView(model: _emptyModel()),
      theme: AppTheme.light(),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DashboardView),
      matchesGoldenFile('goldens/dashboard_empty.png'),
    );
  });
}
