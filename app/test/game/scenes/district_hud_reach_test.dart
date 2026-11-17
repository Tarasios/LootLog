/// On a phone, every plot of every district map (with the row its tall art
/// overhangs and the name under it) can be panned clear of the HUD: the
/// camera's clamp lets each edge of the map rise above the bottom cover and
/// drop below the top cover.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';
import 'package:lootlog/game/scenes/camera_controls.dart';
import 'package:lootlog/game/scenes/town/town_game.dart';

void main() {
  // A 390 x 844 phone; the covers are generous versions of what the HUD
  // measures in the goldens (corners above, chips, strip and buttons below).
  const viewportWidth = 390.0, viewportHeight = 844.0, topCover = 200.0, bottomCover = 260.0;
  // Each plot's footprint, the overhang row above it and the name below it.
  const nameDepth = 8.0;

  for (final district in kDistricts) {
    final layout = TownLayout.forDistrict(district.id)!;
    if (layout.columns != 14) continue;
    test('${district.id}: every plot and its name can be brought into the free band', () {
      final worldHeight = layout.rows * kTileSize;
      CameraControls camera() => CameraControls(
            worldWidth: layout.columns * kTileSize,
            worldHeight: worldHeight,
            zoom: CameraControls.fitZoom(viewportHeight: viewportHeight, worldHeight: worldHeight),
            // The narrow districts' forest border (`TownDistrictWiring`).
            margin: 14 * kTileSize,
          )
            ..setViewport(viewportWidth, viewportHeight)
            ..setInsets(top: topCover, bottom: bottomCover);
      ({double top, double bottom}) band(CameraControls camera) {
        final half = viewportHeight / 2 / camera.zoom;
        return (
          top: camera.centerY - half + topCover / camera.zoom,
          bottom: camera.centerY + half - bottomCover / camera.zoom,
        );
      }

      final scrolledUp = camera()..panByScreen(0, 100000);
      final scrolledDown = camera()..panByScreen(0, -100000);
      final highest = band(scrolledUp).top;
      final lowest = band(scrolledDown).bottom;
      final bandHeight = band(camera()).bottom - band(camera()).top;
      for (final origin in layout.plotOrigins) {
        final top = (origin.row - 1) * kTileSize;
        final bottom = (origin.row + TownLayout.footprint) * kTileSize + nameDepth;
        expect(bottom - top, lessThanOrEqualTo(bandHeight), reason: 'plot at $origin is taller than the band');
        expect(highest, lessThanOrEqualTo(top), reason: 'plot at $origin cannot come out from under the top HUD');
        expect(lowest, greaterThanOrEqualTo(bottom), reason: 'plot at $origin cannot rise above the bottom HUD');
      }
    });
  }

  test('the farmland opens with its lowest fields and their names above the HUD', () {
    const layout = TownLayout.farmland;
    final worldHeight = layout.rows * kTileSize;
    final camera = CameraControls(
      worldWidth: layout.columns * kTileSize,
      worldHeight: worldHeight,
      zoom: CameraControls.fitZoom(viewportHeight: viewportHeight, worldHeight: worldHeight),
      margin: 14 * kTileSize,
      focusY: TownGame.plotFocusY(layout),
      focusBottom: TownGame.plotFocusBottom(layout),
    )
      ..setViewport(viewportWidth, viewportHeight)
      ..setInsets(top: topCover, bottom: bottomCover);
    final bandBottom = camera.centerY + viewportHeight / 2 / camera.zoom - bottomCover / camera.zoom;
    final lowest = layout.plotOrigins.map((origin) => origin.row).reduce((a, b) => a > b ? a : b);
    expect(bandBottom, greaterThanOrEqualTo((lowest + TownLayout.footprint) * kTileSize + nameDepth));
  });
}
