/// Pan and zoom for a top-down scene, in world pixels (16 per tile). The zoom
/// is always a whole number so pixel art stays crisp.
library;

import '../domain/town/town_layout.dart';

const double kTileSize = 16;

class CameraControls {
  CameraControls({
    required this.worldWidth,
    required this.worldHeight,
    int zoom = 3,
  }) : _zoom = zoom.clamp(minZoom, maxZoom),
       _centerX = worldWidth / 2,
       _centerY = worldHeight / 2;

  static const int minZoom = 1;
  static const int maxZoom = 6;

  final double worldWidth;
  final double worldHeight;
  int _zoom;
  double _centerX;
  double _centerY;

  int get zoom => _zoom;
  double get centerX => _centerX;
  double get centerY => _centerY;

  void zoomTo(int zoom) => _zoom = zoom.clamp(minZoom, maxZoom);

  void zoomStep(int steps) => zoomTo(_zoom + steps);

  /// A drag of ([deltaX], [deltaY]) screen pixels moves the view with the
  /// finger, so the camera centre moves the opposite way.
  void panByScreen(double deltaX, double deltaY) {
    _centerX = (_centerX - deltaX / _zoom).clamp(0, worldWidth);
    _centerY = (_centerY - deltaY / _zoom).clamp(0, worldHeight);
  }

  TownCell cellAt(
    double localX,
    double localY,
    double viewportWidth,
    double viewportHeight,
  ) {
    final worldX = _centerX + (localX - viewportWidth / 2) / _zoom;
    final worldY = _centerY + (localY - viewportHeight / 2) / _zoom;
    return TownCell((worldX / kTileSize).floor(), (worldY / kTileSize).floor());
  }
}
