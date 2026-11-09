/// The town HUD on its own: on a phone its two top corners never collide,
/// however long the streak or large the war chest.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/money.dart';
import 'package:lootlog/game/ui/hall_status.dart';
import 'package:lootlog/game/ui/town/town_hud.dart';

Widget _hud({
  required TownHudFigures figures,
  VoidCallback? onLogPurchase,
  Widget? decoratePanel,
}) =>
    MaterialApp(
      home: Scaffold(
        body: TownHud(
          figures: figures,
          noSpendCheckIn: const Text('No spend today'),
          onLogPurchase: onLogPurchase ?? () {},
          onShop: () {},
          onInbox: () {},
          onLedger: () {},
          onMenu: () {},
          decoratePanel: decoratePanel,
        ),
      ),
    );

Future<void> _pumpAt(WidgetTester tester, Size size, Widget hud) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(hud);
}

void main() {
  testWidgets('on a phone a long streak and a huge war chest never collide', (tester) async {
    await _pumpAt(
      tester,
      const Size(360, 780),
      _hud(
        figures: const TownHudFigures(
          dateLabel: 'Sep · day 30',
          streak: LiveStreak(days: 12345, frozenDays: 0),
          freezeTokens: 12,
          gems: 9876543,
          inboxCount: 3,
          goldPouch: Money(98765432100),
          warChest: Money(99999999900),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final timeCorner = tester.getRect(find.byKey(const ValueKey('town-hud-time')));
    final treasureCorner = tester.getRect(find.byKey(const ValueKey('town-hud-treasure')));
    expect(timeCorner.overlaps(treasureCorner), isFalse,
        reason: 'time $timeCorner vs treasure $treasureCorner');
    expect(timeCorner.left, greaterThanOrEqualTo(0));
    expect(treasureCorner.right, lessThanOrEqualTo(360));
  });

  testWidgets('a wide window keeps its corners apart too', (tester) async {
    await _pumpAt(
      tester,
      const Size(700, 600),
      _hud(
        figures: const TownHudFigures(
          dateLabel: 'Sep · day 30',
          streak: LiveStreak(days: 12345, frozenDays: 0),
          freezeTokens: 12,
          gems: 9876543,
          inboxCount: 0,
          goldPouch: Money(98765432100),
          warChest: Money(99999999900),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final timeCorner = tester.getRect(find.byKey(const ValueKey('town-hud-time')));
    final treasureCorner = tester.getRect(find.byKey(const ValueKey('town-hud-treasure')));
    expect(timeCorner.overlaps(treasureCorner), isFalse);
  });
}
