import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';
import 'package:lootlog/game/domain/town/town_view.dart';
import 'package:lootlog/game/scenes/camera_controls.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/scenes/town/town_components.dart';
import 'package:lootlog/game/scenes/town/town_game.dart';

const _adults = [
  TownAdult(memberId: 'alex', name: 'Alex', inAdventure: true),
  TownAdult(memberId: 'sam', name: 'Sam', inAdventure: false),
];

final _now = DateTime.utc(2026, 10, 1);

TownView sampleView() => TownView.from(GameState.initial(), _adults, _now);

TownView viewWithLumberyard() {
  final game = projectGameState([
    BuildingStarted(
      eventId: '01900000-0000-7000-8000-000000000001',
      deviceId: 'device',
      actorId: 'alex',
      occurredAt: _now,
      createdAt: _now,
      plotIndex: 0,
      buildingType: BuildingType.lumberyard,
      tier: 1,
      cost: Loot.none,
      completesAt: _now,
    ),
  ]);
  return TownView.from(game, _adults, _now);
}

TownGame buildGame({
  TownView? view,
  bool ambientLife = false,
  List<TownsfolkEntry> townsfolk = const [],
}) => TownGame(
  atlas: PackAtlas(AssetRegistry.empty, Images(prefix: 'assets/game/')),
  view: view ?? sampleView(),
  ambientLife: ambientLife,
  townsfolk: townsfolk,
);

Iterable<String> plotLabels(PlotComponent plot) =>
    plot.children.whereType<TextComponent>().map((label) => label.text);

void main() {
  testWithGame<TownGame>(
    'draws every plot and house with no art at all',
    buildGame,
    (game) async {
      await game.ready();
      expect(game.world.children.whereType<GroundLayer>(), hasLength(1));
      expect(game.world.children.whereType<PlotComponent>(), hasLength(11));
      expect(game.world.children.whereType<HouseComponent>(), hasLength(2));
    },
  );

  testWithGame<TownGame>(
    'updateView replaces the plots instead of adding more',
    buildGame,
    (game) async {
      await game.ready();
      await game.updateView(sampleView());
      await game.ready();
      expect(game.world.children.whereType<PlotComponent>(), hasLength(11));
    },
  );

  testWithGame<TownGame>('the camera follows the controls', buildGame, (
    game,
  ) async {
    await game.ready();
    game.cameraControls.zoomTo(5);
    game.update(0);
    expect(game.camera.viewfinder.zoom, 5);
  });

  testWithGame<TownGame>(
    'locked and empty plots are labelled under the plot',
    buildGame,
    (game) async {
      await game.ready();
      final plots = game.world.children.whereType<PlotComponent>().toList();
      expect(plotLabels(plots.first), ['Build']);
      expect(plotLabels(plots.last), ['Locked']);
    },
  );

  testWithGame<TownGame>(
    'a building is always named under the building, art or not',
    () => buildGame(view: viewWithLumberyard()),
    (game) async {
      await game.ready();
      final firstPlot = game.world.children.whereType<PlotComponent>().first;
      final label = firstPlot.children.whereType<TextComponent>().singleWhere(
        (text) => text.text == 'Lumberyard',
      );
      expect(label.anchor, Anchor.topCenter);
      expect(label.position.y, TownLayout.footprint * 16 + 1);
    },
  );
  testWithGame<TownGame>(
    'the camera snaps to whole screen pixels so tiles never shimmer',
    buildGame,
    (game) async {
      await game.ready();
      game.cameraControls.zoomTo(3);
      game.cameraControls.panByScreen(-1, -2);
      game.update(0);
      final position = game.camera.viewfinder.position;
      expect(position.x * 3, closeTo((position.x * 3).roundToDouble(), 1e-3));
      expect(position.y * 3, closeTo((position.y * 3).roundToDouble(), 1e-3));
      expect(position.x, isNot(game.cameraControls.centerX));
    },
  );

  const household = [
    (name: 'Kit', isPet: false),
    (name: 'Miso', isPet: true),
  ];

  testWithGame<TownGame>(
    'each dependent and pet strolls the town beside the two default villagers',
    () => buildGame(ambientLife: true, townsfolk: household),
    (game) async {
      await game.ready();
      final villagers = game.world.children.whereType<Villager>().toList();
      expect(villagers, hasLength(4));
      final folk = villagers.skip(2).toList();
      expect(folk.map((villager) => villager.label), ['Kit', 'Miso']);
      expect(folk.map((villager) => villager.assetKey), [
        const AssetKey('npc', 'villager', 'a'),
        const AssetKey('npc', 'pet', 'default'),
      ]);
      expect(
        folk[1].position.x - folk[0].position.x,
        2 * kTileSize,
        reason: 'staggered two tiles apart',
      );
    },
  );

  testWithGame<TownGame>(
    'townsfolk stay home when ambient life is off',
    () => buildGame(townsfolk: household),
    (game) async {
      await game.ready();
      expect(game.world.children.whereType<Villager>(), isEmpty);
    },
  );

  testWithGame<TownGame>(
    'updateTownsfolk replaces the strollers and keeps the default villagers',
    () => buildGame(ambientLife: true, townsfolk: household),
    (game) async {
      await game.ready();
      await game.updateTownsfolk(const [(name: 'Rex', isPet: true)]);
      await game.ready();
      final villagers = game.world.children.whereType<Villager>().toList();
      expect(villagers, hasLength(3));
      expect(villagers.skip(2).single.label, 'Rex');
      await game.updateTownsfolk(const []);
      await game.ready();
      expect(game.world.children.whereType<Villager>(), hasLength(2));
    },
  );

  testWithGame<TownGame>(
    'updateTownsfolk does nothing while ambient life is off',
    buildGame,
    (game) async {
      await game.ready();
      await game.updateTownsfolk(household);
      await game.ready();
      expect(game.world.children.whereType<Villager>(), isEmpty);
    },
  );
}
