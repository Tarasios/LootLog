/// The pixelated sprite renderer for the adventure skin.
///
/// [GameSprite] draws either one frame of a named sprite-sheet strip
/// (`assets/game/<name>_<N>f.png`) or a single-frame custom blob sprite, always
/// with [FilterQuality.none] at an integer scale so pixel art stays crisp.
/// Missing files and undecodable blobs degrade to a labelled grey placeholder —
/// never an exception, never a red error box.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'game_state.dart';

/// The base authoring size of one dungeon sprite frame, in logical pixels (see
/// `docs/art-assets.md`). A sprite occupies `baseSize * scale` on screen; this
/// is the default [baseSize] for [GameSprite].
const double kSpriteBaseSize = 32;

/// The base authoring size of one party-member portrait, in logical pixels.
/// Portraits are the only other size in the system (see `docs/art-assets.md`);
/// pass this as [GameSprite.baseSize] for a roster face.
const double kPortraitBaseSize = 48;

/// Parses the frame count from a strip filename's `_<N>f` suffix. A name with
/// no valid suffix (e.g. a single-frame `gold_pouch_1f.png` reads 1; anything
/// unrecognised reads 1) is treated as a single frame.
int spriteFrameCount(String assetName) {
  final dot = assetName.lastIndexOf('.');
  final base = dot == -1 ? assetName : assetName.substring(0, dot);
  final match = RegExp(r'_(\d+)f$').firstMatch(base);
  if (match == null) return 1;
  final n = int.parse(match.group(1)!);
  return n <= 0 ? 1 : n;
}

/// The source rectangle of [frameIndex] within a strip of [frameCount] uniform
/// frames laid out horizontally across an image of [imageSize].
Rect spriteFrameSrc(Size imageSize, int frameCount, int frameIndex) {
  final count = frameCount <= 0 ? 1 : frameCount;
  final idx = frameIndex % count;
  final frameWidth = imageSize.width / count;
  return Rect.fromLTWH(frameWidth * idx, 0, frameWidth, imageSize.height);
}

/// Resolves a [SpriteRef] to an [ImageProvider], or null when the art is not
/// available (→ placeholder). Kept as an interface so goldens can pass a
/// placeholder-only resolver and the app can pass an asset/blob-backed one.
abstract class SpriteResolver {
  ImageProvider? resolve(SpriteRef ref);
}

/// A resolver that never resolves anything — every sprite renders as its
/// labelled placeholder. Used by goldens so no async image decoding occurs.
class PlaceholderSpriteResolver implements SpriteResolver {
  const PlaceholderSpriteResolver();

  @override
  ImageProvider? resolve(SpriteRef ref) => null;
}

/// The app resolver: named strips load from `assets/game/`; custom blobs load
/// from an in-memory `sha256 -> bytes` map the screen preloads (null when the
/// bytes are not yet available, so the placeholder shows meanwhile).
class AssetSpriteResolver implements SpriteResolver {
  const AssetSpriteResolver({this.customBlobs = const {}});

  final Map<String, Uint8List> customBlobs;

  @override
  ImageProvider? resolve(SpriteRef ref) {
    if (ref.isCustom) {
      final bytes = customBlobs[ref.customSpriteSha256];
      return bytes == null ? null : MemoryImage(bytes);
    }
    final name = ref.assetName;
    if (name == null) return null;
    return AssetImage('assets/game/$name');
  }
}

/// Renders one [SpriteRef]. Animated when [animate] and the strip has more than
/// one frame; otherwise shows [frameIndex]. Falls back to a grey placeholder
/// labelled with the ref's [SpriteRef.label] whenever the image is unavailable.
class GameSprite extends StatefulWidget {
  const GameSprite({
    super.key,
    required this.sprite,
    this.resolver = const PlaceholderSpriteResolver(),
    this.scale = 2,
    this.baseSize = kSpriteBaseSize,
    this.frameIndex = 0,
    this.animate = false,
    this.semanticLabel,
  }) : assert(scale >= 1, 'scale must be an integer >= 1');

  final SpriteRef sprite;
  final SpriteResolver resolver;

  /// Integer on-screen magnification (2×, 3×, …). Fractional values are
  /// disallowed so pixels never blur.
  final int scale;

  /// The sprite's authoring size in logical pixels — [kSpriteBaseSize] for a
  /// dungeon sprite, [kPortraitBaseSize] for a roster portrait. Only these two
  /// sizes exist (see `docs/art-assets.md`).
  final double baseSize;
  final int frameIndex;

  /// Cycle through the strip's frames on a fixed cadence.
  final bool animate;
  final String? semanticLabel;

  double get side => baseSize * scale;
  int get frameCount =>
      widgetFrameCount(sprite);

  static int widgetFrameCount(SpriteRef sprite) =>
      sprite.isCustom ? 1 : spriteFrameCount(sprite.assetName ?? '');

  @override
  State<GameSprite> createState() => _GameSpriteState();
}

class _GameSpriteState extends State<GameSprite>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _failed = false;
  AnimationController? _ticker;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _frame = widget.frameIndex;
    _resolveImage();
    _maybeStartTicker();
  }

  @override
  void didUpdateWidget(GameSprite old) {
    super.didUpdateWidget(old);
    if (old.sprite != widget.sprite || old.resolver != widget.resolver) {
      _failed = false;
      _image = null;
      _resolveImage();
    }
    if (old.animate != widget.animate ||
        old.frameIndex != widget.frameIndex) {
      _frame = widget.frameIndex;
      _maybeStartTicker();
    }
  }

  void _maybeStartTicker() {
    _ticker?.dispose();
    _ticker = null;
    if (!widget.animate || widget.frameCount <= 1) return;
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 180 * widget.frameCount),
    );
    controller.addListener(() {
      final next = (controller.value * widget.frameCount).floor() %
          widget.frameCount;
      if (next != _frame && mounted) setState(() => _frame = next);
    });
    unawaited(controller.repeat());
    _ticker = controller;
  }

  void _resolveImage() {
    _detach();
    final provider = widget.resolver.resolve(widget.sprite);
    if (provider == null) {
      setState(() => _failed = true);
      return;
    }
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() {
          _image = info.image;
          _failed = false;
        });
      },
      onError: (_, _) {
        if (!mounted) return;
        setState(() => _failed = true);
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.side;
    final label = widget.semanticLabel ?? widget.sprite.label;
    final Widget content = (_image == null || _failed)
        ? _SpritePlaceholder(label: widget.sprite.label, side: side)
        : CustomPaint(
            size: Size.square(side),
            painter: _SpritePainter(
              image: _image!,
              frameCount: widget.frameCount,
              frameIndex: _frame,
            ),
          );
    return Semantics(
      label: label,
      image: true,
      child: SizedBox.square(dimension: side, child: content),
    );
  }
}

/// The grey fallback: a bordered box with the ref's label centred and clipped.
class _SpritePlaceholder extends StatelessWidget {
  const _SpritePlaceholder({required this.label, required this.side});

  final String label;
  final double side;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(2),
      child: Text(
        _initials(label),
        maxLines: 1,
        overflow: TextOverflow.clip,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: (side * 0.34).clamp(8, 20),
          height: 1,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Up to two initials from the label, so small placeholders stay legible.
  static String _initials(String label) {
    final words = label.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    final letters = words.map((w) => w[0].toUpperCase()).take(2).join();
    return letters.isEmpty ? '?' : letters;
  }
}

/// Paints a single frame of a strip at integer scale with no filtering.
class _SpritePainter extends CustomPainter {
  _SpritePainter({
    required this.image,
    required this.frameCount,
    required this.frameIndex,
  });

  final ui.Image image;
  final int frameCount;
  final int frameIndex;

  static final Paint _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize =
        Size(image.width.toDouble(), image.height.toDouble());
    final src = spriteFrameSrc(imageSize, frameCount, frameIndex);
    final dst = Offset.zero & size;
    canvas.drawImageRect(image, src, dst, _paint);
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      !identical(old.image, image) ||
      old.frameIndex != frameIndex ||
      old.frameCount != frameCount;
}
