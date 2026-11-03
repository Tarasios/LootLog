/// The kit's controls: buttons that never inherit the theme's full-width
/// minimum size (so they lay out in app-bar actions and rows), a wood button
/// that fills its width on request, meters that announce a clamped percent,
/// a HUD button badge, and tap / disabled behaviour.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/game_sprite.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/ui/theme.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: GameSpriteScope(
          tier: AdventureTier.pixel,
          registry: AssetRegistry.empty,
          child: Center(child: child),
        ),
      ),
    );

void main() {
  testWidgets('regression for 9751329: controls lay out in app-bar actions and rows under the app theme',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        appBar: AppBar(actions: [
          WoodButton(label: 'Go', onPressed: () {}),
          HudButton(label: 'Menu', icon: Icons.menu, onPressed: () {}),
        ]),
        body: Row(children: [
          WoodButton(label: 'A', onPressed: () {}),
          const HudChip(icon: Icons.diamond, value: '12'),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Go'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('controls report intrinsic sizes (dialog action bars measure them)', (tester) async {
    await tester.pumpWidget(_host(IntrinsicWidth(
      child: IntrinsicHeight(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          WoodButton(label: 'Save', icon: Icons.check, onPressed: () {}),
          HudButton(label: 'Menu', icon: Icons.menu, onPressed: () {}),
          const HudChip(icon: Icons.diamond, value: '12'),
          const MeterBar(fraction: 0.5),
          const FloatingTag('Ready'),
        ]),
      ),
    )));
    expect(tester.takeException(), isNull);
  });

  testWidgets('WoodButton(expand: true) fills a 300 px box', (tester) async {
    await tester.pumpWidget(_host(SizedBox(
      width: 300,
      child: WoodButton(label: 'Wide', onPressed: () {}, expand: true),
    )));
    expect(tester.getSize(find.byType(WoodButton)).width, 300);
  });

  testWidgets('expand fills loose width too; without it the button hugs its label', (tester) async {
    await tester.pumpWidget(_host(SizedBox(
      width: 300,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WoodButton(key: const Key('wide'), label: 'Wide', onPressed: () {}, expand: true),
        WoodButton(key: const Key('snug'), label: 'Snug', onPressed: () {}),
      ]),
    )));
    expect(tester.getSize(find.byKey(const Key('wide'))).width, 300);
    final snug = tester.getSize(find.byKey(const Key('snug')));
    expect(snug.width, lessThan(300));
    expect(snug.width, greaterThanOrEqualTo(64));
    expect(snug.height, greaterThanOrEqualTo(44));
  });

  testWidgets('MeterBar announces its fraction as a clamped percent', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(const SizedBox(
      width: 120,
      child: MeterBar(fraction: 1.7, semanticsLabel: 'Canoe'),
    )));
    expect(tester.getSemantics(find.byType(MeterBar)).value, '100%');
    expect(tester.getSemantics(find.byType(MeterBar)).label, 'Canoe');

    await tester.pumpWidget(_host(const SizedBox(width: 120, child: MeterBar(fraction: 0.25))));
    expect(tester.getSemantics(find.byType(MeterBar)).value, '25%');

    await tester.pumpWidget(_host(const SizedBox(width: 120, child: MeterBar(fraction: -0.5))));
    expect(tester.getSemantics(find.byType(MeterBar)).value, '0%');
    semantics.dispose();
  });

  testWidgets('MeterBar lays out with unbounded width', (tester) async {
    await tester.pumpWidget(_host(const Row(mainAxisSize: MainAxisSize.min, children: [
      MeterBar(fraction: 0.5),
    ])));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(MeterBar)).height, 10);
  });

  testWidgets('HudButton shows its badge', (tester) async {
    await tester.pumpWidget(_host(HudButton(label: 'Quests', icon: Icons.flag, onPressed: () {}, badge: '3')));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Quests'), findsOneWidget);
  });

  testWidgets('a large HudButton lays out its icon beside the label', (tester) async {
    await tester.pumpWidget(_host(HudButton(label: 'Log', icon: Icons.add, onPressed: () {}, large: true)));
    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(HudButton));
    expect(size.width, greaterThan(size.height));
  });

  testWidgets('tapping WoodButton calls onPressed; null renders disabled', (tester) async {
    var presses = 0;
    await tester.pumpWidget(_host(WoodButton(label: 'Press', onPressed: () => presses++)));
    await tester.tap(find.text('Press'));
    await tester.pump();
    expect(presses, 1);

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(const WoodButton(label: 'Off', onPressed: null)));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Off'), warnIfMissed: false);
    await tester.pump();
    expect(
      tester.getSemantics(find.byType(WoodButton)),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false, label: 'Off'),
    );
    semantics.dispose();
  });

  testWidgets('pressing WoodButton shifts its label 2 px down', (tester) async {
    await tester.pumpWidget(_host(WoodButton(label: 'Push', onPressed: () {})));
    final resting = tester.getTopLeft(find.text('Push'));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Push')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(find.text('Push')), resting + const Offset(0, 2));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(find.text('Push')), resting);
  });

  testWidgets('HudChip puts valueKey on the value and taps through', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(HudChip(
      icon: Icons.diamond,
      value: '120',
      label: 'gems',
      valueKey: const Key('gem-count'),
      onTap: () => taps++,
    )));
    expect(tester.widget<Text>(find.byKey(const Key('gem-count'))).data, '120');
    expect(find.text('gems'), findsOneWidget);
    await tester.tap(find.byType(HudChip));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('FloatingTag renders plain and urgent', (tester) async {
    await tester.pumpWidget(_host(const Column(mainAxisSize: MainAxisSize.min, children: [
      FloatingTag('Ready'),
      FloatingTag('Enraged!', icon: Icons.warning, urgent: true),
    ])));
    expect(tester.takeException(), isNull);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Enraged!'), findsOneWidget);
    expect(find.byIcon(Icons.warning), findsOneWidget);
  });
}
