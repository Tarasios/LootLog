/// A town's people: the residents its tier draws in plus everyone its
/// Residential Quarter houses, and the housing a town and a city need.
///
/// Population is the tier's base residents (`Balance.populationByTier`)
/// plus the housing of every house in service. The food a town eats follows
/// its population (`food.dart`). Growing into a town or a city needs houses
/// for the tier's people ([housingNeededFor]) as well as prosperity and
/// food; a town short of houses keeps everything and only waits.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../content.dart';
import '../game_state.dart';
import '../game_values.dart';

/// Residents [town]'s houses hold at [at]: the housing of each civic
/// building at its tier in service (an upgrade under way houses its old
/// tier's residents; a house still being built, none).
int housingAt(HallState town, DateTime at) {
  var housing = 0;
  for (final building in town.districts.buildings.values) {
    final type = building.civicType;
    if (type == null) continue;
    housing += CivicBuildingSpec.at(Balance.civicBuildings[type]!.housingByTier, building.tierAt(at));
  }
  return housing;
}

/// Everyone living in a [tier] [town] at [at]: the tier's residents and
/// the housed.
int populationAt(HallState town, TownTier tier, DateTime at) =>
    Balance.populationByTier[tier]! + housingAt(town, at);

/// Food a [tier] [town] eats a day at [at]: its population times what each
/// resident of the tier eats.
int foodNeedAt(HallState town, TownTier tier, DateTime at) =>
    populationAt(town, tier, at) * Balance.foodPerResident[tier]!;

/// Housing a town needs to grow into [tier] (0 for a tier that needs none).
int housingNeededFor(TownTier tier) => Balance.housingForTier[tier] ?? 0;

/// Whether [town]'s houses in service at [at] hold the people [tier] needs.
bool housedFor(HallState town, TownTier tier, DateTime at) =>
    housingAt(town, at) >= housingNeededFor(tier);
