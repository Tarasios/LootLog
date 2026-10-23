/// Turns asset keys into Flame sprites from the bundled packs, or from an
/// artist PNG named after the key. A key with no art returns null and the
/// scene draws a labelled placeholder (asset ladder tier 2).
library;

import 'dart:ui' show FilterQuality;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show decodeImageFromList;

import '../assets/art_source.dart';
import '../assets/asset_key.dart';
import '../assets/asset_registry.dart';
import '../game_sprite.dart' show spriteFrameCount;

class PackAtlas {
  PackAtlas(this.registry, this.images);

  final AssetRegistry registry;

  /// Flame's image cache, with prefix `assets/game/`.
  final Images images;

  /// Paths whose image loaded and decoded cleanly. Only these are ever read
  /// from [images], so a missing or corrupt file can never reach `fromCache`.
  final Set<String> _loadedPaths = {};

  /// Sprites already built, by key. Art for a key never changes once loaded.
  final Map<AssetKey, Sprite> _sprites = {};

  String? _imagePathFor(AssetKey key) => switch (registry.artFor(key)) {
    ArtRegion(:final region) => region.sheetPath,
    ArtFile(:final fileName) => fileName,
    null => null,
  };

  /// Loads every sheet or file [keys] need. Missing or undecodable files are
  /// skipped, so a broken asset degrades to a placeholder instead of failing
  /// the scene. Bytes are read and decoded here rather than through
  /// `Images.load`, which leaves a bad cache entry and an unhandled async
  /// error behind when a file is missing.
  Future<void> preload(Iterable<AssetKey> keys) async {
    final paths = <String>{
      for (final key in keys)
        if (_imagePathFor(key) case final String path) path,
    };
    for (final path in paths) {
      if (_loadedPaths.contains(path)) continue;
      try {
        if (!images.containsKey(path)) {
          final bytes = await rootBundle.load('${images.prefix}$path');
          final image = await decodeImageFromList(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
          images.add(path, image);
        }
        _loadedPaths.add(path);
      } on Object {
        images.clear(path);
      }
    }
  }

  Sprite? spriteFor(AssetKey key) {
    final cached = _sprites[key];
    if (cached != null) return cached;
    final sprite = _buildSprite(key);
    if (sprite != null) _sprites[key] = sprite;
    return sprite;
  }

  Sprite? _buildSprite(AssetKey key) {
    switch (registry.artFor(key)) {
      case ArtRegion(:final region):
        if (!_loadedPaths.contains(region.sheetPath)) return null;
        return Sprite(
          images.fromCache(region.sheetPath),
          srcPosition: Vector2(region.left.toDouble(), region.top.toDouble()),
          srcSize: Vector2(region.width.toDouble(), region.height.toDouble()),
        )..paint.filterQuality = FilterQuality.none;
      case ArtFile(:final fileName):
        if (!_loadedPaths.contains(fileName)) return null;
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
