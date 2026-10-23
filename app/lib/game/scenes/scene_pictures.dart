/// A scene's own handles on the goal pictures it draws. The decoded images
/// are shared (see `goalPictureImagesProvider`) and disposed when the set of
/// pictures changes, so each scene draws from clones, which stay valid until
/// the scene lets them go: after it has switched to newer pictures, or when
/// it is disposed.
library;

import 'dart:ui' as ui;

class ScenePictures {
  ScenePictures(Map<String, ui.Image> source)
      : images = Map.unmodifiable({for (final entry in source.entries) entry.key: entry.value.clone()});

  /// The clones, by the same keys as the source.
  final Map<String, ui.Image> images;

  void dispose() {
    for (final image in images.values) {
      image.dispose();
    }
  }
}
