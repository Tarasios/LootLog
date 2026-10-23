// app/test/game/domain/decor/decor_projection_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';

var _sequence = 0;
DateTime _at() => DateTime.utc(2026, 10, 23, 12, 0, _sequence);
String _id() => '01900000-0000-7000-8000-${(++_sequence).toString().padLeft(12, '0')}';

RewardGranted gems(String personId, int amount) => RewardGranted(
      eventId: _id(), deviceId: 'd', actorId: personId, occurredAt: _at(), createdAt: _at(),
      rewardId: 'test:$personId:$_sequence', kind: 'gems', gems: amount, materials: const MaterialBundle.empty(), tokens: 0,
      reasonCode: 'test', sourceLedgerEventIds: const [],
    );

RewardClaimed claim(String personId, String rewardId) => RewardClaimed(
      eventId: _id(), deviceId: 'd', actorId: personId, occurredAt: _at(), createdAt: _at(), rewardId: rewardId,
    );

ItemAcquired acquired(String personId, String itemId, {String? acquisitionId, bool toTown = false}) => ItemAcquired(
      eventId: _id(), deviceId: 'd', actorId: personId, occurredAt: _at(), createdAt: _at(),
      acquisitionId: acquisitionId ?? 'test:${_sequence + 1}', itemId: itemId, source: DecorSource.chest, toTown: toTown,
    );

ItemPurchased purchased(String personId, String itemId, int cost) => ItemPurchased(
      eventId: _id(), deviceId: 'd', actorId: personId, occurredAt: _at(), createdAt: _at(), itemId: itemId, gemCost: cost,
    );

ItemPlaced placed(String personId, String placementId, String itemId,
        {DecorSpace space = DecorSpace.room, int column = 1, int row = 1, int rotation = 0}) =>
    ItemPlaced(
      eventId: _id(), deviceId: 'd', actorId: personId, occurredAt: _at(), createdAt: _at(),
      placementId: placementId, itemId: itemId, space: space, column: column, row: row, rotation: rotation,
    );

ItemStored stored(String personId, String placementId) => ItemStored(
      eventId: _id(), deviceId: 'd', actorId: personId, occurredAt: _at(), createdAt: _at(), placementId: placementId,
    );

void main() {
  test('acquiring adds to the person\'s inventory; the same acquisition id counts once', () {
    final events = [
      acquired('alex', 'rug_round', acquisitionId: 'chest:1'),
      acquired('alex', 'rug_round', acquisitionId: 'chest:1'),
      acquired('alex', 'rug_round', acquisitionId: 'chest:2'),
    ];
    final state = projectGameState(events);
    expect(state.decor.ownedCount('alex', 'rug_round'), 2);
    expect(state.warnings.map((warning) => warning.code), contains(GameWarningCode.duplicateAcquisition));
  });

  test('buying pays gems and adds the item; town decor goes to the shared pool', () {
    final grant = gems('alex', 50);
    final events = [
      grant,
      claim('alex', grant.rewardId),
      purchased('alex', 'rug_round', 8),
      purchased('alex', 'town_bench', 12),
    ];
    final state = projectGameState(events);
    expect(state.person('alex').gems, 30);
    expect(state.decor.ownedCount('alex', 'rug_round'), 1);
    expect(state.decor.townAvailableCount('town_bench'), 1);
  });

  test('placing uses an available copy; storing gives it back; re-placing moves it', () {
    var state = projectGameState([
      acquired('alex', 'rug_round', acquisitionId: 'a'),
      placed('alex', 'p1', 'rug_round', column: 2, row: 3),
    ]);
    expect(state.decor.availableCount('alex', 'rug_round'), 0);
    expect(state.decor.placementsInRoom('alex').single.column, 2);
    state = state.apply(placed('alex', 'p1', 'rug_round', column: 5, row: 1, rotation: 1));
    expect(state.decor.placementsInRoom('alex').single.column, 5);
    expect(state.decor.placementsInRoom('alex').single.rotation, 1);
    state = state.apply(stored('alex', 'p1'));
    expect(state.decor.placementsInRoom('alex'), isEmpty);
    expect(state.decor.availableCount('alex', 'rug_round'), 1);
  });

  test('placing an item not owned is ignored with a warning', () {
    final state = projectGameState([placed('alex', 'p1', 'bed_canopy')]);
    expect(state.decor.placementsInRoom('alex'), isEmpty);
    expect(state.warnings.single.code, GameWarningCode.decorNotOwned);
  });

  test('town placements come from the shared pool and anyone may store them', () {
    final state = projectGameState([
      acquired('alex', 'town_bench', acquisitionId: 'b', toTown: true),
      placed('sam', 't1', 'town_bench', space: DecorSpace.town, column: 4, row: 2),
    ]);
    expect(state.decor.townPlacements.single.itemId, 'town_bench');
    final afterStore = state.apply(stored('alex', 't1'));
    expect(afterStore.decor.townPlacements, isEmpty);
  });

  test('equipping an outfit or a title', () {
    final state = projectGameState([
      acquired('alex', 'outfit_ranger', acquisitionId: 'o'),
      acquired('alex', 'streak_7_title', acquisitionId: 't'),
      ItemEquipped(eventId: _id(), deviceId: 'd', actorId: 'alex', occurredAt: _at(), createdAt: _at(), itemId: 'outfit_ranger'),
      ItemEquipped(eventId: _id(), deviceId: 'd', actorId: 'alex', occurredAt: _at(), createdAt: _at(), itemId: 'streak_7_title'),
    ]);
    expect(state.decor.outfitOf('alex'), 'outfit_ranger');
    expect(state.decor.titleOf('alex'), 'streak_7_title');
  });

  test('equipping an id that is neither an outfit nor a title changes nothing', () {
    final state = projectGameState([
      ItemEquipped(eventId: _id(), deviceId: 'd', actorId: 'alex', occurredAt: _at(), createdAt: _at(), itemId: 'rug_round'),
    ]);
    expect(state.decor.outfitOf('alex'), isNull);
    expect(state.decor.titleOf('alex'), isNull);
  });
}
