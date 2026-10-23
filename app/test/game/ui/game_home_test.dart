import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/game_sprite.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_screen.dart';
import 'package:lootlog/game/ui/game_home.dart';

import 'hall_harness.dart';

/// Every visible string on screen, for copy checks.
List<String> visibleText(WidgetTester tester) => [
      for (final w in tester.widgetList<Text>(find.byType(Text)))
        w.data ?? w.textSpan?.toPlainText() ?? '',
    ];

void main() {
  testWidgets('the hall home renders every section in the text tier with no '
      'art', (tester) async {
    await pumpHall(tester, store: await storeWith(sampleEvents()));

    expect(tester.takeException(), isNull);
    expect(find.text('Guild hall'), findsOneWidget);
    expect(find.text('THE PARTY'), findsOneWidget, reason: 'text-tier panel');
    expect(find.text('130 gems'), findsOneWidget);
    expect(find.text('1 freeze token'), findsOneWidget);
    expect(find.text('Streak: 3 days'), findsOneWidget);
    expect(find.text('Robin (you)'), findsOneWidget);
    expect(find.text('Sam'), findsWidgets); // name + its text card
    expect(find.textContaining('Supply caravan · 1 delivery'), findsOneWidget);
    expect(find.textContaining('102/150'), findsOneWidget); // lumber
    expect(find.textContaining('100/150'), findsOneWidget); // stone
    expect(find.text('Lumberyard T1'), findsOneWidget);
    expect(find.text('+30 lumber'), findsOneWidget);
    expect(find.text('Central Hall T2'), findsOneWidget);
    expect(find.text('Ready in 30m'), findsOneWidget);
    expect(find.text('Empty plot'), findsOneWidget);
    expect(find.text('Unlock: 20 gems'), findsOneWidget);
    expect(find.text('Wood chest'), findsOneWidget);
    expect(find.text('Showed up today'), findsOneWidget);
    expect(find.textContaining('the dungeon below the town gate is open'),
        findsOneWidget);
    expect(find.text('Log a purchase'), findsOneWidget);
    // Sprites fall back to their text cards: no image is ever decoded.
    expect(find.byType(TextSpriteCard), findsWidgets);
  });

  testWidgets('a Standard partner is shown as the caravan, never blamed',
      (tester) async {
    await pumpHall(tester, store: await storeWith(const []));
    final copy = visibleText(tester).join(' ').toLowerCase();
    expect(copy, contains('sam'));
    for (final word in [
      'inactive',
      'lazy',
      'missed',
      'slacking',
      'behind',
      'not logging',
      'failed',
    ]) {
      expect(copy, isNot(contains(word)), reason: 'found "$word"');
    }
    expect(copy, contains('streak: start a fresh one today'));
  });

  testWidgets('the ritual callout opens the month-end dungeon',
      (tester) async {
    await pumpHall(tester, store: await storeWith(sampleEvents()));
    await tester.tap(find.text('Enter the dungeon'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DungeonScreen), findsOneWidget);
  });

  testWidgets('"Log a purchase" opens quick entry in one tap', (tester) async {
    final links = LinkLog();
    await pumpHall(tester, store: await storeWith(const []), links: links);
    await tester.tap(find.text('Log a purchase'));
    expect(links.calls, ['logPurchase']);
  });

  testWidgets("the Scribe's Desk and the app bar open the ledger",
      (tester) async {
    final links = LinkLog();
    await pumpHall(tester, store: await storeWith(const []), links: links);
    await tester.tap(find.text('Open the ledger'));
    await tester.tap(find.text('Ledger'));
    expect(links.calls, ['ledger', 'ledger']);
  });

  testWidgets('"No spend today" checks in through the ledger habit API',
      (tester) async {
    final habits = FakeHabits();
    // A fresh log: today is not yet covered.
    await pumpHall(tester, store: await storeWith(const []), habits: habits);
    await tester.tap(find.text('No spend today'));
    await settle(tester);
    expect(habits.checkIns, 1);
    expect(find.text('Today already counts'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a covered day disables the check-in', (tester) async {
    await pumpHall(tester, store: await storeWith(sampleEvents()));
    final button = tester.widget<OutlinedButton>(find.ancestor(
        of: find.text('Today already counts'),
        matching: find.byWidgetPredicate((w) => w is OutlinedButton)));
    expect(button.onPressed, isNull);
  });

  testWidgets('weekly reconcile asks first, then records the week',
      (tester) async {
    final habits = FakeHabits();
    await pumpHall(tester, store: await storeWith(const []), habits: habits);
    await tester.tap(find.text('Reconcile this week'));
    await tester.pumpAndSettle();
    expect(find.text('Reconcile this week?'), findsOneWidget);
    await tester.tap(find.text('Mark reconciled'));
    await settle(tester);
    expect(habits.reconciled, [CalendarDay(2026, 10, 3)]);
    expect(find.text('Week reconciled'), findsOneWidget);
  });

  testWidgets('habits are disabled with a plain reason until the savings '
      'rules are adopted', (tester) async {
    final habits = FakeHabits();
    await pumpHall(tester,
        store: await storeWith(const []),
        habits: habits,
        view: sampleView(habits: false));
    expect(find.textContaining('adopts the savings rules'), findsOneWidget);
    await tester.tap(find.text('No spend today'));
    await tester.pump();
    expect(habits.checkIns, 0);
  });

  testWidgets('opening a chest celebrates what it rolled', (tester) async {
    final store = await storeWith(sampleEvents());
    await pumpHall(tester, store: store);
    await tester.tap(find.widgetWithText(FilledButton, 'Open'));
    await settle(tester);

    final opened = (await store.all()).whereType<ChestOpened>().single;
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Inside: ${opened.contents.gems} gems'),
        findsOneWidget);
    await tester.tap(find.text('Huzzah!'));
    await settle(tester);
    expect(find.text('Wood chest'), findsNothing);
  });

  testWidgets('the Open button waits, labelled, until the decorations have '
      'loaded', (tester) async {
    final store = await storeWith(sampleEvents());
    final catalogLoading = Completer<DecorCatalog>();
    await pumpHall(tester,
        store: store, decorCatalog: catalogLoading.future);
    expect(find.widgetWithText(FilledButton, 'Open'), findsNothing);
    final waiting = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Unpacking…'));
    expect(waiting.onPressed, isNull);

    catalogLoading.complete(kShippedCatalog);
    await settle(tester);
    expect(find.widgetWithText(FilledButton, 'Unpacking…'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Open'))
            .onPressed,
        isNotNull);
  });

  testWidgets('claiming a reward credits it and says so', (tester) async {
    final store = await storeWith(sampleEvents());
    await pumpHall(tester, store: store);
    await tester.tap(find.widgetWithText(FilledButton, 'Claim'));
    await settle(tester);
    expect((await stateOf(store)).person(robin).gems, 135);
    expect(find.textContaining('5 gems.'), findsOneWidget);
    expect(find.text('135 gems'), findsOneWidget);
  });

  testWidgets('the hall renders in the pixel tier with zero art',
      (tester) async {
    await pumpHall(tester,
        store: await storeWith(sampleEvents()), tier: AdventureTier.pixel);
    expect(tester.takeException(), isNull);
    expect(find.text('The party'), findsOneWidget);
    expect(find.text('Lumberyard T1'), findsOneWidget);
    expect(find.byType(GameSprite), findsWidgets);
  });

  testWidgets('desktop lays the hall out in two columns', (tester) async {
    await pumpHall(tester,
        store: await storeWith(sampleEvents()), size: const Size(1100, 1600));
    final party = tester.getTopLeft(find.text('THE PARTY'));
    final grounds = tester.getTopLeft(find.text('THE HALL GROUNDS'));
    expect(grounds.dx, greaterThan(party.dx + 200));
    expect(grounds.dy, closeTo(party.dy, 1));
  });

  testWidgets('an unreadable game log still shows a usable hall',
      (tester) async {
    await pumpHall(tester, store: await storeWith(const []));
    expect(find.byType(GameHome), findsOneWidget);
    expect(find.text('0 gems'), findsOneWidget);
    expect(find.text('Wood chest'), findsNothing);
    expect(
        find.text('Nothing waiting. Log something and see what turns up.'),
        findsOneWidget);
    expect(MaterialKind.values, isNotEmpty);
  });
}
