import 'package:lootlog/features/spoils/spoils_sheet.dart';
import 'package:lootlog/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dashboard/dashboard_fixtures.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppTheme.light().colorScheme.surface,
        body: Align(alignment: Alignment.bottomCenter, child: child),
      ),
    );

void main() {
  testWidgets('spoils sheet golden (phone)', (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SpoilsResult? result;
    await tester.pumpWidget(_host(SpoilsSheetView(
      ritual: sampleSpoilsRitual(),
      onConfirm: (r) => result = r,
    )));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SpoilsSheetView),
      matchesGoldenFile('goldens/spoils_phone.png'),
    );

    // The sheet emits one allocation per slice (defaults preselected) and a
    // tally per variable expense on confirm.
    await tester.tap(find.text('Confirm the division'));
    expect(result, isNotNull);
    expect(result!.allocations.length, 2);
    expect(result!.tallies.length, 1);
  });
}
