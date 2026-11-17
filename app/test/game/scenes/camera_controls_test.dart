import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';
import 'package:lootlog/game/scenes/camera_controls.dart';

CameraControls townCamera() =>
    CameraControls(worldWidth: 28 * kTileSize, worldHeight: 20 * kTileSize);

void main() {
  test('starts centred at zoom 3', () {
    final camera = townCamera();
    expect(camera.zoom, 3);
    expect(camera.centerX, 14 * kTileSize);
    expect(camera.centerY, 10 * kTileSize);
  });

  test('zoom stays a whole number between 1 and 6', () {
    final camera = townCamera()..zoomStep(10);
    expect(camera.zoom, 6);
    camera.zoomStep(-10);
    expect(camera.zoom, 1);
    camera.zoomTo(4);
    expect(camera.zoom, 4);
  });

  test('a drag moves the view with the finger and stays inside the world', () {
    final camera = townCamera()..panByScreen(-30, 0);
    expect(camera.centerX, 14 * kTileSize + 10);
    camera.panByScreen(100000, 100000);
    expect(camera.centerX, 0);
    expect(camera.centerY, 0);
  });

  test('the screen centre maps to the camera centre cell', () {
    expect(townCamera().cellAt(200, 150, 400, 300), const TownCell(14, 10));
  });

  test('one tile right of centre at zoom 3 is 48 screen pixels', () {
    expect(
      townCamera().cellAt(200 + 48, 150, 400, 300),
      const TownCell(15, 10),
    );
  });

  group('fitting the town to the window', () {
    test('the largest whole zoom where the world height fits, 2 to 5', () {
      int fit(double height) =>
          CameraControls.fitZoom(viewportHeight: height, worldHeight: 20 * kTileSize);
      expect(fit(900), 2);
      expect(fit(1000), 3);
      expect(fit(1700), 5);
      expect(fit(4000), 5, reason: 'never past 5');
      expect(fit(400), 2, reason: 'never below 2');
    });
  });

  group('a known viewport and a forest margin', () {
    CameraControls framedCamera() => CameraControls(
      worldWidth: 28 * kTileSize,
      worldHeight: 20 * kTileSize,
      zoom: 2,
      margin: 6 * kTileSize,
    )..setViewport(400, 300);

    test('panning stops where the forest margin ends', () {
      final camera = framedCamera()..panByScreen(100000, 100000);
      // Half the viewport (200 x 150 screen px) is 100 x 75 world px.
      expect(camera.centerX, -6 * kTileSize + 100);
      expect(camera.centerY, -6 * kTileSize + 75);
      camera.panByScreen(-100000, -100000);
      expect(camera.centerX, 34 * kTileSize - 100);
      expect(camera.centerY, 26 * kTileSize - 75);
    });

    test('a viewport wider than world and margin keeps the world centred', () {
      final camera = framedCamera()
        ..setViewport(4000, 3000)
        ..panByScreen(500, 500);
      expect(camera.centerX, 14 * kTileSize);
      expect(camera.centerY, 10 * kTileSize);
    });

    test('zooming out re-clamps the centre', () {
      final camera = framedCamera()..panByScreen(100000, 0);
      camera.zoomTo(1);
      expect(camera.centerX, -6 * kTileSize + 200);
    });
  });

  group('world to screen', () {
    test('the camera centre is the viewport centre', () {
      final point = townCamera().worldToScreen(14 * kTileSize, 10 * kTileSize, 400, 300);
      expect(point.x, 200);
      expect(point.y, 150);
    });

    test('one tile right of centre at zoom 3 is 48 screen pixels right', () {
      final point = townCamera().worldToScreen(15 * kTileSize, 10 * kTileSize, 400, 300);
      expect(point.x, 248);
    });

    test('inverts cellAt', () {
      final camera = townCamera()..panByScreen(-37, 22);
      final point = camera.worldToScreen(5 * kTileSize + 1, 7 * kTileSize + 1, 400, 300);
      expect(camera.cellAt(point.x, point.y, 400, 300), const TownCell(5, 7));
    });
  });

  group('a phone HUD over the scene', () {
    // A 390 x 844 phone at zoom 2: 640 screen px of map, chips over the top
    // 150 px and the log stack over the bottom 260 px.
    CameraControls phoneCamera() => CameraControls(
      worldWidth: 28 * kTileSize,
      worldHeight: 20 * kTileSize,
      zoom: 2,
      margin: 6 * kTileSize,
    )
      ..setViewport(390, 844)
      ..setInsets(top: 150, bottom: 260);

    test('the map sits centred in the band between the HUD rows', () {
      final camera = phoneCamera();
      final mapCentre = camera.worldToScreen(14 * kTileSize, 10 * kTileSize, 390, 844);
      expect(mapCentre.y, closeTo((150 + (844 - 260)) / 2, 1));
    });

    test('the camera pans far enough to lift the bottom row clear of the HUD', () {
      final camera = phoneCamera()..panByScreen(0, -100000);
      final bottomEdge = camera.worldToScreen(0, 20 * kTileSize, 390, 844);
      expect(bottomEdge.y, lessThanOrEqualTo(844 - 260));
      camera.panByScreen(0, 100000);
      final topEdge = camera.worldToScreen(0, 0, 390, 844);
      expect(topEdge.y, greaterThanOrEqualTo(150));
    });

    test('a pan the player made survives new insets', () {
      final camera = phoneCamera()..panByScreen(0, -40);
      final centre = camera.centerY;
      camera.setInsets(top: 150, bottom: 300);
      expect(camera.centerY, centre);
    });
  });
}
