import 'dart:convert';
import 'dart:io';

import 'package:flame/cache.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';
import 'package:lootlog/game/scenes/room/room_components.dart';
import 'package:lootlog/game/scenes/room/room_game.dart';

final instant = DateTime.utc(2026, 10, 23, 12);
final catalog = DecorCatalog.fromJson(
  jsonDecode(File('assets/game/catalog.json').readAsStringSync())
      as Map<String, dynamic>,
);

RoomView roomWithBed({String viewerId = 'alex'}) {
  final game = projectGameState([
    ItemAcquired(
      eventId: 'a1',
      deviceId: 'd',
      actorId: 'alex',
      occurredAt: instant,
      createdAt: instant,
      acquisitionId: 'starter:alex:bed_simple',
      itemId: 'bed_simple',
      source: DecorSource.starter,
    ),
    ItemAcquired(
      eventId: 'a2',
      deviceId: 'd',
      actorId: 'alex',
      occurredAt: instant,
      createdAt: instant,
      acquisitionId: 'starter:alex:outfit_traveller',
      itemId: 'outfit_traveller',
      source: DecorSource.starter,
    ),
    ItemPlaced(
      eventId: 'a3',
      deviceId: 'd',
      actorId: 'alex',
      occurredAt: instant,
      createdAt: instant,
      placementId: 'p1',
      itemId: 'bed_simple',
      space: DecorSpace.room,
      column: 2,
      row: 1,
    ),
    ItemEquipped(
      eventId: 'a4',
      deviceId: 'd',
      actorId: 'alex',
      occurredAt: instant,
      createdAt: instant,
      itemId: 'outfit_traveller',
    ),
  ]);
  return RoomView.from(
    game,
    catalog,
    personId: 'alex',
    ownerName: 'Alex',
    viewerId: viewerId,
  );
}

void main() {
  test('the room lists its placed items with the cells they cover', () {
    final view = roomWithBed();
    expect(view.items.single.item.id, 'bed_simple');
    expect(view.items.single.cells, {(2, 1), (2, 2)});
    expect(view.itemAt(2, 2)?.placement.placementId, 'p1');
    expect(view.itemAt(5, 5), isNull);
  });

  test('the worn outfit decides the character sprite', () {
    expect(
      roomWithBed().characterKey,
      catalog.itemFor('outfit_traveller')!.assetKey,
    );
  });

  test('only the owner may edit', () {
    expect(roomWithBed().editable, isTrue);
    expect(roomWithBed(viewerId: 'sam').editable, isFalse);
  });

  testWithGame<RoomGame>(
    'draws the floor, every placed item and the character with no art',
    () => RoomGame(
      atlas: PackAtlas(AssetRegistry.empty, Images(prefix: 'assets/game/')),
      view: roomWithBed(),
    ),
    (game) async {
      await game.ready();
      expect(game.world.children.whereType<RoomFloor>(), hasLength(1));
      expect(game.world.children.whereType<RoomItemComponent>(), hasLength(1));
      expect(game.world.children.whereType<RoomCharacter>(), hasLength(1));
    },
  );

  testWithGame<RoomGame>(
    'a new view replaces the items without duplicating the floor',
    () => RoomGame(
      atlas: PackAtlas(AssetRegistry.empty, Images(prefix: 'assets/game/')),
      view: roomWithBed(),
    ),
    (game) async {
      await game.ready();
      await game.updateView(
        RoomView(
          personId: 'alex',
          ownerName: 'Alex',
          items: const [],
          characterKey: RoomView.defaultCharacter,
          editable: true,
        ),
      );
      await game.ready();
      expect(game.world.children.whereType<RoomFloor>(), hasLength(1));
      expect(game.world.children.whereType<RoomItemComponent>(), isEmpty);
      expect(game.world.children.whereType<RoomCharacter>(), hasLength(1));
    },
  );
}
