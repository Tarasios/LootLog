/// The vault, forge and expeditions in the pixel tier: the wood header with
/// its chips, the same behaviour as the text tier through wood buttons, and
/// the celebration as a game dialog.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/expeditions_screen.dart';
import 'package:lootlog/game/ui/forge_screen.dart';
import 'package:lootlog/game/ui/hall_common.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/game/ui/vault_screen.dart';

import 'hall_harness.dart';

List<GameEvent> _withForge() => [
      ...sampleEvents(),
      built('f1', 2, BuildingType.forge, when: before(const Duration(hours: 4))),
      granted('f2',
          when: before(const Duration(hours: 4)),
          rewardId: 'ore',
          materials: MaterialBundle({MaterialKind.ore: 20})),
      claimed('f3', 'ore', when: before(const Duration(hours: 4))),
    ];

void main() {
  testWidgets('vault: header, gems chip and quarter marks', (tester) async {
    await pumpHall(tester,
        store: await storeWith(sampleEvents()),
        tier: AdventureTier.pixel,
        home: HallScope(child: VaultScreen(onOpenLedger: () {})));
    expect(find.byType(GameScreenHeader), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Vault'), findsOneWidget);
    expect(find.byKey(const ValueKey('hall-gems')), findsOneWidget);
    expect(find.text('55%'), findsOneWidget);
    expect(find.byType(MeterBar), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forge: pick a type and forge with wood buttons', (tester) async {
    final store = await storeWith(_withForge());
    await pumpHall(tester,
        store: store, tier: AdventureTier.pixel, home: const HallScope(child: ForgeScreen()));
    expect(find.byKey(const ValueKey('hall-material-ore')), findsOneWidget);
    expect(find.byKey(const ValueKey('forge-power')), findsOneWidget);

    await tester.ensureVisible(find.text('Bow'));
    await tester.tap(find.text('Bow'));
    await tester.pump();
    await tester.ensureVisible(find.text('Forge tier 1').first);
    await tester.tap(find.text('Forge tier 1').first);
    await settle(tester);

    final upgrade = (await store.all()).whereType<GearUpgraded>().single;
    expect((upgrade.slot, upgrade.gearType, upgrade.tier), ('weapon', 'bow', 1));
    expect(find.text('Weapon: Bow T1'), findsOneWidget);
  });

  testWidgets('expeditions: send, then welcome home with a game dialog', (tester) async {
    final store = await storeWith([
      ...sampleEvents(),
      expeditionStarted('x1', ExpeditionRegion.marketCatacombs,
          when: before(const Duration(hours: 2)), minutes: 30),
    ]);
    await pumpHall(tester,
        store: store,
        tier: AdventureTier.pixel,
        home: const HallScope(child: ExpeditionsScreen()));
    expect(find.byKey(const ValueKey('hall-stores')), findsOneWidget);

    await tester.tap(find.text('Welcome the hero home'));
    await settle(tester);
    expect(find.byType(GameDialog), findsOneWidget);
    expect(find.text('The hero is home!'), findsOneWidget);
    await tester.tap(find.text('Huzzah!'));
    await settle(tester);
    expect(find.byType(GameDialog), findsNothing);

    await tester.ensureVisible(find.text('Send the hero').first);
    await tester.tap(find.text('Send the hero').first);
    await settle(tester);
    expect((await store.all()).whereType<ExpeditionStarted>(), hasLength(2));
    expect(find.byType(MeterBar), findsWidgets);
  });
}
