/// The civic quarters: the Guard Post, Residential Quarter, Park and Market
/// Row, and the buildings that stand there (watchtowers and barracks,
/// cottages and rowhouses, gardens and a bandstand, stalls and workshops).
///
/// Building one is a decision ([planCivicBuilding]) the command turns into
/// a `CivicBuildingStarted`; the projection applies it with
/// [applyCivicBuilding], which sets aside a building this build does not
/// know, one on a district the town does not own, or a stale copy of an
/// upgrade, charging nothing. What the buildings add lives beside the rule
/// that reads it: housing in `residents.dart`, guards in `guards.dart`, the
/// market trade in `market.dart`, refining in `goods.dart`, and the extra
/// prosperity of the park and the guild hall here ([civicProsperityAt]).
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../commands/game_commands.dart' show GameRejection;
import '../content.dart';
import '../game_event.dart';
import '../game_state.dart';
import '../game_values.dart';
import '../hall_rules.dart';
import 'districts.dart';

/// Whether [actorId] may build [type] on plot [plotIndex] of [districtId]
/// now (tier 1 on an empty plot, or the next tier of the same building),
/// and the tier and its cost.
({GameRejection? rejection, int tier, Loot cost}) planCivicBuilding(
  GameState state,
  String actorId,
  String districtId,
  int plotIndex,
  CivicBuildingType type,
  DateTime now,
) {
  ({GameRejection? rejection, int tier, Loot cost}) refuse(GameRejection why) =>
      (rejection: why, tier: 0, cost: Loot.none);
  final district = districtById(districtId);
  if (district == null) return refuse(GameRejection.unknownDistrict);
  final spec = Balance.civicBuildings[type]!;
  if (spec.districtId != districtId) return refuse(GameRejection.wrongDistrict);
  final town = state.townOf(actorId);
  if (!town.districts.owns(districtId)) return refuse(GameRejection.districtNotOwned);
  if (plotIndex < 0 || plotIndex >= district.plotCount) return refuse(GameRejection.invalidPlot);
  final existing = town.districts.buildingAt(PlotAddress(districtId, plotIndex));
  final int tier;
  if (existing == null) {
    if (spec.unique && town.districts.buildings.values.any((b) => b.civicType == type)) {
      return refuse(GameRejection.buildingAlreadyInHall);
    }
    tier = 1;
  } else {
    if (existing.civicType != type) return refuse(GameRejection.plotOccupied);
    if (!existing.isCompleteAt(now)) return refuse(GameRejection.underConstruction);
    tier = existing.tier + 1;
    if (tier > Balance.maxBuildingTier) return refuse(GameRejection.maxTierReached);
  }
  // Civic buildings follow the Central Hall like every other building.
  if (tier > maxTierUnderCentralHall(town, now)) return refuse(GameRejection.needsCentralHall);
  final cost = Balance.civicBuildingCost(type, tier).cost;
  if (state.person(actorId).gems < cost.gems) return refuse(GameRejection.notEnoughGems);
  if (!town.materials.covers(cost.materials)) return refuse(GameRejection.notEnoughMaterials);
  return (rejection: null, tier: tier, cost: cost);
}

/// [town]'s districts after [started], or why it changes nothing (and is
/// not charged): see `placeDistrictBuilding`. A civic building named on a
/// district that does not list it (or a farm building) is set aside.
({TownDistricts? districts, GameWarningCode? warning}) applyCivicBuilding(
        HallState town, CivicBuildingStarted started) =>
    placeDistrictBuilding(
      town,
      districtId: started.districtId,
      plotIndex: started.plotIndex,
      buildingKey: started.buildingKey,
      tier: started.tier,
      startedAt: started.occurredAt,
      completesAt: started.completesAt,
      knownKey: (key) => civicBuildingByKey(key) != null,
    );

/// The prosperity [town]'s civic buildings add at [at] beyond the usual
/// amount per building tier: the park's buildings and the guild hall, each
/// at its tier in service.
int civicProsperityAt(HallState town, DateTime at) {
  var prosperity = 0;
  for (final building in town.districts.buildings.values) {
    final type = building.civicType;
    if (type == null) continue;
    prosperity +=
        CivicBuildingSpec.at(Balance.civicBuildings[type]!.prosperityByTier, building.tierAt(at));
  }
  return prosperity;
}
