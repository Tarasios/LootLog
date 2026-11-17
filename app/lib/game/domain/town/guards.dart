/// A town's guards: the capacity its Guard Post's buildings add, and which
/// farmland plots they cover.
///
/// The first [Balance.unguardedFarmPlots] farm plots need no guards; each
/// plot past them needs [Balance.guardsPerFarmPlot] guard capacity. A farm
/// on a plot past what the guards cover still stands and is never damaged
/// or taken away: it rests, growing nothing, and starts growing again the
/// moment guards arrive (never for the time it rested). Guard capacity only
/// ever rises, so a plot once guarded stays guarded.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../content.dart';
import '../game_state.dart';
import 'districts.dart';

/// [town]'s guard capacity at [at]: the guards of each civic building at
/// its tier in service.
int guardCapacityAt(HallState town, DateTime at) {
  var guards = 0;
  for (final building in town.districts.buildings.values) {
    final type = building.civicType;
    if (type == null) continue;
    guards += CivicBuildingSpec.at(Balance.civicBuildings[type]!.guardsByTier, building.tierAt(at));
  }
  return guards;
}

/// How many farm plots (from plot 0) work at [at]: the unguarded ones and
/// as many more as the guards cover.
int guardedFarmPlots(HallState town, DateTime at) =>
    Balance.unguardedFarmPlots + guardCapacityAt(town, at) ~/ Balance.guardsPerFarmPlot;

/// Whether farmland plot [plotIndex] is guarded at [at].
bool farmPlotGuarded(HallState town, int plotIndex, DateTime at) =>
    plotIndex < guardedFarmPlots(town, at);

/// Whether the farm or orchard on [address] rests at [at] for want of
/// guards (false for an empty plot, a granary, or a guarded plot).
bool farmResting(HallState town, PlotAddress address, DateTime at) {
  final type = town.districts.buildingAt(address)?.farmType;
  if (type == null || !Balance.farmBuildings[type]!.growsFood) return false;
  return !farmPlotGuarded(town, address.plotIndex, at);
}

/// The instant farmland plot [plotIndex] became guarded, by the guard
/// buildings as they stand: [kAlwaysGuarded] for a plot guarded from the
/// start (or before any guard building changed), null for one not guarded
/// yet. Capacity changes only when a guard building finishes, so those are
/// the only instants to look at.
DateTime? farmPlotGuardedSince(HallState town, int plotIndex) {
  if (plotIndex < Balance.unguardedFarmPlots) return kAlwaysGuarded;
  final changes = <DateTime>[
    for (final building in town.districts.buildings.values)
      if (building.civicType case final type?
          when Balance.civicBuildings[type]!.guardsByTier.isNotEmpty)
        building.completesAt,
  ]..sort();
  if (farmPlotGuarded(town, plotIndex, kAlwaysGuarded)) return kAlwaysGuarded;
  for (final change in changes) {
    if (farmPlotGuarded(town, plotIndex, change)) return change;
  }
  return null;
}

/// An instant before any town existed: "guarded from the start".
final DateTime kAlwaysGuarded = DateTime.utc(2000);
