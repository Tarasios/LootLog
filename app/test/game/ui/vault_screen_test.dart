import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/hall_common.dart';
import 'package:lootlog/game/ui/hall_ledger_view.dart';
import 'package:lootlog/game/ui/vault_screen.dart';

import 'game_home_test.dart' show visibleText;
import 'hall_harness.dart';

void main() {
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
