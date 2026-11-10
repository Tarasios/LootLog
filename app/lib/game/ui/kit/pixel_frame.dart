/// The Adventure kit's pixel frames: a sliced pack image (a 9-slice panel or
/// a 3-slice banner) drawn behind a padded child, crisp at an integer scale.
///
/// Every frame walks the asset ladder: the key's art (an artist PNG or a pack
/// region) once it has decoded, otherwise — in the text tier, with no art, or
/// while the image is still loading — a drawn [DecoratedBox] in the fallback
/// colours. The child sits under the same padding either way, so nothing jumps
/// when the art arrives, and the widget tree keeps its shape, so the child's
/// state survives the swap.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../assets/art_source.dart';
import '../../assets/asset_key.dart';
import '../../assets/asset_registry.dart';
import '../../assets/sheet_image.dart';
import '../../game_sprite.dart';
import '../../skin_prefs.dart';

/// The drawn stand-in for a frame: [fill] with a 2 px [border] and
/// square-ish (radius 2) corners.
BoxDecoration kitFallbackDecoration({Color? fill, Color? border}) => BoxDecoration(
      color: fill,
      border: border == null ? null : Border.all(color: border, width: 2),
      borderRadius: BorderRadius.circular(2),
    );

/// A uniform 9-slice panel: [border] source pixels on each side stay whole
/// (magnified by [scale]); the edges and centre stretch, nearest-neighbour.
class PixelFrame extends StatelessWidget {
  const PixelFrame({
    super.key,
    required this.assetKey,
    required this.child,
    this.scale = 2,
    this.border = 8,
    this.fallbackFill,
    this.fallbackBorder,
    this.padding = const EdgeInsets.all(12),
  });

  final AssetKey assetKey;
  final Widget child;

  /// Whole-number magnification of the source pixels.
  final int scale;

  /// The 9-slice inset on the source image, in source pixels.
  final int border;
  final Color? fallbackFill;
  final Color? fallbackBorder;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => PixelSliceBox(
        assetKey: assetKey,
        sourceInsets: EdgeInsets.all(border.toDouble()),
        scale: scale,
        fallback: kitFallbackDecoration(fill: fallbackFill, border: fallbackBorder),
        padding: padding,
        child: child,
      );
}

/// The general sliced frame behind [PixelFrame] and the kit's banners: the
/// source image is cut at [sourceInsets] (source pixels; a zero inset means
/// that axis stretches whole, e.g. a horizontal-only 3-slice banner).
class PixelSliceBox extends StatelessWidget {
  const PixelSliceBox({
    super.key,
    required this.assetKey,
    required this.sourceInsets,
    required this.child,
    this.scale = 2,
    this.fallback = const BoxDecoration(),
    this.padding = EdgeInsets.zero,
  }) : assert(scale >= 1, 'scale must be an integer >= 1');

  final AssetKey assetKey;
  final EdgeInsets sourceInsets;
  final Widget child;
  final int scale;
  final BoxDecoration fallback;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scope = GameSpriteScope.maybeOf(context);
    final registry = scope?.registry ?? AssetRegistry.bundled;
    final art = scope?.tier == AdventureTier.text ? null : registry.artFor(assetKey);
    return SheetImageBuilder(
      assetPath: switch (art) {
        ArtRegion(:final region) => '${AssetRegistry.assetDir}${region.sheetPath}',
        ArtFile(:final fileName) => '${AssetRegistry.assetDir}$fileName',
        null => null,
      },
      // A missing or undecodable image keeps the drawn fallback.
      onError: (error, stackTrace) {},
      builder: (context, image) {
        final painter = (image == null || art == null)
            ? null
            : NineSlicePainter(
                image: image,
                source: _sourceRect(art, image),
                insets: sourceInsets,
                scale: scale,
              );
        return CustomPaint(
          painter: painter,
          child: DecoratedBox(
            decoration: painter == null ? fallback : const BoxDecoration(),
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );
  }

  /// The rectangle of [image] holding the frame: the pack region, or the
  /// first frame of an artist's strip.
  static Rect _sourceRect(ArtSource art, ui.Image image) => switch (art) {
        ArtRegion(:final region) => Rect.fromLTWH(region.left.toDouble(),
            region.top.toDouble(), region.width.toDouble(), region.height.toDouble()),
        ArtFile(:final fileName) => spriteFrameSrc(
            Size(image.width.toDouble(), image.height.toDouble()), spriteFrameCount(fileName), 0),
      };
}

/// Paints [source] of [image] sliced at [insets] (source pixels): the corner
/// and edge bands keep their size magnified by [scale], the middle stretches.
/// Bands shrink proportionally when the box is smaller than both borders.
class NineSlicePainter extends CustomPainter {
  NineSlicePainter({
    required this.image,
    required this.source,
    required this.insets,
    required this.scale,
  });

  final ui.Image image;
  final Rect source;
  final EdgeInsets insets;
  final int scale;

  @override
  void paint(Canvas canvas, Size size) {
    final sourceXs = [source.left, source.left + insets.left, source.right - insets.right, source.right];
    final sourceYs = [source.top, source.top + insets.top, source.bottom - insets.bottom, source.bottom];
    final destXs = _destinationStops(insets.left, insets.right, size.width);
    final destYs = _destinationStops(insets.top, insets.bottom, size.height);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 3; column++) {
        final sourceRect = Rect.fromLTRB(
            sourceXs[column], sourceYs[row], sourceXs[column + 1], sourceYs[row + 1]);
        final destRect =
            Rect.fromLTRB(destXs[column], destYs[row], destXs[column + 1], destYs[row + 1]);
        if (sourceRect.isEmpty || destRect.isEmpty) continue;
        canvas.drawImageRect(image, sourceRect, destRect, paint);
      }
    }
  }

  /// The four destination stops along one axis of [extent]: the start, the
  /// end of the leading band, the start of the trailing band, the end.
  List<double> _destinationStops(double leadingSource, double trailingSource, double extent) {
    var leading = leadingSource * scale;
    var trailing = trailingSource * scale;
    final bands = leading + trailing;
    if (bands > extent && bands > 0) {
      leading = (leading * extent / bands).floorToDouble();
      trailing = extent - leading;
    }
    return [0, leading, extent - trailing, extent];
  }

  @override
  bool shouldRepaint(NineSlicePainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.source != source ||
      oldDelegate.insets != insets ||
      oldDelegate.scale != scale;
}
