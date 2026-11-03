/// The kit's screen header: the back button only where there is somewhere to
/// go back to, the title on its ribbon, and trailing chips that wrap on a
/// phone instead of overflowing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/ui/kit/kit.dart';

Widget _app({required Widget home}) => MaterialApp(theme: AdventureTheme.build(), home: home);

void main() {
  testWidgets('shows the title and no back button on a root route', (tester) async {
    await tester.pumpWidget(_app(
      home: const Scaffold(body: GameScreenHeader(title: 'Vault')),
    ));
    expect(find.text('Vault'), findsOneWidget);
    expect(find.byKey(const ValueKey('game-back')), findsNothing);
  });

  testWidgets('back button pops the route', (tester) async {
    await tester.pumpWidget(_app(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: GameScreenHeader(title: 'Forge')),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Forge'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-back')));
    await tester.pumpAndSettle();
    expect(find.text('Forge'), findsNothing);
  });

  testWidgets('many chips on a phone wrap without overflowing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(
      home: Scaffold(
        body: GameScreenHeader(
          title: 'Forge',
          trailing: [
            for (var index = 0; index < 6; index++)
              HudChip(icon: Icons.diamond, value: '${index * 111}', label: 'gems'),
          ],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(HudChip), findsNWidgets(6));
  });
}
