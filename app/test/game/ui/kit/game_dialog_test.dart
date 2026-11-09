/// The game dialog: shown as a route it carries its ribbon title, body and
/// wood action buttons, pops with an action's value, closes through its X and
/// on Escape when dismissible, and draws its fallbacks with no art at all.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/game_sprite.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/kit/kit.dart';

/// A tier that never touches the device's saved preference.
class _FixedTier extends AdventureTierNotifier {
  @override
  AdventureTier build() => AdventureTier.pixel;
}

/// A screen with one button that opens [dialog] through [showGameDialog] and
/// records what the dialog popped with in [results].
Widget _launcher({
  required WidgetBuilder dialog,
  required List<Object?> results,
  bool barrierDismissible = true,
}) =>
    ProviderScope(
      overrides: [
        adventureTierProvider.overrideWith(_FixedTier.new),
        gameAssetRegistryProvider.overrideWith((ref) async => AssetRegistry.empty),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async => results.add(await showGameDialog<String>(
                  context,
                  builder: dialog,
                  barrierDismissible: barrierDismissible,
                )),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the title, body and actions; an action pops with its value', (tester) async {
    final results = <Object?>[];
    await tester.pumpWidget(_launcher(
      results: results,
      dialog: (context) => GameDialog(
        title: 'Treasure found',
        body: const Text('A chest of gems!'),
        actions: [
          WoodButton(label: 'Open it', onPressed: () => Navigator.of(context).pop('opened')),
        ],
      ),
    ));
    await _open(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Treasure found'), findsOneWidget);
    expect(find.text('A chest of gems!'), findsOneWidget);
    expect(find.byType(RibbonTitle), findsOneWidget);
    expect(find.byType(WoodPanel), findsOneWidget);
    expect(find.byType(ParchmentCard), findsOneWidget);

    await tester.tap(find.text('Open it'));
    await tester.pumpAndSettle();
    expect(find.text('Treasure found'), findsNothing);
    expect(results, ['opened']);
  });

  testWidgets('pack art resolves inside the route: the sprite scope wraps the dialog', (tester) async {
    await tester.pumpWidget(_launcher(
      results: [],
      dialog: (context) => const GameDialog(title: 'Scope', body: Text('body')),
    ));
    await _open(tester);

    final scope = GameSpriteScope.maybeOf(tester.element(find.text('body')));
    expect(scope, isNotNull);
    expect(scope!.registry, same(AssetRegistry.empty));
    expect(scope.tier, AdventureTier.pixel);
  });

  testWidgets('the X calls onClose; no X without onClose', (tester) async {
    var closed = 0;
    await tester.pumpWidget(_launcher(
      results: [],
      dialog: (context) => GameDialog(
        title: 'Closable',
        body: const Text('body'),
        onClose: () => closed++,
      ),
    ));
    await _open(tester);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(closed, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_launcher(
      results: [],
      dialog: (context) => const GameDialog(title: 'Fixed', body: Text('body')),
    ));
    await _open(tester);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('the X sits clear of the scene well and the body', (tester) async {
    await tester.pumpWidget(_launcher(
      results: [],
      dialog: (context) => GameDialog(
        title: 'Closable',
        scene: const ColoredBox(color: Colors.black),
        body: const Text('body'),
        onClose: () {},
      ),
    ));
    await _open(tester);
    final closeButton = tester.getRect(find.byKey(const ValueKey('game-dialog-close')));
    final wellTop = tester.getRect(find.byType(InsetWell)).top;
    expect(closeButton.bottom, lessThanOrEqualTo(wellTop));
  });

  testWidgets('Escape closes a dismissible dialog only', (tester) async {
    final results = <Object?>[];
    await tester.pumpWidget(_launcher(
      results: results,
      dialog: (context) => const GameDialog(title: 'Dismissible', body: Text('body')),
    ));
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Dismissible'), findsNothing);
    expect(results, [null]);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_launcher(
      results: results,
      barrierDismissible: false,
      dialog: (context) => const GameDialog(title: 'Sticky', body: Text('body')),
    ));
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Sticky'), findsOneWidget);
  });

  testWidgets('a tall body scrolls inside a short screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_launcher(
      results: [],
      dialog: (context) => GameDialog(
        title: 'Long tale',
        scene: const ColoredBox(color: Colors.green),
        body: Column(children: [for (var line = 0; line < 40; line++) Text('line $line')]),
        actions: [WoodButton(label: 'Done', onPressed: () {})],
      ),
    ));
    await _open(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('inline, in an unbounded column, the dialog still lays out', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GameSpriteScope(
          tier: AdventureTier.pixel,
          registry: AssetRegistry.empty,
          child: SingleChildScrollView(
            child: GameDialog(
              title: 'Inline',
              body: const Text('body'),
              actions: [
                WoodButton(label: 'Yes', onPressed: () {}),
                WoodButton(label: 'No', tone: WoodButtonTone.secondary, onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Inline'), findsOneWidget);
  });

  testWidgets('narrow screens stack the actions full width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_launcher(
      results: [],
      dialog: (context) => GameDialog(
        title: 'Choose',
        body: const Text('body'),
        actions: [
          WoodButton(label: 'Yes', onPressed: () {}),
          WoodButton(label: 'No', tone: WoodButtonTone.secondary, onPressed: () {}),
        ],
      ),
    ));
    await _open(tester);
    final yes = tester.getRect(find.byType(WoodButton).first);
    final no = tester.getRect(find.byType(WoodButton).last);
    expect(yes.width, no.width);
    expect(no.top, greaterThan(yes.bottom - 1));
    expect(yes.width, greaterThan(200));
  });
}
