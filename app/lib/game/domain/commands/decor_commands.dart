/// Decoration commands: buy from today's shop, claim the starter set, place,
/// move, rotate or store items, and wear an outfit or title. Pure functions
/// from the current state to the events to append (or a rejection), like
/// `GameCommands`. Pure Dart.
library;

import '../clock.dart';
import '../decor/catalog.dart';
import '../decor/decor_state.dart';
import '../decor/decor_values.dart';
import '../decor/room_grid.dart';
import '../decor/shop_rotation.dart';
import '../game_event.dart';
import '../game_event_stamp.dart';
import '../game_state.dart';
import '../game_values.dart';
import '../town/town_layout.dart';
import 'game_commands.dart';

String starterAcquisitionId(String personId, String itemId) => 'starter:$personId:$itemId';

class DecorCommands {
  DecorCommands({
    required this.state,
    required this.clock,
    required this.actorId,
    required this.stamp,
    required this.catalog,
    this.townLayout = TownLayout.standard,
  });

  final GameState state;
  final Clock clock;
  final String actorId;
  final GameEventStamp stamp;
  final DecorCatalog catalog;
  final TownLayout townLayout;

  late final DateTime _now = clock.now();
  DecorState get _decor => state.decor;

  GameCommandResult buyItem(String itemId) {
    final item = catalog.itemFor(itemId);
    if (item == null) return const GameCommandResult.rejected(GameRejection.unknownItem);
    final todaysShop = ShopRotation.forDay(catalog, GameDay.fromInstant(_now));
    if (!todaysShop.any((shopItem) => shopItem.id == itemId)) {
      return const GameCommandResult.rejected(GameRejection.notInShopToday);
    }
    final price = item.priceGems!;
    if (state.person(actorId).gems < price) return const GameCommandResult.rejected(GameRejection.notEnoughGems);
    return GameCommandResult.accepted([
      ItemPurchased(
        eventId: stamp.newEventId(), deviceId: stamp.deviceId, actorId: actorId,
        occurredAt: _now, createdAt: _now, itemId: itemId, gemCost: price,
      ),
    ]);
  }

  GameCommandResult claimStarterSet() {
    final pending = [
      for (final item in catalog.starterSet)
        if (!_decor.seenAcquisitionIds.contains(starterAcquisitionId(actorId, item.id))) item,
    ];
    if (pending.isEmpty) return const GameCommandResult.rejected(GameRejection.starterAlreadyClaimed);
    return GameCommandResult.accepted([
      for (final item in pending)
        ItemAcquired(
          eventId: stamp.newEventId(), deviceId: stamp.deviceId, actorId: actorId,
          occurredAt: _now, createdAt: _now,
          acquisitionId: starterAcquisitionId(actorId, item.id), itemId: item.id, source: DecorSource.starter,
        ),
    ]);
  }

  GameCommandResult placeItem({
    required String itemId,
    required DecorSpace space,
    required int column,
    required int row,
    int rotation = 0,
    String? placementId,
  }) {
    final item = catalog.itemFor(itemId);
    if (item == null) return const GameCommandResult.rejected(GameRejection.unknownItem);
    final isTown = space == DecorSpace.town;
    if (isTown ? !item.placeableInTown : !item.placeableInRoom) {
      return const GameCommandResult.rejected(GameRejection.wrongSpace);
    }
    final existing = placementId == null ? null : _decor.placements[placementId];
    if (existing != null && existing.space == DecorSpace.room && existing.ownerId != actorId) {
      return const GameCommandResult.rejected(GameRejection.notYourRoom);
    }
    // A move within the same space reuses the copy already placed; moving
    // between room and town needs a free copy on the other side.
    final movingSameCopy = existing != null && existing.itemId == itemId && existing.space == space;
    final available = isTown ? _decor.townAvailableCount(itemId) : _decor.availableCount(actorId, itemId);
    if (!movingSameCopy && available <= 0) return const GameCommandResult.rejected(GameRejection.itemNotOwned);

    final normalisedRotation = rotation % 4;
    final others = [
      for (final placement in isTown ? _decor.townPlacements : _decor.placementsInRoom(actorId))
        if (placement.placementId != placementId) placement,
    ];
    if (isTown) {
      final spotOk = item.kind == DecorKind.statue
          ? townLayout.statueSpots.contains(TownCell(column, row))
          : TownDecorSpots.isFreeGrass(townLayout, column, row);
      if (!spotOk) return const GameCommandResult.rejected(GameRejection.outOfBounds);
      if (others.any((placement) => placement.column == column && placement.row == row)) {
        return const GameCommandResult.rejected(GameRejection.cellOccupied);
      }
    } else {
      if (!RoomGrid.fits(item, column, row, normalisedRotation)) {
        return const GameCommandResult.rejected(GameRejection.outOfBounds);
      }
      final wanted = RoomGrid.cellsOf(item, column, row, normalisedRotation);
      for (final placement in others) {
        final otherItem = catalog.itemFor(placement.itemId);
        if (otherItem == null) continue;
        final taken = RoomGrid.cellsOf(otherItem, placement.column, placement.row, placement.rotation);
        if (taken.intersection(wanted).isNotEmpty) {
          return const GameCommandResult.rejected(GameRejection.cellOccupied);
        }
      }
    }
    final eventId = stamp.newEventId();
    return GameCommandResult.accepted([
      ItemPlaced(
        eventId: eventId, deviceId: stamp.deviceId, actorId: actorId,
        occurredAt: _now, createdAt: _now,
        placementId: placementId ?? eventId, itemId: itemId, space: space,
        column: column, row: row, rotation: normalisedRotation,
      ),
    ]);
  }

  GameCommandResult storePlacement(String placementId) {
    final placement = _decor.placements[placementId];
    if (placement == null) return const GameCommandResult.rejected(GameRejection.unknownPlacement);
    if (placement.space == DecorSpace.room && placement.ownerId != actorId) {
      return const GameCommandResult.rejected(GameRejection.notYourRoom);
    }
    return GameCommandResult.accepted([
      ItemStored(
        eventId: stamp.newEventId(), deviceId: stamp.deviceId, actorId: actorId,
        occurredAt: _now, createdAt: _now, placementId: placementId,
      ),
    ]);
  }

  GameCommandResult equipItem(String itemId) {
    final item = catalog.itemFor(itemId);
    if (item == null) return const GameCommandResult.rejected(GameRejection.unknownItem);
    if (!item.equippable) return const GameCommandResult.rejected(GameRejection.notEquippable);
    if (_decor.ownedCount(actorId, itemId) <= 0) return const GameCommandResult.rejected(GameRejection.itemNotOwned);
    return GameCommandResult.accepted([
      ItemEquipped(
        eventId: stamp.newEventId(), deviceId: stamp.deviceId, actorId: actorId,
        occurredAt: _now, createdAt: _now, itemId: itemId,
      ),
    ]);
  }
}
