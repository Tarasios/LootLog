/// Builders for the town-growth tests: prosperity, tiers, districts and
/// food events, plus the decoration events that count toward prosperity.
library;

import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';

import '../game_fixtures.dart';

ProsperityReached prosperityReached(String id, int value,
        {required DateTime when, String actor = robin, String device = 'dev-1'}) =>
    ProsperityReached(
      eventId: id,
      deviceId: device,
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      value: value,
    );

TierReached tierReached(String id, TownTier tier,
        {required DateTime when, String actor = robin, String device = 'dev-1'}) =>
    TierReached(
      eventId: id,
      deviceId: device,
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      tier: tier,
    );

FestivalHeld festivalHeld(String id, GameDay week,
        {required DateTime when,
        String actor = robin,
        FestivalTier tier = FestivalTier.marketDay}) =>
    FestivalHeld(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      week: week,
      tier: tier,
      weekdaysLogged: 0,
    );

/// [count] festivals for [actor], one per week going back from [lastWeek].
List<FestivalHeld> festivals(int count,
        {required DateTime when, String actor = robin, GameDay? lastWeek}) {
  final week = (lastWeek ?? GameDay.fromInstant(when)).weekStart;
  return [
    for (var i = 0; i < count; i++)
      festivalHeld('fest-$actor-$i', week.addDays(-7 * i), when: when, actor: actor),
  ];
}

/// A town decoration acquired and placed at column [index].
List<GameEvent> townDecoration(int index, {required DateTime when, String actor = robin}) => [
      ItemAcquired(
        eventId: 'deco-acq-$index',
        deviceId: 'dev-1',
        actorId: actor,
        occurredAt: when,
        createdAt: when,
        acquisitionId: 'deco-$index',
        itemId: 'town_bench',
        source: DecorSource.chest,
        toTown: true,
      ),
      ItemPlaced(
        eventId: 'deco-place-$index',
        deviceId: 'dev-1',
        actorId: actor,
        occurredAt: when,
        createdAt: when,
        placementId: 'placement-$index',
        itemId: 'town_bench',
        space: DecorSpace.town,
        column: index,
        row: 0,
      ),
    ];

ItemStored storedAway(int index, {required DateTime when, String actor = robin}) =>
    ItemStored(
      eventId: 'deco-store-$index',
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      placementId: 'placement-$index',
    );

DistrictPurchased districtPurchased(String id, String districtId,
        {required DateTime when, String actor = robin, Loot cost = Loot.none}) =>
    DistrictPurchased(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      districtId: districtId,
      cost: cost,
    );

DistrictBuildingStarted farmBuilt(String id, int plotIndex, FarmBuildingType type,
        {required DateTime when,
        String actor = robin,
        int tier = 1,
        Loot cost = Loot.none,
        DateTime? completesAt,
        String districtId = 'farmland'}) =>
    DistrictBuildingStarted(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      districtId: districtId,
      plotIndex: plotIndex,
      buildingKey: type.name,
      tier: tier,
      cost: cost,
      completesAt: completesAt ?? when,
    );

FoodHarvested foodHarvested(String id, int plotIndex, int amount,
        {required DateTime when, String actor = robin}) =>
    FoodHarvested(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      districtId: 'farmland',
      plotIndex: plotIndex,
      amount: amount,
    );

FoodConsumed foodConsumed(String id, GameDay day, int amount,
        {required DateTime when, String actor = robin, String device = 'dev-1'}) =>
    FoodConsumed(
      eventId: id,
      deviceId: device,
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      day: day,
      amount: amount,
    );

/// Robin at the hamlet with [gems] gems and [lumber] lumber and [stone]
/// stone in the town, all claimed.
List<GameEvent> hamletWith({int gems = 0, int lumber = 0, int stone = 0, String actor = robin}) => [
      tierReached('hamlet-$actor', TownTier.hamlet, when: at(-3), actor: actor),
      granted('funds-$actor',
          when: at(-2),
          actor: actor,
          rewardId: 'funds-$actor',
          gems: gems,
          materials: MaterialBundle({MaterialKind.lumber: lumber, MaterialKind.stone: stone})),
      claimed('funds-claim-$actor', 'funds-$actor', when: at(-1), actor: actor),
    ];
