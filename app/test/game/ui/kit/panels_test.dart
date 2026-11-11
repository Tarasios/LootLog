/// The kit's frames and panels: each renders its child with no art at all
/// (the drawn fallback), switches to the 9-slice painter once a pack region
/// decodes, and a tappable parchment card calls back.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/assets/sprite_region.dart';
import 'package:lootlog/game/game_sprite.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/kit/kit.dart';

const _sheetPath = 'packs/ui_pixel_adventure/tilemap_packed.png';

const _woodRegistry = AssetRegistry({}, {
  'ui.panel.wood.idle': SpriteRegion(sheetPath: _sheetPath, column: 1, row: 0, cellSize: 32),
});

Widget _host(Widget child, {AssetRegistry registry = AssetRegistry.empty, AdventureTier tier = AdventureTier.pixel}) =>
    MaterialApp(
      home: Scaffold(
        body: GameSpriteScope(
          tier: tier,
          registry: registry,
          child: Center(child: child),
        ),
      ),
    );

/// Kit painters (a [CustomPaint] carrying a [NineSlicePainter]) under [of].
Finder _slicePaintsUnder(Finder of) => find.descendant(
      of: of,
      matching: find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is NineSlicePainter),
    );

/// Loads and decodes the UI sheet for real, then lets the frame repaint.
Future<void> _decodeSheet(WidgetTester tester) async {
  await tester.runAsync(() async {
    final element = tester.element(find.byType(Scaffold));
    await precacheImage(const AssetImage('${AssetRegistry.assetDir}$_sheetPath'), element);
  });
  await tester.pump();
}

void main() {
  group('no art: every panel draws its fallback', () {
    final panels = <String, (Widget, String)>{
      'WoodPanel': (const WoodPanel(child: Text('wood child')), 'wood child'),
      'ParchmentCard': (const ParchmentCard(child: Text('card child')), 'card child'),
      'InsetWell': (const InsetWell(child: Text('well child')), 'well child'),
      'RibbonTitle': (const RibbonTitle('Quest board'), 'Quest board'),
    };
    for (final MapEntry(key: name, value: (panel, text)) in panels.entries) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(_host(panel));
        expect(tester.takeException(), isNull);
        expect(find.text(text), findsOneWidget);
        expect(find.descendant(of: find.byWidget(panel), matching: find.byType(DecoratedBox)), findsWidgets);
        expect(_slicePaintsUnder(find.byWidget(panel)), findsNothing);
      });
    }
  });

  testWidgets('the text tier draws the fallback even when the art exists', (tester) async {
    await tester.pumpWidget(_host(const WoodPanel(child: Text('wood child')),
        registry: _woodRegistry, tier: AdventureTier.text));
    await _decodeSheet(tester);
    expect(find.text('wood child'), findsOneWidget);
    expect(_slicePaintsUnder(find.byType(WoodPanel)), findsNothing);
  });

  testWidgets('a wood region paints the 9-slice once decoded', (tester) async {
    await tester.pumpWidget(_host(const WoodPanel(child: Text('wood child')), registry: _woodRegistry));
    await _decodeSheet(tester);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(_slicePaintsUnder(find.byType(WoodPanel)), findsOneWidget);
    expect(find.text('wood child'), findsOneWidget);
  });

  testWidgets('decoding never moves the content', (tester) async {
    await tester.pumpWidget(_host(const WoodPanel(child: Text('wood child')), registry: _woodRegistry));
    final before = tester.getRect(find.text('wood child'));
    final sizeBefore = tester.getSize(find.byType(WoodPanel));
    await _decodeSheet(tester);
    expect(tester.getRect(find.text('wood child')), before);
    expect(tester.getSize(find.byType(WoodPanel)), sizeBefore);
  });

  testWidgets('a parchment card with onTap calls back', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(ParchmentCard(onTap: () => taps++, child: const Text('tap me'))));
    await tester.tap(find.text('tap me'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('tokens: pixel fonts on title and label, tabular amounts', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(_host(Builder(builder: (context) {
      captured = context;
      return const SizedBox();
    })));
    expect(AdventureTokens.title(captured).fontFamily, AdventureTokens.pixelFont);
    expect(AdventureTokens.label(captured).fontFamily, AdventureTokens.pixelFont);
    expect(AdventureTokens.title(captured).color, AdventureTokens.ink);
    // The pixel font is crisp only at whole multiples of its native step.
    expect(AdventureTokens.label(captured).fontSize, AdventureTokens.pixelFontStep * 2);
    expect(AdventureTokens.title(captured).fontSize, AdventureTokens.pixelFontStep * 3);
    final amount = AdventureTokens.amount(captured);
    expect(amount.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(amount.color, AdventureTokens.ink);
    expect(KitKeys.wood.value, 'ui.panel.wood.idle');
    expect(KitKeys.ribbon.value, 'ui.banner.ribbon.idle');
  });
}
