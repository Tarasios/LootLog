import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/skin_prefs.dart';

import 'hall_harness.dart';

Future<void> openPlot(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await settle(tester);
}

void main() {
  testWidgets('an empty plot lists what can be built and builds it',
      (tester) async {
    final store = await storeWith(sampleEvents());
    await pumpHall(tester, store: store);
    await openPlot(tester, 'Empty plot');

    expect(find.text('Plot 3 — empty'), findsOneWidget);
    // Buildings already standing are not offered again.
    expect(find.text('Build Lumberyard'), findsNothing);
    expect(find.text('Build Quarry'), findsOneWidget);

    await tester.ensureVisible(find.text('Build Quarry'));
    await tester.tap(find.text('Build Quarry'));
    await settle(tester);

    final events = await store.all();
    final b = events.whereType<BuildingStarted>().last;
    expect(b.buildingType, BuildingType.quarry);
    expect(b.plotIndex, 2);
    expect(find.text('Quarry — tier 1'), findsOneWidget,
        reason: 'the sheet follows the new state');
  });

  testWidgets('a producer previews and collects what fits', (tester) async {
    final store = await storeWith(sampleEvents());
    await pumpHall(tester, store: store);
    await openPlot(tester, 'Lumberyard T1');

    expect(find.text('Ready to collect: 30 lumber'), findsOneWidget);
    expect(find.text('Makes 6 lumber an hour.'), findsOneWidget);
    await tester.tap(find.text('Collect'));
    await settle(tester);

    final c = (await store.all()).whereType<MaterialsCollected>().single;
    expect(c.amounts[MaterialKind.lumber], 30);
    expect(find.textContaining('Collected 30 lumber.'), findsOneWidget);
  });

  testWidgets('an upgrade gate explains itself in plain words',
      (tester) async {
    await pumpHall(tester, store: await storeWith(sampleEvents()));
    await openPlot(tester, 'Lumberyard T1');

    expect(find.text('Upgrade to tier 2'), findsWidgets);
    expect(
        find.text('Raise the Central Hall first. It sets how high everything '
            'else can go.'),
        findsOneWidget);
    expect(find.text('Tier 2 needs the Central Hall at tier 2.'),
        findsOneWidget);
    final button = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Upgrade to tier 2').last,
        matching: find.byWidgetPredicate((w) => w is FilledButton)));
    expect(button.onPressed, isNull);
  });

  testWidgets('a building under construction shows its timer',
      (tester) async {
    await pumpHall(tester, store: await storeWith(sampleEvents()));
    await openPlot(tester, 'Central Hall T2');
    expect(find.text('Upgrading to tier 2 · ready in 30m'), findsOneWidget);
    expect(find.text('The builders are still at work. It\'ll be ready soon.'),
        findsOneWidget);
  });

  testWidgets('a locked plot shows its price and unlocks for gems',
      (tester) async {
    final store = await storeWith(sampleEvents());
    await pumpHall(tester, store: store);
    await openPlot(tester, 'Unlock: 20 gems');

    expect(find.text('Plot 4 — locked'), findsOneWidget);
    await tester.tap(find.text('Unlock for 20 gems'));
    await settle(tester);
    expect((await store.all()).whereType<PlotUnlocked>().single.plotIndex, 3);
    expect((await stateOf(store)).person(robin).gems, 110);
  });

  testWidgets('a plot out of reach says how many gems it needs',
      (tester) async {
    await pumpHall(tester, store: await storeWith(sampleEvents()));
    await openPlot(tester, 'Unlock: 135 gems');
    expect(
        find.text('A few more gems needed. They come from logging, so every '
            'entry brings this closer.'),
        findsOneWidget);
    final button = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Unlock for 135 gems'),
        matching: find.byWidgetPredicate((w) => w is FilledButton)));
    expect(button.onPressed, isNull);
  });

  testWidgets('the sheet renders in the pixel tier with zero art',
      (tester) async {
    await pumpHall(tester,
        store: await storeWith(sampleEvents()), tier: AdventureTier.pixel);
    await openPlot(tester, 'Empty plot');
    expect(tester.takeException(), isNull);
    expect(find.text('Build Quarry'), findsOneWidget);
  });
}
