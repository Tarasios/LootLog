import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/hall_common.dart';
import 'package:lootlog/game/ui/hall_ledger_view.dart';
import 'package:lootlog/game/ui/ritual_screen.dart';
import 'package:lootlog/game/ui/vault_screen.dart';

import 'game_home_test.dart' show visibleText;
import 'hall_harness.dart';

final september = Month(2026, 9);

Widget ritual(LinkLog links) => HallScope(
    child: RitualScreen(onOpenLedger: links.openLedger, links: links.links()));

void main() {
  group('Spoils ritual', () {
    testWidgets('each step links to its ledger screen and is marked done in '
        'order', (tester) async {
      final store = await storeWith(sampleEvents());
      final links = LinkLog();
      await pumpHall(tester, store: store, home: ritual(links));

      expect(find.text('September 2026'.toUpperCase()), findsOneWidget);
      // Reconcile and review are done; plan is next.
      await tester.tap(find.text('Open budget setup'));
      expect(links.calls, ['plan 2026-09']);

      await tester.tap(find.text('Mark done').first);
      await settle(tester);
      final steps = (await store.all()).whereType<RitualStepCompleted>();
      expect(steps.last.step, RitualStep.plan);
      expect(steps.last.month, september);

      await tester.tap(find.text('Divide the leftovers').first);
      expect(links.calls.last, 'divide 2026-09');
    });

    testWidgets('the boss waits for all four steps', (tester) async {
      await pumpHall(tester,
          store: await storeWith(sampleEvents()), home: ritual(LinkLog()));
      final face = tester.widget<FilledButton>(find.ancestor(
          of: find.text('Face the Harvest Lich').first,
          matching: find.byWidgetPredicate((w) => w is FilledButton)));
      expect(face.onPressed, isNull);
      expect(find.text('Finish the steps to summon the Harvest Lich.'),
          findsWidgets);
    });

    testWidgets('the boss fight plays turn by turn and the spoils arrive',
        (tester) async {
      final store = await storeWith([
        ...sampleEvents(),
        ritualStep('r3', september, RitualStep.plan,
            when: before(const Duration(hours: 2))),
        ritualStep('r4', september, RitualStep.contribute,
            when: before(const Duration(hours: 2))),
      ]);
      await pumpHall(tester, store: store, home: ritual(LinkLog()));

      await tester.tap(find.text('Face the Harvest Lich').first);
      await settle(tester);

      final fight = (await store.all()).whereType<BossFightResolved>().single;
      final chest = (await store.all()).whereType<ChestGranted>().last;
      expect(chest.chestType, ChestType.spoils);
      expect(find.byType(BossFightScreen), findsOneWidget);
      expect(find.textContaining('Turn 1:'), findsNothing);

      await tester.tap(find.text('Next turn'));
      await tester.pump();
      expect(find.textContaining('Turn 1:'), findsOneWidget);

      await tester.tap(find.text('Skip to the end'));
      await tester.pump();
      expect(find.textContaining('Turn ${fight.turns}:'), findsOneWidget);
      expect(find.text('Back to the hall'), findsOneWidget);
      final copy = visibleText(tester).join(' ').toLowerCase();
      expect(copy, anyOf(contains('spoils'), contains('chest')));
    });

    testWidgets('losing reads as supportive and still pays the spoils',
        (tester) async {
      await pumpHall(tester,
          store: await storeWith(const []),
          home: HallScope(
            child: BossFightScreen(
              month: september,
              seed: 'loss',
              result: const BossResult(
                  bossKey: 'harvestLich', won: false, turns: 6, rewards: Loot.none),
            ),
          ));
      await tester.tap(find.text('Skip to the end'));
      await tester.pump();
      final copy = visibleText(tester).join(' ').toLowerCase();
      for (final word in ['fail', 'defeat', 'lost', 'shame', 'punish']) {
        expect(copy, isNot(contains(word)), reason: word);
      }
      expect(copy, anyOf(contains('spoils'), contains('chest')));
    });

    testWidgets('a fought month offers a replay; the screen works in pixel '
        'tier', (tester) async {
      await pumpHall(tester,
          store: await storeWith([
            ...sampleEvents(),
            bossFight('bf', september, when: before(const Duration(hours: 1))),
          ]),
          tier: AdventureTier.pixel,
          home: ritual(LinkLog()));
      expect(tester.takeException(), isNull);
      expect(find.text('Replay the fight'), findsOneWidget);
    });
  });

  group('Vault', () {
    testWidgets('shows percentages and month runs, never an amount',
        (tester) async {
      final links = LinkLog();
      await pumpHall(tester,
          store: await storeWith(const []),
          home: HallScope(child: VaultScreen(onOpenLedger: links.openLedger)));

      expect(find.text('55%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('[x] 25%  [x] 50%  [ ] 75%  [ ] 100%'), findsOneWidget);
      expect(find.text('4 months in a row with a savings choice.'),
          findsOneWidget);
      expect(find.text('[x] 3 months  [ ] 6 months  [ ] 12 months'),
          findsOneWidget);
      final copy = visibleText(tester).join(' ');
      expect(copy, isNot(contains(r'$')));
    });

    testWidgets('with no goals it points to the ledger', (tester) async {
      final links = LinkLog();
      await pumpHall(tester,
          store: await storeWith(const []),
          view: const HallLedgerView(meId: robin),
          tier: AdventureTier.pixel,
          home: HallScope(child: VaultScreen(onOpenLedger: links.openLedger)));
      await tester.tap(find.text('Open the ledger'));
      expect(links.calls, ['ledger']);
    });
  });
}
