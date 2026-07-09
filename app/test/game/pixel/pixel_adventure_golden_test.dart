import 'dart:ui' as ui;

import 'package:duobudget/game/game_sprite.dart';
import 'package:duobudget/game/game_state.dart';
import 'package:duobudget/game/pixel/pixel_adventure_view.dart';
import 'package:duobudget/game/text_mode/text_adventure_view.dart';
import 'package:duobudget/ui/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../adventure_fixtures.dart';

/// A deterministic sprite resolver for the tier-1 golden: every sprite resolves
/// to the same crisp 2-colour checker, built synchronously (no async decode, no
/// real art files), so "sprites present" renders reproducibly.
class _CheckerSpriteResolver implements SpriteResolver {
  _CheckerSpriteResolver() : _image = _buildChecker();

  final ui.Image _image;

  @override
  ImageProvider? resolve(SpriteRef ref) => _StaticImageProvider(_image);

  static ui.Image _buildChecker() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    const cell = 8.0;
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        paint.color = (x + y).isEven
            ? const Color(0xFF6DAA2C) // DB16 leaf green
            : const Color(0xFF30346D); // DB16 navy
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
      }
    }
    return recorder.endRecording().toImageSync(32, 32);
  }
}

/// An [ImageProvider] backed by an already-decoded [ui.Image], delivered
/// synchronously so the golden is stable on the first pump.
class _StaticImageProvider extends ImageProvider<_StaticImageProvider> {
  _StaticImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_StaticImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_StaticImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
      _StaticImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone())),
    );
  }

  @override
  bool operator ==(Object other) => other is _StaticImageProvider;

  @override
  int get hashCode => runtimeType.hashCode;
}

Widget _host(Widget child, {required Size size}) => MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: SizedBox.fromSize(size: size, child: child),
        ),
      ),
    );

void main() {
  final game = sampleGameStateWithRoster();
  final log = sampleAdventureLog();

  Future<void> pumpAt(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(child, size: size));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('tier 1 — full pixel art (sprites present)', (tester) async {
    await pumpAt(
      tester,
      PixelAdventureView(
        game: game,
        log: log,
        resolver: _CheckerSpriteResolver(),
        animate: false,
        spoilsPending: true,
      ),
      const Size(1024, 720),
    );
    await expectLater(
      find.byType(PixelAdventureView),
      matchesGoldenFile('goldens/pixel_tier1_art.png'),
    );
  });

  testWidgets('tier 2 — partial (missing sprites degrade to placeholders)',
      (tester) async {
    await pumpAt(
      tester,
      PixelAdventureView(
        game: game,
        log: log,
        // Default PlaceholderSpriteResolver: every sprite is a labelled card.
        animate: false,
        spoilsPending: true,
      ),
      const Size(1024, 720),
    );
    await expectLater(
      find.byType(PixelAdventureView),
      matchesGoldenFile('goldens/pixel_tier2_placeholder.png'),
    );
  });

  testWidgets('tier 3 — text mode (no art at all)', (tester) async {
    await pumpAt(
      tester,
      TextAdventureView(game: game, log: log),
      const Size(720, 1400),
    );
    await expectLater(
      find.byType(TextAdventureView),
      matchesGoldenFile('goldens/pixel_tier3_text.png'),
    );
  });
}
