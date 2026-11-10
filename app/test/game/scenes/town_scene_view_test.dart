/// The town's first zoom fits the window's real height: a first layout with
/// no height yet (a window still opening) never pins the zoom.
library;

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/town/town_view.dart';
import 'package:lootlog/game/scenes/camera_controls.dart';
import 'package:lootlog/game/scenes/town/town_game.dart';
import 'package:lootlog/game/scenes/town/town_scene_view.dart';

const _adults = [TownAdult(memberId: 'alex', name: 'Alex', inAdventure: true)];

void main() {
  testWidgets('a zero-height first layout still ends at the fitted zoom', (
    tester,
  ) async {
    final view = TownView.from(GameState.initial(), _adults, DateTime.utc(2026, 10, 1));
    final worldHeight = view.layout.rows * kTileSize;
    // Room for the town four times over: a fit above the smallest fit zoom.
    final windowHeight = worldHeight * 4;
    final fitted = CameraControls.fitZoom(viewportHeight: windowHeight, worldHeight: worldHeight);
    expect(fitted, isNot(CameraControls.fitZoom(viewportHeight: 0, worldHeight: worldHeight)));

    tester.view.physicalSize = Size(800, windowHeight);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget host(double height) => Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 800,
              height: height,
              child: TownSceneView(
                view: view,
                registry: AssetRegistry.empty,
                onTarget: (_) {},
                ambientLife: false,
              ),
            ),
          ),
        );

    await tester.pumpWidget(host(0));
    await tester.pump();
    await tester.pumpWidget(host(windowHeight));
    await tester.pump();

    final game = tester.widget<GameWidget<TownGame>>(find.byType(GameWidget<TownGame>)).game!;
    expect(game.cameraControls.zoom, fitted);
  });
}
