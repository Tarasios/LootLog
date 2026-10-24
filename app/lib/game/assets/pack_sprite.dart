/// Draws one asset key from a bundled pack sheet (or an artist PNG) as crisp
/// pixel art, or the key's text card in text tier / when there is no art.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game_sprite.dart';
import '../skin_prefs.dart';
import 'art_source.dart';
import 'asset_key.dart';
import 'asset_registry.dart';
import 'sprite_region.dart';
import 'text_sprite.dart';

/// The pack cell size, in source pixels; a text card stands in for one cell.
const int _kTextCardCellSize = 16;

class PackSprite extends StatelessWidget {
  const PackSprite({super.key, required this.assetKey, this.scale = 2, this.label});

  final AssetKey assetKey;

  /// Whole-number magnification of the source pixels.
  final int scale;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scope = GameSpriteScope.maybeOf(context);
    final registry = scope?.registry ?? AssetRegistry.bundled;
    final art = scope?.tier == AdventureTier.text ? null : registry.artFor(assetKey);
    return switch (art) {
      ArtRegion(:final region) => _RegionImage(
          key: const ValueKey('pack-sprite-region'), region: region, scale: scale),
      ArtFile(:final fileName) => Image.asset(
          '${AssetRegistry.assetDir}$fileName',
          key: const ValueKey('pack-sprite-file'),
          filterQuality: FilterQuality.none,
          scale: 1 / scale,
        ),
      null => KeyedSubtree(
          key: const ValueKey('pack-sprite-text'),
          child: TextSpriteCard(
            sprite: textSpriteFor(assetKey, label: label),
            side: (_kTextCardCellSize * scale).toDouble(),
          ),
        ),
    };
  }
}

class _RegionImage extends StatefulWidget {
  const _RegionImage({super.key, required this.region, required this.scale});
  final SpriteRegion region;
  final int scale;

  @override
  State<_RegionImage> createState() => _RegionImageState();
}

class _RegionImageState extends State<_RegionImage> {
  ui.Image? _sheet;
  ImageStream? _stream;
  late final ImageStreamListener _listener =
      ImageStreamListener((info, _) => setState(() => _sheet = info.image));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_RegionImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.region.sheetPath != widget.region.sheetPath) _resolve();
  }

  void _resolve() {
    final stream = AssetImage('${AssetRegistry.assetDir}${widget.region.sheetPath}')
        .resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = widget.region;
    return SizedBox(
      width: (region.width * widget.scale).toDouble(),
      height: (region.height * widget.scale).toDouble(),
      child: _sheet == null ? null : CustomPaint(painter: _RegionPainter(_sheet!, region)),
    );
  }
}

class _RegionPainter extends CustomPainter {
  _RegionPainter(this.sheet, this.region);
  final ui.Image sheet;
  final SpriteRegion region;

  @override
  void paint(Canvas canvas, Size size) {
    final source = Rect.fromLTWH(region.left.toDouble(), region.top.toDouble(),
        region.width.toDouble(), region.height.toDouble());
    canvas.drawImageRect(sheet, source, Offset.zero & size, Paint()..filterQuality = FilterQuality.none);
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) =>
      oldDelegate.sheet != sheet || oldDelegate.region != region;
}
