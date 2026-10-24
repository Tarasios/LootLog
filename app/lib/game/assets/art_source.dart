/// Where an asset key's art comes from: an artist's PNG named after the key,
/// or a region of a bundled pack sheet. Pure Dart, zero Flutter imports.
library;

import 'sprite_region.dart';

sealed class ArtSource {
  const ArtSource();
}

/// A PNG under `assets/game/` (a strip when its name ends `_<N>f`).
class ArtFile extends ArtSource {
  const ArtFile(this.fileName);
  final String fileName;
}

/// A rectangle of a pack sheet.
class ArtRegion extends ArtSource {
  const ArtRegion(this.region);
  final SpriteRegion region;
}
