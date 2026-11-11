/// The trade road between neighbouring towns. On every household day two or
/// more adults were active (Adventure adults logged or checked in; a
/// Standard adult backed the party as its supply caravan), each active
/// Adventure adult receives a caravan from every other active neighbour:
/// [Balance.tradeRoadAmount] of what that neighbour's town makes most of,
/// scaled by the tier of the producer making it. A Standard neighbour sends
/// [Balance.caravanTradeBundle]. The goods are generated, never taken from
/// the neighbour, and nobody alone ever gets one, or loses anything.
///
/// One reward per (recipient, day, neighbour), so a neighbour's log that
/// syncs in late tops the day up instead of being locked out, and two
/// devices granting the same caravan credit it once. The trade road opens
/// on the day the towns were split.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../game_state.dart';
import '../game_values.dart';

/// The reward id of the caravan [neighbourId] sends [who] for [day].
String tradeRoadRewardId(String who, GameDay day, String neighbourId) =>
    'trade.road:$who:${day.toKey()}:$neighbourId';

/// What [giverTown]'s caravan carries at [now]: [Balance.tradeRoadAmount]
/// of the material its busiest producer makes (highest hourly rate at the
/// tier in service, ties to the earlier [MaterialKind]), scaled by that
/// producer's tier. A town with no working producer sends
/// [Balance.tradeRoadFallbackMaterial] at the base amount.
MaterialBundle tradeRoadDelivery(HallState giverTown, DateTime now) {
  var material = Balance.tradeRoadFallbackMaterial;
  var bestRate = 0;
  var bestTier = 0;
  final indices = giverTown.plots.keys.toList()..sort();
  for (final index in indices) {
    final building = giverTown.plots[index]!.building;
    if (building == null) continue;
    final tier = building.tierAt(now);
    if (tier < 1) continue;
    final spec = Balance.buildings[building.type]!;
    for (final entry in spec.productionPerHour.entries) {
      final rate = entry.value[tier - 1];
      final better = rate > bestRate ||
          (rate == bestRate && rate > 0 && entry.key.index < material.index);
      if (better) {
        material = entry.key;
        bestRate = rate;
        bestTier = tier;
      }
    }
  }
  return MaterialBundle({material: Balance.tradeRoadAmount(bestTier)});
}

/// One caravan due on the trade road.
typedef TradeRoadCaravan = ({String who, GameDay day, String neighbourId});

/// Every caravan due from [from] to [to] inclusive: for each day, each
/// Adventure adult active that day ([adventurerDays]) gets one from every
/// other active Adventure adult and from every Standard adult whose caravan
/// rolled that day ([caravanDays]). Ordered by day, recipient, neighbour.
List<TradeRoadCaravan> tradeRoadCaravansDue({
  required GameDay from,
  required GameDay to,
  required Map<String, Set<GameDay>> adventurerDays,
  required Map<String, Set<GameDay>> caravanDays,
}) {
  final adventurers = adventurerDays.keys.toList()..sort();
  final standards = caravanDays.keys.toList()..sort();
  final due = <TradeRoadCaravan>[];
  for (var day = from; day <= to; day = day.next()) {
    final active = [
      for (final id in adventurers)
        if (adventurerDays[id]!.contains(day)) id,
    ];
    final caravans = [
      for (final id in standards)
        if (caravanDays[id]!.contains(day)) id,
    ];
    for (final who in active) {
      for (final neighbour in [...active, ...caravans]) {
        if (neighbour == who) continue;
        due.add((who: who, day: day, neighbourId: neighbour));
      }
    }
  }
  return due;
}
