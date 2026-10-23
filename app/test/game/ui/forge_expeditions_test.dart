import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/expeditions_screen.dart';
import 'package:lootlog/game/ui/forge_screen.dart';
import 'package:lootlog/game/ui/hall_common.dart';

import 'hall_harness.dart';

/// The sample hall plus a finished Forge on plot 2 and 20 ore.
List<GameEvent> withForge() => [
      ...sampleEvents(),
      built('f1', 2, BuildingType.forge, when: before(const Duration(hours: 4))),
      granted('f2',
          when: before(const Duration(hours: 4)),
          rewardId: 'ore',
          materials: MaterialBundle({MaterialKind.ore: 20})),
      claimed('f3', 'ore', when: before(const Duration(hours: 4))),
    ];

void main() {
  group('Forge & hero', () {
    testWidgets('without a Forge, gear waits and says why', (tester) async {
      await pumpHall(tester,
          store: await storeWith(sampleEvents()),
          home: const HallScope(child: ForgeScreen()));
      expect(find.textContaining('Build a Forge on any plot'), findsOneWidget);
      expect(find.text('The Forge needs to be built or upgraded first.'),
          findsWidgets);
      expect(find.text('Power 0'), findsOneWidget);
    });

    testWidgets('forges gear and raises hero power', (tester) async {
      final store = await storeWith(withForge());
      await pumpHall(tester,
          store: store, home: const HallScope(child: ForgeScreen()));

      await tester.tap(find.text('Bow'));
      await tester.pump();
      await tester.tap(find.text('Forge tier 1').first);
      await settle(tester);

      final g = (await store.all()).whereType<GearUpgraded>().single;
      expect((g.slot, g.gearType, g.tier), ('weapon', 'bow', 1));
      expect(find.text('Weapon: Bow T1'), findsOneWidget);
      expect(find.text('Power 1'), findsOneWidget);
    });

    testWidgets('customizing is free, and a no-op save is gently refused',
        (tester) async {
      final store = await storeWith(sampleEvents());
      await pumpHall(tester,
          store: store, home: const HallScope(child: ForgeScreen()));

      await tester.enterText(find.widgetWithText(TextField, 'Hero name'), 'Robin Hood');
      await tester.tap(find.text('Save').first);
      await settle(tester);
      expect((await stateOf(store)).person(robin).hero.cosmetics['name'],
          'Robin Hood');
      expect((await stateOf(store)).person(robin).gems, 130);

      await tester.tap(find.text('Save').first);
      await settle(tester);
      expect(find.text('Your hero already looks like that.'), findsOneWidget);
    });

    testWidgets('renders in the pixel tier with zero art', (tester) async {
      await pumpHall(tester,
          store: await storeWith(withForge()),
          tier: AdventureTier.pixel,
          home: const HallScope(child: ForgeScreen()));
      expect(tester.takeException(), isNull);
      expect(find.text('Weapon: empty'), findsOneWidget);
    });
  });

  group('Expeditions', () {
    testWidgets('locked regions say what opens them; open ones send the hero',
        (tester) async {
      final store = await storeWith(sampleEvents());
      await pumpHall(tester,
          store: store, home: const HallScope(child: ExpeditionsScreen()));

      // Central Hall tier 1 is in service (tier 2 still building).
      expect(find.text('Opens when the Central Hall reaches tier 2.'),
          findsNWidgets(2));
      await tester.tap(find.text('Send the hero').first);
      await settle(tester);

      final e = (await store.all()).whereType<ExpeditionStarted>().single;
      expect(e.region, ExpeditionRegion.marketCatacombs);
      expect(find.text('Away in Market Catacombs'), findsOneWidget);
      expect(find.text('Back in 30m'), findsOneWidget);
      expect(find.text('The hero is already out on the road.'), findsWidgets);
    });

    testWidgets('a returned hero brings home the stored report and loot',
        (tester) async {
      final store = await storeWith([
        ...sampleEvents(),
        expeditionStarted('x1', ExpeditionRegion.marketCatacombs,
            when: before(const Duration(hours: 2)), minutes: 30),
      ]);
      await pumpHall(tester,
          store: store, home: const HallScope(child: ExpeditionsScreen()));

      await tester.tap(find.text('Welcome the hero home'));
      await settle(tester);

      final resolved =
          (await store.all()).whereType<ExpeditionResolved>().single;
      expect(find.text('The hero is home!'), findsOneWidget);
      for (final line in resolved.reportLines) {
        expect(find.text(line), findsWidgets);
      }
      await tester.tap(find.text('Huzzah!'));
      await settle(tester);
      expect(find.textContaining('LAST REPORT'), findsOneWidget);
    });
  });
}
