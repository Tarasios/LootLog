/// The daily town event: when a person opens their day with a first log or a
/// "no spend" check-in, something turns up in town — a visiting trader
/// offering a swap, a producer having a good day (a windfall), or a visitor
/// with a gift. Taking it is a choice, never a chore; waving it off costs
/// nothing.
///
/// [rollDailyOffer] is pure and deterministic: the reward engine calls it
/// once, seeded by the id of the ledger event that opened the day, and
/// stores the result in a `DailyEventOffered` event, so every device shows
/// the same offer and nothing is ever re-rolled. The wording lives in
/// `assets/game/text/town_events.json` ([dailyEventFlavourKeys]).
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../game_rng.dart';
import '../game_state.dart';
import '../game_values.dart';

export '../game_state.dart' show DailyOffer;
export '../game_values.dart' show DailyEventKind;

/// The flavour lines each kind has in `town_events.json`.
const int kDailyEventFlavourLines = 3;

/// The deterministic id of [personId]'s daily event for [day]: one per
/// person per day, so a second device's copy is credited once.
String dailyEventOfferId(String personId, GameDay day) =>
    'daily.event:$personId:${day.toKey()}';

/// The `town_events.json` keys a [kind] may tell its story with.
List<String> dailyEventFlavourKeys(DailyEventKind kind) => [
  for (var line = 1; line <= kDailyEventFlavourLines; line++)
    '${kind.name}.$line',
];

/// Rolls [personId]'s daily event for [day] from the hall as it stands at
/// [now], with the RNG seeded by [seedEventId] (the ledger event that opened
/// the day).
///
/// The kind follows [Balance.dailyEventWeights]; a windfall needs a working
/// producer, otherwise the roll is among the other kinds.
DailyOffer rollDailyOffer({
  required String personId,
  required GameDay day,
  required String seedEventId,
  required HallState hall,
  required DateTime now,
}) {
  final rng = GameRng.forEvent(seedEventId);
  final producers = _workingProducers(hall, now);
  final kind = _rollKind(rng, hasProducer: producers.isNotEmpty);
  final offerId = dailyEventOfferId(personId, day);
  final flavourKey = rng.pick(dailyEventFlavourKeys(kind));

  DailyOffer offer({
    MaterialBundle gives = const MaterialBundle.empty(),
    required Loot receives,
    int? plotIndex,
  }) => DailyOffer(
    offerId: offerId,
    day: day,
    kind: kind,
    gives: gives,
    receives: receives,
    flavourKey: flavourKey,
    plotIndex: plotIndex,
  );

  switch (kind) {
    case DailyEventKind.windfall:
      final plot = rng.pick(producers);
      return offer(
        receives: Loot(materials: _windfall(plot, now)),
        plotIndex: plot.index,
      );
    case DailyEventKind.trader:
      final hallTier = hall.completedTier(BuildingType.centralHall, now);
      final (:plentiful, :scarce) = _tradePair(hall.materials);
      return offer(
        gives: MaterialBundle({plentiful: Balance.traderGiveAmount(hallTier)}),
        receives: Loot(
          materials: MaterialBundle({
            scarce: Balance.traderReceiveAmount(hallTier),
          }),
        ),
      );
    case DailyEventKind.visitor:
      if (rng.chance(Balance.visitorGemChancePermille)) {
        return offer(receives: const Loot(gems: Balance.visitorGiftGems));
      }
      final material = rng.pick(Balance.visitorGiftMaterials);
      return offer(
        receives: Loot(
          materials: MaterialBundle({material: Balance.visitorGift}),
        ),
      );
  }
}

DailyEventKind _rollKind(GameRng rng, {required bool hasProducer}) {
  final weights = [
    for (final kind in DailyEventKind.values)
      if (hasProducer || kind != DailyEventKind.windfall)
        (kind: kind, weight: Balance.dailyEventWeights[kind] ?? 0),
  ];
  final total = weights.fold(0, (sum, entry) => sum + entry.weight);
  var roll = rng.nextInt(total);
  for (final entry in weights) {
    if (roll < entry.weight) return entry.kind;
    roll -= entry.weight;
  }
  return weights.last.kind;
}

/// Plots holding a producer whose tier in service at [now] is at least 1,
/// in plot order.
List<PlotState> _workingProducers(HallState hall, DateTime now) {
  final indices = hall.plots.keys.toList()..sort();
  return [
    for (final index in indices)
      if (hall.plots[index]!.building case final BuildingState building
          when Balance.buildings[building.type]!.isProducer &&
              building.tierAt(now) >= 1)
        hall.plots[index]!,
  ];
}

/// [Balance.windfallHours] of [plot]'s producer at its tier in service.
MaterialBundle _windfall(PlotState plot, DateTime now) {
  final building = plot.building!;
  final tier = building.tierAt(now);
  final spec = Balance.buildings[building.type]!;
  return MaterialBundle({
    for (final entry in spec.productionPerHour.entries)
      entry.key: entry.value[tier - 1] * Balance.windfallHours,
  });
}

/// The pool's most plentiful trade material and its scarcest other one
/// (ties go to the earlier material in [Balance.tradeMaterials]).
({MaterialKind plentiful, MaterialKind scarce}) _tradePair(
  MaterialBundle pool,
) {
  var plentiful = Balance.tradeMaterials.first;
  for (final kind in Balance.tradeMaterials) {
    if (pool[kind] > pool[plentiful]) plentiful = kind;
  }
  MaterialKind? scarce;
  for (final kind in Balance.tradeMaterials) {
    if (kind == plentiful) continue;
    if (scarce == null || pool[kind] < pool[scarce]) scarce = kind;
  }
  return (plentiful: plentiful, scarce: scarce!);
}
