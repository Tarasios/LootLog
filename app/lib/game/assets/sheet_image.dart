/// Loads one bundled game image (a pack sheet or an artist PNG) as a decoded
/// [ui.Image] and hands it to a builder — null until it has decoded, so the
/// caller draws its own placeholder meanwhile.
///
/// Shared by [PackSprite] and the Adventure kit's pixel frames so both follow
/// the same image-stream pattern: resolve against the local image
/// configuration, listen to one stream at a time, re-resolve only when the
/// path changes (dropping the old image at once), and dispose every frame it
/// is handed once it is replaced.
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
  /// The latest frame. This state owns it (an image stream hands each
  /// listener its own handle) and disposes it when it is replaced or dropped.
  ImageInfo? _imageInfo;
  ImageStream? _stream;
  ImageStreamListener? _listener;

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
      _stopListening();
      _replaceImage(null);
      return;
    }
    final stream = AssetImage(assetPath).resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stopListening();
    // A new sheet: never keep drawing the old one while it loads (or fails).
    _replaceImage(null);
    final listener = ImageStreamListener(_onImage, onError: widget.onError);
    _listener = listener;
    _stream = stream..addListener(listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() => _replaceImage(info));
  }

  /// Swaps in [info], disposing the old frame after this frame is drawn (the
  /// frame being built may still paint it).
  void _replaceImage(ImageInfo? info) {
    final previous = _imageInfo;
    _imageInfo = info;
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  void _stopListening() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopListening();
    _imageInfo?.dispose();
    _imageInfo = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _imageInfo?.image);
}
