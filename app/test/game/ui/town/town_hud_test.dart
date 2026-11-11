/// The town HUD on its own: on a phone its two top corners never collide,
/// however long the streak or large the war chest, and decorating keeps
/// "Log purchase" one tap away.
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
  List<Widget> logNotes = const [],
  Widget noSpendCheckIn = const Text('No spend today'),
  Widget? districtStrip,
}) =>
    MaterialApp(
      home: Scaffold(
        body: TownHud(
          figures: figures,
          noSpendCheckIn: noSpendCheckIn,
          logNotes: logNotes,
          districtStrip: districtStrip,
          onLogPurchase: onLogPurchase ?? () {},
          onShop: () {},
          onInbox: () {},
          onLedger: () {},
          onMenu: () {},
          decoratePanel: decoratePanel,
        ),
      ),
    );

const TownHudFigures _everyday = TownHudFigures(
  dateLabel: 'Oct · day 3',
  streak: LiveStreak(days: 3, frozenDays: 0),
  freezeTokens: 1,
  gems: 130,
  inboxCount: 0,
  goldPouch: Money(7000),
  warChest: Money(123456),
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

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets('decorating keeps Log purchase on screen at ${size.width.toInt()} wide', (tester) async {
      var logged = 0;
      await _pumpAt(
        tester,
        size,
        _hud(
          figures: _everyday,
          onLogPurchase: () => logged++,
          decoratePanel: const SizedBox(height: 120, child: Text('Decoration tray')),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Decoration tray'), findsOneWidget);
      expect(find.textContaining('Menu'), findsOneWidget);
      await tester.tap(find.textContaining('Log purchase'));
      expect(logged, 1);
    });
  }

  /// A chip stand-in [width] wide, as tall as a HUD chip.
  Widget chip(String key, double width) =>
      SizedBox(key: ValueKey(key), width: width, height: 28, child: const ColoredBox(color: Colors.amber));

  testWidgets('on a phone the crews chip and the check-in share one row when they fit', (tester) async {
    await _pumpAt(
      tester,
      const Size(390, 844),
      _hud(
        figures: _everyday,
        logNotes: [chip('crews', 170)],
        noSpendCheckIn: chip('check-in', 170),
        districtStrip: chip('strip', 300),
      ),
    );
    expect(tester.takeException(), isNull);
    final crews = tester.getRect(find.byKey(const ValueKey('crews')));
    final checkIn = tester.getRect(find.byKey(const ValueKey('check-in')));
    final strip = tester.getRect(find.byKey(const ValueKey('strip')));
    final log = tester.getRect(find.textContaining('Log purchase'));
    expect(checkIn.top, crews.top, reason: 'one row: $crews / $checkIn');
    expect(checkIn.left, greaterThan(crews.right));
    expect(strip.top, greaterThan(crews.bottom));
    expect(log.top, greaterThan(strip.bottom));
  });

  testWidgets('at 360x780 chips too wide for one row wrap without overflow', (tester) async {
    var logged = 0;
    await _pumpAt(
      tester,
      const Size(360, 780),
      _hud(
        figures: _everyday,
        onLogPurchase: () => logged++,
        logNotes: [chip('crews', 220), chip('open-town', 200)],
        noSpendCheckIn: chip('check-in', 220),
        districtStrip: chip('strip', 300),
      ),
    );
    expect(tester.takeException(), isNull);
    final crews = tester.getRect(find.byKey(const ValueKey('crews')));
    final checkIn = tester.getRect(find.byKey(const ValueKey('check-in')));
    expect(checkIn.top, greaterThan(crews.top), reason: 'wrapped to a second row');
    expect(checkIn.right, lessThanOrEqualTo(360));
    await tester.tap(find.textContaining('Log purchase'));
    expect(logged, 1);
  });
}
