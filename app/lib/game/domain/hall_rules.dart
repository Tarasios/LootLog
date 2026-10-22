/// Read-side rules of the guild hall that both the commands and the UI need:
/// what a building has produced, what fits in the Storehouse, how high a
/// building may go. Pure functions of the [HallState] and an instant.
///
/// Pure Dart, zero Flutter imports.
library;

import '../config/balance.dart';
import 'game_state.dart';
import 'game_values.dart';

/// What the building on [plotIndex] has produced since it was last collected
/// (or since it was built), as of [now], before any Storehouse cap. Empty for
/// an empty plot or a building that produces nothing.
///
/// While an upgrade is under way the building keeps producing at its old
/// tier; from the moment it completes, at the new one.
MaterialBundle uncollectedProduction(HallState hall, int plotIndex, DateTime now) {
  final plot = hall.plots[plotIndex];
  final b = plot?.building;
  if (plot == null || b == null) return const MaterialBundle.empty();
  final spec = Balance.buildings[b.type]!;
  if (!spec.isProducer) return const MaterialBundle.empty();

  // A never-collected building produces from its first completion. Upgrades
  // bank production first, so a never-collected building is still tier 1
  // (its startedAt is the fallback for a race between devices).
  final from = hall.lastCollectedAt[plot.buildingId] ??
      (b.tier == 1 ? b.completesAt : b.startedAt);
  if (!now.isAfter(from)) return const MaterialBundle.empty();

  final oldEnd = now.isBefore(b.completesAt) ? now : b.completesAt;
  final oldMinutes = from.isBefore(oldEnd) ? oldEnd.difference(from).inMinutes : 0;
  final newStart = from.isAfter(b.completesAt) ? from : b.completesAt;
  final newMinutes =
      now.isAfter(newStart) ? now.difference(newStart).inMinutes : 0;

  int rate(List<int> rates, int tier) => tier < 1 ? 0 : rates[tier - 1];
  return MaterialBundle({
    for (final e in spec.productionPerHour.entries)
      e.key: (rate(e.value, b.tier - 1) * oldMinutes +
              rate(e.value, b.tier) * newMinutes) ~/
          60,
  });
}

/// The part of [wanted] the shared pool has room for at [now]: each capped
/// kind is limited to the Storehouse capacity minus what the pool holds.
MaterialBundle fitInStorehouse(HallState hall, MaterialBundle wanted, DateTime now) {
  final capacity = hall.storageCapacityAt(now);
  return MaterialBundle({
    for (final e in wanted.amounts.entries)
      e.key: Balance.uncappedMaterials.contains(e.key)
          ? e.value
          : _min(e.value, _max(0, capacity - hall.materials[e.key])),
  });
}

/// What collecting [plotIndex] at [now] would bank.
MaterialBundle collectableNow(HallState hall, int plotIndex, DateTime now) =>
    fitInStorehouse(hall, uncollectedProduction(hall, plotIndex, now), now);

/// The highest tier [type] may be built to at [now]: [Balance.maxBuildingTier]
/// for the Central Hall itself; for everything else the Central Hall's
/// completed tier (or [Balance.maxTierWithoutCentralHall] without one).
int maxTierAllowed(HallState hall, BuildingType type, DateTime now) {
  if (type == BuildingType.centralHall) return Balance.maxBuildingTier;
  final hallTier = hall.completedTier(BuildingType.centralHall, now);
  return _min(Balance.maxBuildingTier,
      _max(Balance.maxTierWithoutCentralHall, hallTier));
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;
