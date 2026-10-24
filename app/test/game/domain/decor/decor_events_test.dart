import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/game_event.dart';

final instant = DateTime.utc(2026, 10, 23, 12);

GameEvent roundTrip(GameEvent event) => GameEvent.fromJson(event.toJson());

void main() {
  test('ItemAcquired round-trips', () {
    final event = ItemAcquired(
      eventId: 'e1', deviceId: 'd', actorId: 'alex', occurredAt: instant, createdAt: instant,
      acquisitionId: 'starter:alex:bed_simple', itemId: 'bed_simple', source: DecorSource.starter,
    );
    final decoded = roundTrip(event) as ItemAcquired;
    expect(decoded.acquisitionId, 'starter:alex:bed_simple');
    expect(decoded.source, DecorSource.starter);
    expect(decoded.toTown, isFalse);
  });

  test('ItemPurchased, ItemPlaced, ItemStored and ItemEquipped round-trip', () {
    final purchased = roundTrip(ItemPurchased(
        eventId: 'e2', deviceId: 'd', actorId: 'alex', occurredAt: instant, createdAt: instant,
        itemId: 'rug_round', gemCost: 8)) as ItemPurchased;
    expect(purchased.gemCost, 8);
    final placed = roundTrip(ItemPlaced(
        eventId: 'e3', deviceId: 'd', actorId: 'alex', occurredAt: instant, createdAt: instant,
        placementId: 'p1', itemId: 'rug_round', space: DecorSpace.room, column: 3, row: 4, rotation: 1)) as ItemPlaced;
    expect([placed.column, placed.row, placed.rotation], [3, 4, 1]);
    expect(placed.space, DecorSpace.room);
    expect((roundTrip(ItemStored(
        eventId: 'e4', deviceId: 'd', actorId: 'alex', occurredAt: instant, createdAt: instant,
        placementId: 'p1')) as ItemStored).placementId, 'p1');
    expect((roundTrip(ItemEquipped(
        eventId: 'e5', deviceId: 'd', actorId: 'alex', occurredAt: instant, createdAt: instant,
        itemId: 'outfit_ranger')) as ItemEquipped).itemId, 'outfit_ranger');
  });

  test('a source this build does not know becomes an UnknownGameEvent', () {
    final json = ItemAcquired(
      eventId: 'e6', deviceId: 'd', actorId: 'alex', occurredAt: instant, createdAt: instant,
      acquisitionId: 'x', itemId: 'bed_simple', source: DecorSource.shop,
    ).toJson();
    (json['payload'] as Map)['source'] = 'raffle';
    expect(GameEvent.fromJson(json), isA<UnknownGameEvent>());
  });

  test('the new types are registered', () {
    expect(kGameEventTypes, containsAll(['ItemAcquired', 'ItemPurchased', 'ItemPlaced', 'ItemStored', 'ItemEquipped']));
  });
}
