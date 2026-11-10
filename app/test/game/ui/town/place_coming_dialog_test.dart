import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/game/ui/town/town_place_openers.dart';

import '../hall_harness.dart';

void main() {
  Future<void> openComing(WidgetTester tester, AdventureTier tier) async {
    final store = await storeWith(sampleEvents());
    await pumpHall(
      tester,
      store: store,
      tier: tier,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showPlaceComingSheet(context, title: 'Home', body: 'On its way.'),
          child: const Text('Open'),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settle(tester);
  }

  testWidgets('the pixel tier shows a framed dialog that closes', (tester) async {
    await openComing(tester, AdventureTier.pixel);
    expect(find.byType(GameDialog), findsOneWidget);
    expect(find.text('On its way.'), findsOneWidget);
    await tester.tap(find.widgetWithText(WoodButton, 'Got it'));
    await settle(tester);
    expect(find.byType(GameDialog), findsNothing);
  });

  testWidgets('the text tier keeps the bottom sheet', (tester) async {
    await openComing(tester, AdventureTier.text);
    expect(find.byType(GameDialog), findsNothing);
    expect(find.text('On its way.'), findsOneWidget);
  });
}
