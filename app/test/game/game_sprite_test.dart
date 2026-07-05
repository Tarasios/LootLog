import 'package:duobudget/game/game_sprite.dart';
import 'package:duobudget/game/game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('spriteFrameCount', () {
    test('parses the _Nf suffix', () {
      expect(spriteFrameCount('monster_idle_4f.png'), 4);
      expect(spriteFrameCount('coin_spin_6f.png'), 6);
      expect(spriteFrameCount('gold_pouch_1f.png'), 1);
      expect(spriteFrameCount('big_12f.png'), 12);
    });

    test('missing or malformed suffix is a single frame', () {
      expect(spriteFrameCount('no_suffix.png'), 1);
      expect(spriteFrameCount('trophy.png'), 1);
      expect(spriteFrameCount('weird_0f.png'), 1);
      expect(spriteFrameCount('frames_2.png'), 1); // no trailing f
    });
  });

  group('spriteFrameSrc', () {
    test('slices a horizontal strip into uniform frames', () {
      const size = Size(64, 16); // 4 frames of 16
      expect(spriteFrameSrc(size, 4, 0), const Rect.fromLTWH(0, 0, 16, 16));
      expect(spriteFrameSrc(size, 4, 2), const Rect.fromLTWH(32, 0, 16, 16));
    });

    test('wraps the frame index and guards a zero count', () {
      const size = Size(48, 16);
      expect(spriteFrameSrc(size, 3, 5), const Rect.fromLTWH(48 / 3 * 2, 0, 16, 16));
      expect(spriteFrameSrc(size, 0, 0), const Rect.fromLTWH(0, 0, 48, 16));
    });
  });

  group('GameSprite placeholder', () {
    testWidgets('renders a labelled placeholder when art is unavailable',
        (tester) async {
      await tester.pumpWidget(_host(const GameSprite(
        sprite: SpriteRef.asset('missing_4f.png', label: 'War Chest'),
        // Default PlaceholderSpriteResolver -> never resolves.
      )));
      await tester.pump();
      // Initials of the label are shown; no exception is thrown.
      expect(find.text('WC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sizes the box to base * integer scale', (tester) async {
      await tester.pumpWidget(_host(const GameSprite(
        sprite: SpriteRef.asset('missing_1f.png', label: 'Gold'),
        scale: 4,
      )));
      await tester.pump();
      final box = tester.getSize(find.byType(GameSprite));
      expect(box.width, kSpriteBaseSize * 4);
      expect(box.height, kSpriteBaseSize * 4);
    });

    testWidgets('an unresolved custom blob also shows a placeholder',
        (tester) async {
      await tester.pumpWidget(_host(const GameSprite(
        sprite: SpriteRef.custom('deadbeef', label: 'Mochi'),
        resolver: AssetSpriteResolver(), // no bytes for the sha -> null
      )));
      await tester.pump();
      expect(find.text('M'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('GameSprite.widgetFrameCount treats custom sprites as single-frame', () {
    expect(
      GameSprite.widgetFrameCount(
          const SpriteRef.custom('abc', label: 'x')),
      1,
    );
    expect(
      GameSprite.widgetFrameCount(
          const SpriteRef.asset('a_4f.png', label: 'x')),
      4,
    );
  });
}
