import 'package:duobudget/game/adventure_spoils.dart';
import 'package:duobudget/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/dashboard/dashboard_fixtures.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('adventure spoils recap golden (phone, placeholder assets)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AdventureSpoilsRecap(ritual: sampleSpoilsRitual()),
    )));
    await tester.pump(const Duration(milliseconds: 200));

    await expectLater(
      find.byType(AdventureSpoilsRecap),
      matchesGoldenFile('goldens/adventure_spoils_phone.png'),
    );
  });
}
