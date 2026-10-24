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
}
