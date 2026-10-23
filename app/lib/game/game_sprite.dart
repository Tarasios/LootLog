/// The sprite renderer for the adventure skin.
///
/// [GameSprite] draws one [SpriteRef]. For an asset-keyed ref
/// ([SpriteRef.key] / [GameSprite.fromKey]) it walks the degradation ladder:
///
/// 1. the ref's custom blob (a user's own quest / pet / avatar sprite),
/// 2. the art the [AssetRegistry] maps the key to (via its fallback chain),
/// 3. the key's text/ASCII card ([TextSpriteCard]) — the text-mode tier, a
///    first-class look rather than an error state.
///
/// In the text tier ([AdventureTier.text], from [GameSprite.tier] or an
/// enclosing [GameSpriteScope]) every sprite renders its text card and no
/// image is decoded. Legacy filename refs ([SpriteRef.asset]) keep their grey
/// initials placeholder in the pixel tier.
///
/// Art always draws one frame of a horizontal strip (`<name>_<N>f.png`) with
/// [FilterQuality.none] at an integer scale so pixel art stays crisp. Missing
/// files and undecodable blobs degrade — never an exception, never a red box.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'assets/asset_key.dart';
import 'assets/asset_registry.dart';
import 'assets/text_sprite.dart';
import 'dungeon_state.dart';
import 'skin_prefs.dart';
import 'text_mode/text_widgets.dart' show monoStyle;

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
  final frames = int.parse(match.group(1)!);
  return frames <= 0 ? 1 : frames;
}

/// The source rectangle of [frameIndex] within a strip of [frameCount] uniform
/// frames laid out horizontally across an image of [imageSize].
Rect spriteFrameSrc(Size imageSize, int frameCount, int frameIndex) {
  final count = frameCount <= 0 ? 1 : frameCount;
  final frame = frameIndex % count;
  final frameWidth = imageSize.width / count;
  return Rect.fromLTWH(frameWidth * frame, 0, frameWidth, imageSize.height);
}

/// Resolves a [SpriteRef] to an [ImageProvider], or null when the art is not
/// available (→ fallback). Kept as an interface so goldens can pass a
/// placeholder-only resolver and the app can pass an asset/blob-backed one.
///
/// [GameSprite] only ever hands a resolver [SpriteRef.asset] or
/// [SpriteRef.custom] refs: asset keys are turned into filenames by the
/// [AssetRegistry] first.
abstract class SpriteResolver {
  ImageProvider? resolve(SpriteRef ref);
}

/// A resolver that never resolves anything — every sprite renders as its
/// fallback. Used by goldens so no async image decoding occurs.
class PlaceholderSpriteResolver implements SpriteResolver {
  const PlaceholderSpriteResolver();

  @override
  ImageProvider? resolve(SpriteRef ref) => null;
}

/// The app resolver: named strips load from `assets/game/`; custom blobs load
/// from an in-memory `sha256 -> bytes` map the screen preloads (null when the
/// bytes are not yet available, so the fallback shows meanwhile).
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

/// Supplies the render tier and asset registry to every [GameSprite] below it.
///
/// A screen shown in both tiers (e.g. the guild hall) wraps itself in one of
/// these — usually via `AdventureSpriteScope`, which reads the device's tier
/// and the discovered registry from providers. Without a scope a sprite draws
/// in the pixel tier with [AssetRegistry.bundled]: the dungeon's pixel screens
/// are only ever shown in the pixel tier, so they need no scope.
class GameSpriteScope extends InheritedWidget {
  const GameSpriteScope({
    super.key,
    required this.tier,
    this.registry = AssetRegistry.bundled,
    required super.child,
  });

  final AdventureTier tier;
  final AssetRegistry registry;

  static GameSpriteScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameSpriteScope>();

  @override
  bool updateShouldNotify(GameSpriteScope old) =>
      old.tier != tier || !identical(old.registry, registry);
}

/// Renders one [SpriteRef]. Animated when [animate] and the strip has more than
/// one frame; otherwise shows [frameIndex]. See the library doc for the
/// fallback ladder.
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
    this.tier,
    this.registry,
  }) : assert(scale >= 1, 'scale must be an integer >= 1');

  /// Draws the sprite for [assetKey], e.g.
  /// `GameSprite.fromKey(GameAssetKeys.chest(ChestType.gold, open: true))`.
  /// [label] overrides the key's title; [customSpriteSha256] is a user blob
  /// drawn in preference to the registered art.
  GameSprite.fromKey(
    AssetKey assetKey, {
    super.key,
    String? label,
    String? customSpriteSha256,
    this.resolver = const PlaceholderSpriteResolver(),
    this.scale = 2,
    this.baseSize = kSpriteBaseSize,
    this.frameIndex = 0,
    this.animate = false,
    this.semanticLabel,
    this.tier,
    this.registry,
  })  : assert(scale >= 1, 'scale must be an integer >= 1'),
        sprite = SpriteRef.key(assetKey,
            label: label, customSpriteSha256: customSpriteSha256);

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

  /// Forces a render tier; null reads it from [GameSpriteScope] (pixel when
  /// there is none).
  final AdventureTier? tier;

  /// Overrides the key -> file registry; null reads it from [GameSpriteScope]
  /// ([AssetRegistry.bundled] when there is none).
  final AssetRegistry? registry;

  double get side => baseSize * scale;
  int get frameCount => widgetFrameCount(sprite);

  /// The frame count of [sprite]'s first-choice art (a keyed sprite is looked
  /// up in [registry], default [AssetRegistry.bundled]).
  static int widgetFrameCount(SpriteRef sprite,
      {AssetRegistry registry = AssetRegistry.bundled}) {
    if (sprite.isCustom) return 1;
    final key = sprite.assetKey;
    if (key != null) return spriteFrameCount(registry.fileFor(key) ?? '');
    return spriteFrameCount(sprite.assetName ?? '');
  }

  @override
  State<GameSprite> createState() => _GameSpriteState();
}

/// One image to try: the ref handed to the resolver and its strip frame count.
class _Candidate {
  const _Candidate(this.ref, this.frameCount);
  final SpriteRef ref;
  final int frameCount;
}

class _GameSpriteState extends State<GameSprite>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  AnimationController? _ticker;
  int _frame = 0;

  List<_Candidate> _candidates = const [];
  int _candidateIndex = 0;
  bool _textTier = false;
  AssetRegistry _registry = AssetRegistry.bundled;
  bool _initialized = false;

  /// Whether a candidate image is currently drawn.
  bool get _hasImage => _image != null;

  int get _frameCount => _candidateIndex < _candidates.length
      ? _candidates[_candidateIndex].frameCount
      : 1;

  @override
  void initState() {
    super.initState();
    _frame = widget.frameIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh(force: !_initialized);
    _initialized = true;
  }

  @override
  void didUpdateWidget(GameSprite old) {
    super.didUpdateWidget(old);
    _refresh(
      force: old.sprite != widget.sprite || old.resolver != widget.resolver,
    );
    if (old.animate != widget.animate ||
        old.frameIndex != widget.frameIndex) {
      _frame = widget.frameIndex;
      _maybeStartTicker();
    }
  }

  /// Re-reads tier and registry; rebuilds the candidate list when they (or the
  /// sprite / resolver, when [force]) changed.
  void _refresh({bool force = false}) {
    final scope = GameSpriteScope.maybeOf(context);
    final textTier =
        (widget.tier ?? scope?.tier ?? AdventureTier.pixel) == AdventureTier.text;
    final registry =
        widget.registry ?? scope?.registry ?? AssetRegistry.bundled;
    if (!force && textTier == _textTier && identical(registry, _registry)) {
      return;
    }
    _textTier = textTier;
    _registry = registry;
    _candidates = _buildCandidates();
    _candidateIndex = 0;
    _image = null;
    _resolveCurrent();
    _maybeStartTicker();
  }

  List<_Candidate> _buildCandidates() {
    if (_textTier) return const [];
    final sprite = widget.sprite;
    final key = sprite.assetKey;
    if (key == null) {
      // Legacy refs go to the resolver exactly as given.
      return [_Candidate(sprite, GameSprite.widgetFrameCount(sprite))];
    }
    final sha = sprite.customSpriteSha256;
    final file = _registry.fileFor(key);
    return [
      if (sha != null) _Candidate(SpriteRef.custom(sha, label: sprite.label), 1),
      if (file != null)
        _Candidate(SpriteRef.asset(file, label: sprite.label),
            spriteFrameCount(file)),
    ];
  }

  void _maybeStartTicker() {
    _ticker?.dispose();
    _ticker = null;
    final frames = _frameCount;
    if (!widget.animate || frames <= 1 || _textTier) return;
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 180 * frames),
    );
    controller.addListener(() {
      final next = (controller.value * frames).floor() % frames;
      if (next != _frame && mounted) setState(() => _frame = next);
    });
    unawaited(controller.repeat());
    _ticker = controller;
  }

  /// Starts loading the current candidate, skipping any the resolver cannot
  /// provide; the fallback shows when the list runs out. Callers rebuild
  /// (lifecycle methods are followed by build; the error path uses setState).
  void _resolveCurrent() {
    _detach();
    while (_candidateIndex < _candidates.length) {
      final provider =
          widget.resolver.resolve(_candidates[_candidateIndex].ref);
      if (provider != null) {
        _listen(provider);
        return;
      }
      _candidateIndex++;
    }
  }

  void _listen(ImageProvider provider) {
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() => _image = info.image);
      },
      onError: (_, _) {
        if (!mounted) return;
        setState(() {
          _image = null;
          _candidateIndex++;
        });
        _resolveCurrent();
        _maybeStartTicker();
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
    final sprite = widget.sprite;
    final label = widget.semanticLabel ?? sprite.label;
    final Widget content;
    if (_hasImage && !_textTier) {
      content = CustomPaint(
        size: Size.square(side),
        painter: _SpritePainter(
          image: _image!,
          frameCount: _frameCount,
          frameIndex: _frame,
        ),
      );
    } else if (sprite.assetKey != null) {
      content = TextSpriteCard(
          sprite: textSpriteFor(sprite.assetKey!, label: sprite.label),
          side: side);
    } else if (_textTier) {
      content = TextSpriteCard(sprite: labelTextSprite(sprite.label), side: side);
    } else {
      content = _SpritePlaceholder(label: sprite.label, side: side);
    }
    return Semantics(
      label: label,
      image: true,
      child: SizedBox.square(dimension: side, child: content),
    );
  }
}

/// The text-mode tier of a sprite: the key's ASCII emblem in a bordered text
/// panel, with its title beneath and badge (`T3`, `OPEN`) in the corner once
/// the box is big enough to read them (≥ 48 logical px). Below that only the
/// emblem shows. Public so a screen can place a text sprite directly.
class TextSpriteCard extends StatelessWidget {
  const TextSpriteCard({super.key, required this.sprite, required this.side});

  final TextSprite sprite;
  final double side;

  /// Below this side the title and badge are dropped.
  static const double captionMinSide = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showCaption = side >= captionMinSide;
    final captionSize = (side * 0.13).clamp(8.0, 13.0);
    final art = Text(
      sprite.art.join('\n'),
      textAlign: TextAlign.left,
      softWrap: false,
      style: monoStyle(context, color: scheme.primary, weight: FontWeight.w700)
          .copyWith(height: 1.1),
    );
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(2),
      ),
      padding: EdgeInsets.all(side >= captionMinSide ? 4 : 2),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      top: showCaption && sprite.badge != null
                          ? captionSize + 2
                          : 0),
                  child: Center(child: FittedBox(child: art)),
                ),
              ),
              if (showCaption)
                Text(
                  sprite.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: monoStyle(context,
                          color: scheme.onSurface, weight: FontWeight.w600)
                      .copyWith(fontSize: captionSize, height: 1.1),
                ),
            ],
          ),
          if (showCaption && sprite.badge != null)
            Positioned(
              top: 0,
              right: 0,
              child: Text(
                sprite.badge!,
                maxLines: 1,
                style: monoStyle(context,
                        color: scheme.tertiary, weight: FontWeight.w700)
                    .copyWith(fontSize: captionSize * 0.9, height: 1),
              ),
            ),
        ],
      ),
    );
  }
}

/// The grey fallback for legacy filename refs: a bordered box with the ref's
/// label initials centred and clipped.
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
    final words = label.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    if (words.isEmpty) return '?';
    final letters = words.map((word) => word[0].toUpperCase()).take(2).join();
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
    final sourceRect = spriteFrameSrc(imageSize, frameCount, frameIndex);
    final destinationRect = Offset.zero & size;
    canvas.drawImageRect(image, sourceRect, destinationRect, _paint);
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      !identical(old.image, image) ||
      old.frameIndex != frameIndex ||
      old.frameCount != frameCount;
}
