/// Loads one bundled game image (a pack sheet or an artist PNG) as a decoded
/// [ui.Image] and hands it to a builder — null until it has decoded, so the
/// caller draws its own placeholder meanwhile.
///
/// Shared by [PackSprite] and the Adventure kit's pixel frames so both follow
/// the same image-stream pattern: resolve against the local image
/// configuration, keep one listener, and re-resolve only when the path changes.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Builds with the decoded image at [assetPath] (a full asset path, e.g.
/// `assets/game/packs/ui_pixel_adventure/tilemap_packed.png`). A null path
/// loads nothing and builds with null.
class SheetImageBuilder extends StatefulWidget {
  const SheetImageBuilder({
    super.key,
    required this.assetPath,
    required this.builder,
    this.onError,
  });

  final String? assetPath;
  final Widget Function(BuildContext context, ui.Image? image) builder;

  /// Called when the image fails to load. Null leaves the error to Flutter's
  /// default reporting; a handler swallows it (the builder keeps seeing null).
  final ImageErrorListener? onError;

  @override
  State<SheetImageBuilder> createState() => _SheetImageBuilderState();
}

class _SheetImageBuilderState extends State<SheetImageBuilder> {
  ui.Image? _image;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) => setState(() => _image = info.image),
    onError: widget.onError,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(SheetImageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) _resolve();
  }

  void _resolve() {
    final assetPath = widget.assetPath;
    if (assetPath == null) {
      _stream?.removeListener(_listener);
      _stream = null;
      _image = null;
      return;
    }
    final stream = AssetImage(assetPath).resolve(createLocalImageConfiguration(context));
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
  Widget build(BuildContext context) => widget.builder(context, _image);
}
