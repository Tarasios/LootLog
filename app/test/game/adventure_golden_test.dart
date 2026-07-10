import 'package:lootlog/game/adventure_dashboard.dart';
import 'package:lootlog/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'adventure_fixtures.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('adventure dashboard golden (phone, placeholder assets)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(AdventureDashboard(
      game: sampleGameState(),
      // Default PlaceholderSpriteResolver: sprites render as labelled grey
      // placeholders, so the golden is deterministic with no real art.
      spoilsBanner: sampleSpoilsBanner(),
    )));
    await tester.pump(const Duration(milliseconds: 200));

    await expectLater(
      find.byType(AdventureDashboard),
      matchesGoldenFile('goldens/adventure_phone.png'),
    );
  });

  testWidgets('adventure dashboard golden (desktop, placeholder assets)',
      (tester) async {
    tester.view.physicalSize = const Size(820, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(AdventureDashboard(
      game: sampleGameState(),
      spoilsBanner: sampleSpoilsBanner(),
    )));
    await tester.pump(const Duration(milliseconds: 200));

    await expectLater(
      find.byType(AdventureDashboard),
      matchesGoldenFile('goldens/adventure_desktop.png'),
    );
  });
}
