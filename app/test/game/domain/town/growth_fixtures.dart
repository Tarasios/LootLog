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
