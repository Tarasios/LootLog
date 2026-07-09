import 'package:duobudget/game/game_sprite.dart';
import 'package:duobudget/game/pixel/pixel_adventure_view.dart';
import 'package:duobudget/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../adventure_fixtures.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

/// A surface tall enough that every region of the (scrolling) main screen is
/// laid out and mounted, so `find.text` can reach the minimap and treasury.
void _bigSurface(WidgetTester t) {
  t.view.physicalSize = const Size(1100, 1700);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  final game = sampleGameStateWithRoster();
  final log = sampleAdventureLog();

  testWidgets('renders the floor, party frames, monsters, minimap and log',
      (t) async {
    _bigSurface(t);
    await t.pumpWidget(_wrap(PixelAdventureView(
      game: game,
      log: log,
      animate: false,
    )));

    // Prime action and the two-way toggles are present.
    expect(find.text('Strike a monster'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);

    // Every party frame (adventurer, companion, familiar) shows.
    expect(find.text('Robin'), findsWidgets);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Iris'), findsOneWidget);
    expect(find.text('Mochi'), findsOneWidget);

    // A monster on the floor, a quest boss, the year minimap, and the log.
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Canoe'), findsOneWidget);
    expect(find.text('YEAR 2026'), findsOneWidget);
    expect(find.text(r'GROCERIES MONSTER TAKES $42.00 DMG'), findsOneWidget);

    // Sprites are drawn through the shared pixel pipeline; nothing throws.
    expect(find.byType(GameSprite), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('Strike, Text and Classic fire their callbacks', (t) async {
    var struck = 0;
    var text = 0;
    var classic = 0;
    await t.pumpWidget(_wrap(PixelAdventureView(
      game: game,
      log: log,
      animate: false,
      callbacks: PixelAdventureCallbacks(
        onStrikeMonster: () => struck++,
        onSwitchToText: () => text++,
        onSwitchToClassic: () => classic++,
      ),
    )));

    await t.tap(find.text('Strike a monster'));
    await t.tap(find.byTooltip('Text mode'));
    await t.tap(find.text('Classic'));
    expect(struck, 1);
    expect(text, 1);
    expect(classic, 1);
  });

  testWidgets('tier 2: missing sprites degrade without throwing', (t) async {
    // The default PlaceholderSpriteResolver resolves nothing, so every sprite
    // falls back to its labelled placeholder card — no crash, no red box.
    await t.pumpWidget(_wrap(PixelAdventureView(
      game: game,
      log: log,
      animate: false,
    )));
    expect(find.byType(GameSprite), findsWidgets);
    expect(find.text('Food'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
