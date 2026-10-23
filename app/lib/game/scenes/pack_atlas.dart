/// Turns asset keys into Flame sprites from the bundled packs, or from an
/// artist PNG named after the key. A key with no art returns null and the
/// scene draws a labelled placeholder (asset ladder tier 2).
library;

import 'dart:ui' show FilterQuality;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../assets/art_source.dart';
import '../assets/asset_key.dart';
import '../assets/asset_registry.dart';
import '../game_sprite.dart' show spriteFrameCount;

class PackAtlas {
  PackAtlas(this.registry, this.images);

  final AssetRegistry registry;

  /// Flame's image cache, with prefix `assets/game/`.
  final Images images;

  String? _imagePathFor(AssetKey key) => switch (registry.artFor(key)) {
    ArtRegion(:final region) => region.sheetPath,
    ArtFile(:final fileName) => fileName,
    null => null,
  };

  /// Loads every sheet or file [keys] need. Missing files are skipped, so a
  /// broken asset degrades to a placeholder instead of failing the scene.
  Future<void> preload(Iterable<AssetKey> keys) async {
    final paths = <String>{
      for (final key in keys)
        if (_imagePathFor(key) case final String path) path,
    };
    for (final path in paths) {
      if (images.containsKey(path)) continue;
      try {
        await images.load(path);
      } on Object {
        continue;
      }
    }
  }

  Sprite? spriteFor(AssetKey key) {
    switch (registry.artFor(key)) {
      case ArtRegion(:final region):
        if (!images.containsKey(region.sheetPath)) return null;
        return Sprite(
          images.fromCache(region.sheetPath),
          srcPosition: Vector2(region.left.toDouble(), region.top.toDouble()),
          srcSize: Vector2(region.width.toDouble(), region.height.toDouble()),
        )..paint.filterQuality = FilterQuality.none;
      case ArtFile(:final fileName):
        if (!images.containsKey(fileName)) return null;
        final image = images.fromCache(fileName);
        final frameWidth = image.width / spriteFrameCount(fileName);
        return Sprite(
          image,
          srcSize: Vector2(frameWidth, image.height.toDouble()),
        )..paint.filterQuality = FilterQuality.none;
      case null:
        return null;
    }
  }
}
