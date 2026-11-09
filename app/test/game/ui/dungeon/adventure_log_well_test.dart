/// The dungeon's adventure log well never shows a line cut in half at its
/// top edge: the scroll area holds whole lines, the spare height sits above
/// it as padding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_battle_layout.dart';

Future<void> _pumpWell(WidgetTester tester, {required double height, required List<String> lines}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 374, height: height, child: AdventureLogWell(lines: lines)),
      ),
    ),
  ));
}

void main() {
  final longLog = [
    for (var turn = 1; turn <= 8; turn++) 'GOBLIN TAKES $turn DMG',
    // Wraps onto a second line in the phone's width.
    'THE CANOE QUEST TAKES 120 DMG',
    'GOBLIN TAKES 9 DMG',
  ];

  for (final height in const [72.0, 90.0, 136.0]) {
    testWidgets('a ${height.toInt()} px well shows only whole lines', (tester) async {
      await _pumpWell(tester, height: height, lines: longLog);
      final viewport = tester.getRect(find.byType(Scrollable));
      final lineHeight = tester.getSize(find.text('GOBLIN TAKES 9 DMG')).height;
      for (final element in find.byType(Text).evaluate()) {
        final entry = tester.getRect(find.byWidget(element.widget));
        if (entry.bottom <= viewport.top || entry.top >= viewport.bottom) continue;
        // An entry may run off the top only by whole lines.
        final hiddenAbove = viewport.top - entry.top;
        if (hiddenAbove > 0) {
          final partialLine = hiddenAbove % lineHeight;
          expect(partialLine < 0.01 || lineHeight - partialLine < 0.01, isTrue,
              reason: '"${(element.widget as Text).data}" is cut mid-line at the top of $viewport');
        }
        expect(entry.bottom, lessThanOrEqualTo(viewport.bottom + 0.01));
      }
      expect(find.byKey(const ValueKey('dungeon-log')), findsOneWidget);
    });
  }

  testWidgets('a short log sits at the top of the well', (tester) async {
    await _pumpWell(tester, height: 136, lines: const ['THE GATE OPENS']);
    final well = tester.getRect(find.byType(AdventureLogWell));
    final line = tester.getRect(find.text('THE GATE OPENS'));
    expect(line.top - well.top, lessThan(40));
  });
}
