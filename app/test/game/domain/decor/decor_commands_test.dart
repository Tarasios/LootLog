import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/decor_commands.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/decor/shop_rotation.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';

final now = DateTime.utc(2026, 10, 23, 18);
final catalog = DecorCatalog.fromJson(
    jsonDecode(File('assets/game/catalog.json').readAsStringSync()) as Map<String, dynamic>);
var _counter = 0;
final stamp = GameEventStamp(deviceId: 'd', newEventId: () => '01900000-0000-7000-9000-${(++_counter).toString().padLeft(12, '0')}');

DecorCommands commandsFor(GameState state) =>
    DecorCommands(state: state, clock: FixedClock(now), actorId: 'alex', stamp: stamp, catalog: catalog);

GameState withGems(int amount) {
  final grant = RewardGranted(
    eventId: '01900000-0000-7000-8000-000000000001', deviceId: 'd', actorId: 'alex',
    occurredAt: now.subtract(const Duration(hours: 1)), createdAt: now,
    rewardId: 'test:gems', kind: 'gems', gems: amount, materials: const MaterialBundle.empty(),
    tokens: 0, reasonCode: 'test', sourceLedgerEventIds: const [],
  );
  final claim = RewardClaimed(
    eventId: '01900000-0000-7000-8000-000000000002', deviceId: 'd', actorId: 'alex',
    occurredAt: now.subtract(const Duration(minutes: 30)), createdAt: now, rewardId: 'test:gems',
  );
  return projectGameState([grant, claim]);
}

GameState applyAll(GameState state, GameCommandResult result) {
  var next = state;
  for (final event in result.events) {
    next = next.apply(event);
  }
  return next;
}

void main() {
  final todaysShop = ShopRotation.forDay(catalog, GameDay.fromInstant(now));

  test('buying an item from today\'s shop', () {
    final item = todaysShop.first;
    final result = commandsFor(withGems(100)).buyItem(item.id);
    expect(result.accepted, isTrue);
    final purchase = result.events.single as ItemPurchased;
    expect(purchase.gemCost, item.priceGems);
  });

  test('buying is refused when the item is not in today\'s shop, unknown, or too dear', () {
    final notToday = catalog.shopPool.firstWhere((item) => !todaysShop.contains(item));
    expect(commandsFor(withGems(1000)).buyItem(notToday.id).rejection, GameRejection.notInShopToday);
    expect(commandsFor(withGems(1000)).buyItem('no_such_item').rejection, GameRejection.unknownItem);
    expect(commandsFor(withGems(0)).buyItem(todaysShop.first.id).rejection, GameRejection.notEnoughGems);
  });

  test('the starter set is claimed once', () {
    final first = commandsFor(GameState.initial()).claimStarterSet();
    expect(first.events, hasLength(catalog.starterSet.length));
    final after = applyAll(GameState.initial(), first);
    expect(commandsFor(after).claimStarterSet().rejection, GameRejection.starterAlreadyClaimed);
  });

  test('placing an owned item, then a clash, then off the grid', () {
    final owned = applyAll(GameState.initial(), commandsFor(GameState.initial()).claimStarterSet());
    final placed = commandsFor(owned).placeItem(itemId: 'bed_simple', space: DecorSpace.room, column: 0, row: 0);
    expect(placed.accepted, isTrue);
    final withBed = applyAll(owned, placed);
    expect(
      commandsFor(withBed).placeItem(itemId: 'lamp_small', space: DecorSpace.room, column: 0, row: 1).rejection,
      GameRejection.cellOccupied,
    );
    expect(
      commandsFor(withBed).placeItem(itemId: 'lamp_small', space: DecorSpace.room, column: 10, row: 0).rejection,
      GameRejection.outOfBounds,
    );
    expect(
      commandsFor(withBed).placeItem(itemId: 'bed_canopy', space: DecorSpace.room, column: 5, row: 5).rejection,
      GameRejection.itemNotOwned,
    );
  });

  test('furniture cannot go in town and town decor cannot go in a room', () {
    final owned = applyAll(GameState.initial(), commandsFor(GameState.initial()).claimStarterSet());
    expect(
      commandsFor(owned).placeItem(itemId: 'rug_round', space: DecorSpace.town, column: 1, row: 5).rejection,
      GameRejection.wrongSpace,
    );
    expect(
      commandsFor(owned).placeItem(itemId: 'town_bench', space: DecorSpace.room, column: 1, row: 1).rejection,
      GameRejection.wrongSpace,
    );
  });

  test('moving a placed item ignores its own old cells', () {
    final owned = applyAll(GameState.initial(), commandsFor(GameState.initial()).claimStarterSet());
    final placed = commandsFor(owned).placeItem(itemId: 'bed_simple', space: DecorSpace.room, column: 0, row: 0);
    final withBed = applyAll(owned, placed);
    final placementId = (placed.events.single as ItemPlaced).placementId;
    final moved = commandsFor(withBed).placeItem(
        itemId: 'bed_simple', space: DecorSpace.room, column: 0, row: 1, placementId: placementId);
    expect(moved.accepted, isTrue);
  });

  test('storing someone else\'s room item is refused', () {
    final owned = applyAll(GameState.initial(), commandsFor(GameState.initial()).claimStarterSet());
    final placed = commandsFor(owned).placeItem(itemId: 'lamp_small', space: DecorSpace.room, column: 2, row: 2);
    final withLamp = applyAll(owned, placed);
    final placementId = (placed.events.single as ItemPlaced).placementId;
    final samCommands = DecorCommands(state: withLamp, clock: FixedClock(now), actorId: 'sam', stamp: stamp, catalog: catalog);
    expect(samCommands.storePlacement(placementId).rejection, GameRejection.notYourRoom);
    expect(commandsFor(withLamp).storePlacement(placementId).accepted, isTrue);
    expect(commandsFor(withLamp).storePlacement('nope').rejection, GameRejection.unknownPlacement);
  });

  test('equipping needs an owned outfit or title', () {
    final owned = applyAll(GameState.initial(), commandsFor(GameState.initial()).claimStarterSet());
    expect(commandsFor(owned).equipItem('outfit_traveller').accepted, isTrue);
    expect(commandsFor(owned).equipItem('rug_round').rejection, GameRejection.notEquippable);
    expect(commandsFor(owned).equipItem('outfit_knight').rejection, GameRejection.itemNotOwned);
  });

  GameState withTownItems() => projectGameState([
        ItemAcquired(
          eventId: '01900000-0000-7000-8000-000000000100', deviceId: 'd', actorId: 'alex',
          occurredAt: now.subtract(const Duration(minutes: 10)), createdAt: now,
          acquisitionId: 'bench-1', itemId: 'town_bench', source: DecorSource.chest, toTown: true,
        ),
        ItemAcquired(
          eventId: '01900000-0000-7000-8000-000000000110', deviceId: 'd', actorId: 'alex',
          occurredAt: now.subtract(const Duration(minutes: 5)), createdAt: now,
          acquisitionId: 'statue-1', itemId: 'statue:q1', source: DecorSource.trophy, toTown: true,
        ),
      ]);

  test('town decor needs free grass, statues need a statue spot, one item per cell', () {
    final state = withTownItems();
    expect(commandsFor(state).placeItem(itemId: 'town_bench', space: DecorSpace.town, column: 1, row: 5).accepted, isTrue);
    expect(
      commandsFor(state).placeItem(itemId: 'town_bench', space: DecorSpace.town, column: 14, row: 3).rejection,
      GameRejection.outOfBounds,
    );
    expect(
      commandsFor(state).placeItem(itemId: 'statue:q1', space: DecorSpace.town, column: 1, row: 5).rejection,
      GameRejection.outOfBounds,
    );
    expect(commandsFor(state).placeItem(itemId: 'statue:q1', space: DecorSpace.town, column: 12, row: 8).accepted, isTrue);
    final placedBench = commandsFor(state).placeItem(itemId: 'town_bench', space: DecorSpace.town, column: 1, row: 5);
    final withBench = applyAll(state, placedBench);
    expect(
      commandsFor(withBench).placeItem(itemId: 'town_bench', space: DecorSpace.town, column: 1, row: 5).rejection,
      GameRejection.itemNotOwned,
      reason: 'the only town copy is already out',
    );
  });
}
