/// Pan and zoom for a top-down scene, in world pixels (16 per tile). The zoom
/// is always a whole number so pixel art stays crisp.
///
/// Once the viewport is known ([setViewport]) panning stops where the
/// scenery [margin] around the world ends, so the view never shows past it;
/// before that the centre simply stays inside the world.
library;

import '../domain/town/town_layout.dart';

const double kTileSize = 16;

class CameraControls {
  CameraControls({
    required this.worldWidth,
    required this.worldHeight,
    int zoom = 3,
    this.margin = 0,
  }) : _zoom = zoom.clamp(minZoom, maxZoom),
       _centerX = worldWidth / 2,
       _centerY = worldHeight / 2;

  static const int minZoom = 1;
  static const int maxZoom = 6;

  /// The smallest and largest zoom [fitZoom] picks.
  static const int minFitZoom = 2;
  static const int maxFitZoom = 5;

  /// The largest whole zoom at which [worldHeight] world pixels fit in
  /// [viewportHeight] screen pixels, kept between [minFitZoom] and
  /// [maxFitZoom].
  static int fitZoom({
    required double viewportHeight,
    required double worldHeight,
  }) {
    if (worldHeight <= 0) return minFitZoom;
    return (viewportHeight / worldHeight).floor().clamp(minFitZoom, maxFitZoom);
  }

  final double worldWidth;
  final double worldHeight;

  /// World pixels of scenery drawn beyond every edge of the world.
  final double margin;

  int _zoom;
  double _centerX;
  double _centerY;
  double? _viewportWidth;
  double? _viewportHeight;

  int get zoom => _zoom;
  double get centerX => _centerX;
  double get centerY => _centerY;

  void zoomTo(int zoom) {
    _zoom = zoom.clamp(minZoom, maxZoom);
    _clampCentre();
  }

  void zoomStep(int steps) => zoomTo(_zoom + steps);

  /// Records the viewport's size in screen pixels and keeps the view inside
  /// the world and its margin.
  void setViewport(double width, double height) {
    _viewportWidth = width;
    _viewportHeight = height;
    _clampCentre();
  }

  /// A drag of ([deltaX], [deltaY]) screen pixels moves the view with the
  /// finger, so the camera centre moves the opposite way.
  void panByScreen(double deltaX, double deltaY) {
    _centerX -= deltaX / _zoom;
    _centerY -= deltaY / _zoom;
    _clampCentre();
  }

  void _clampCentre() {
    _centerX = _clampAxis(_centerX, worldWidth, _viewportWidth);
    _centerY = _clampAxis(_centerY, worldHeight, _viewportHeight);
  }

  /// Keeps one axis of the centre in range: inside the world while the
  /// viewport is unknown; otherwise so the view's edges stay within the
  /// margin, centring the world when the view is wider than world and margin.
  double _clampAxis(double centre, double worldExtent, double? viewportExtent) {
    if (viewportExtent == null) return centre.clamp(0, worldExtent);
    final halfView = viewportExtent / 2 / _zoom;
    final lowest = -margin + halfView;
    final highest = worldExtent + margin - halfView;
    if (lowest > highest) return worldExtent / 2;
    return centre.clamp(lowest, highest);
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

  /// Where the world point ([worldX], [worldY]) lands on a viewport of the
  /// given size, in screen pixels: the inverse of [cellAt].
  ({double x, double y}) worldToScreen(
    double worldX,
    double worldY,
    double viewportWidth,
    double viewportHeight,
  ) => (
    x: (worldX - _centerX) * _zoom + viewportWidth / 2,
    y: (worldY - _centerY) * _zoom + viewportHeight / 2,
  );
}
