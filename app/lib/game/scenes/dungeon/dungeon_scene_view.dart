/// Hosts a [DungeonGame] at the largest whole zoom that fits the whole
/// dungeon, so the pixel art stays crisp on every screen.
library;

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'dungeon_game.dart';

class DungeonSceneView extends StatelessWidget {
  const DungeonSceneView({super.key, required this.game});

  final DungeonGame game;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          game.cameraControls.zoomTo(
            DungeonGame.fitZoom(Size(constraints.maxWidth, constraints.maxHeight), game.rows),
          );
          return ColoredBox(color: const Color(0xFF140C1C), child: GameWidget(game: game));
        },
      );
}
