/// The Adventure theme: pixel-font headings over legible body text, finite
/// button minimums (so buttons lay out in app-bar actions), and the app's
/// theme choice — Standard keeps [AppTheme] exactly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/ui/kit/adventure_theme.dart';
import 'package:lootlog/game/ui/kit/adventure_tokens.dart';
import 'package:lootlog/features/shell/app_shell.dart' show kWideBreakpoint;
import 'package:lootlog/main.dart';
import 'package:lootlog/ui/theme.dart';

void main() {
  test('Adventure switches to its wide layouts where Standard does', () {
    expect(AdventureTokens.wideBreakpoint, kWideBreakpoint);
  });

  test('headings use the pixel font at crisp sizes; body text keeps the default face', () {
    final textTheme = AdventureTheme.build().textTheme;
    expect(textTheme.titleLarge!.fontFamily, 'LootPixel');
    final pixelStyles = [
      textTheme.headlineLarge, textTheme.headlineMedium, textTheme.headlineSmall,
      textTheme.titleLarge,
    ];
    for (final style in pixelStyles) {
      expect(style!.fontFamily, AdventureTokens.pixelFont);
      expect(style.fontSize! % AdventureTokens.pixelFontStep, 0, reason: '$style');
    }
    for (final style in [
      textTheme.bodyLarge, textTheme.bodyMedium, textTheme.bodySmall,
      // Small amounts and captions are drawn in these.
      textTheme.titleSmall, textTheme.labelLarge, textTheme.labelMedium,
      textTheme.labelSmall,
    ]) {
      expect(style!.fontFamily, isNot(AdventureTokens.pixelFont));
    }
  });

  test('the roles money is drawn in keep the default face', () {
    // AppText.amount, heroAmount and metricValue build on these, bold.
    final textTheme = AdventureTheme.build().textTheme;
    for (final style in [
      textTheme.displayLarge, textTheme.displayMedium, textTheme.displaySmall, textTheme.titleMedium,
    ]) {
      expect(style!.fontFamily, isNot(AdventureTokens.pixelFont));
    }
  });

  test('wood, parchment and ribbon drive the colour scheme', () {
    final theme = AdventureTheme.build();
    expect(theme.colorScheme.surface, AdventureTokens.parchment);
    expect(theme.colorScheme.onSurface, AdventureTokens.ink);
    expect(theme.colorScheme.primary, AdventureTokens.ribbon);
    expect(theme.scaffoldBackgroundColor, AdventureTokens.parchmentDark);
  });

  testWidgets('a FilledButton lays out in app-bar actions under the Adventure theme', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AdventureTheme.build(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Ledger'),
          actions: [
            FilledButton(onPressed: () {}, child: const Text('Log')),
            OutlinedButton(onPressed: () {}, child: const Text('Undo')),
            ElevatedButton(onPressed: () {}, child: const Text('Sync')),
          ],
        ),
        body: const Center(child: Card(child: Text('card'))),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Log'), findsOneWidget);
  });

  group('appThemeFor', () {
    test('Standard keeps AppTheme exactly', () {
      expect(appThemeFor(adventure: false, brightness: Brightness.light).colorScheme,
          AppTheme.light().colorScheme);
      expect(appThemeFor(adventure: false, brightness: Brightness.dark).colorScheme,
          AppTheme.dark().colorScheme);
    });

    test('Adventure uses the pixel-font Adventure theme in both brightnesses', () {
      for (final brightness in Brightness.values) {
        final theme = appThemeFor(adventure: true, brightness: brightness);
        expect(theme.textTheme.titleLarge!.fontFamily, 'LootPixel');
        expect(theme.colorScheme.surface, AdventureTokens.parchment);
      }
    });
  });
}
