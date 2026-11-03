/// Shared setup for the decoration screens' goldens: the screen sizes, and a
/// helper that decodes every bundled image (the UI pack's frames and the
/// sprite sheets) so the pixel art paints within a few frames of the test
/// clock.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_registry.dart';

/// The phone and desktop sizes the decoration goldens are drawn at.
const decorGoldenSizes = [
  ('phone', Size(390, 844)),
  ('desktop', Size(1440, 900)),
];

/// Decodes every image [registry] can draw, using the first element
/// [contextFinder] locates for the image configuration, then pumps a few
/// frames so the decoded art paints.
Future<void> decodeAllGameArt(
  WidgetTester tester,
  AssetRegistry registry,
  Finder contextFinder,
) async {
  final paths = {
    for (final fileName in registry.files.values) '${AssetRegistry.assetDir}$fileName',
    for (final region in registry.regions.values) '${AssetRegistry.assetDir}${region.sheetPath}',
  };
  await tester.runAsync(() async {
    final element = tester.element(contextFinder.first);
    for (final path in paths) {
      await precacheImage(AssetImage(path), element).timeout(const Duration(seconds: 30));
    }
  });
  for (var frame = 0; frame < 3; frame++) {
    await tester.pump();
  }
}
