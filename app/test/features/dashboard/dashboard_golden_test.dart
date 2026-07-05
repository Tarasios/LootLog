import 'package:duobudget/features/dashboard/dashboard_view.dart';
import 'package:duobudget/features/sync/sync_status.dart';
import 'package:duobudget/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dashboard_fixtures.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('dashboard golden (phone)', (tester) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(DashboardView(
      model: sampleDashboardModel(),
      activityItems: sampleActivity(),
      syncStatus: SyncStatus.localOnly,
    )));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DashboardView),
      matchesGoldenFile('goldens/dashboard_phone.png'),
    );
  });

  testWidgets('dashboard golden (desktop pane)', (tester) async {
    // On desktop the dashboard pane sits beside the activity pane, so it renders
    // without the inline activity section at a wider width.
    tester.view.physicalSize = const Size(760, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(DashboardView(
      model: sampleDashboardModel(),
      syncStatus: SyncStatus.synced,
      showActivity: false,
    )));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DashboardView),
      matchesGoldenFile('goldens/dashboard_desktop.png'),
    );
  });
}
