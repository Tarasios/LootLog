/// The decisions behind the district and farm commands: buying a district,
/// building or upgrading a farm building, and harvesting food. Each checks
/// the actor's own town and settles every time-dependent amount now, so the
/// command only has to write the event (`GameCommands.buyDistrict`,
/// `startFarmBuilding`, `harvestFood`).
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../commands/game_commands.dart' show GameRejection;
import '../game_state.dart';
import '../game_values.dart';
import '../hall_rules.dart';
import 'districts.dart';
import 'food.dart';

/// Whether [actorId] may buy [districtId] now, and what it costs.
({GameRejection? rejection, Loot cost}) planBuyDistrict(
    GameState state, String actorId, String districtId) {
  ({GameRejection? rejection, Loot cost}) refuse(GameRejection why) =>
      (rejection: why, cost: Loot.none);
  final district = districtById(districtId);
  if (district == null) return refuse(GameRejection.unknownDistrict);
  final town = state.townOf(actorId);
  if (town.districts.owns(districtId)) return refuse(GameRejection.districtAlreadyOwned);
  if (!district.purchasable) return refuse(GameRejection.districtNotOpenYet);
  final person = state.person(actorId);
  if (person.townTier.index < district.requiredTier.index) {
    return refuse(GameRejection.townTierTooLow);
  }
  final cost = district.price;
  if (person.gems < cost.gems) return refuse(GameRejection.notEnoughGems);
  if (!town.materials.covers(cost.materials)) return refuse(GameRejection.notEnoughMaterials);
  return (rejection: null, cost: cost);
}

/// Whether [actorId] may build [type] on farmland plot [plotIndex] (tier 1
/// on an empty plot, or the next tier of the same building), and the tier,
/// its cost and the food the upgrade banks first.
({GameRejection? rejection, int tier, Loot cost, int bank}) planFarmBuilding(
  GameState state,
  String actorId,
  int plotIndex,
  FarmBuildingType type,
  DateTime now,
) {
  ({GameRejection? rejection, int tier, Loot cost, int bank}) refuse(GameRejection why) =>
      (rejection: why, tier: 0, cost: Loot.none, bank: 0);
  final town = state.townOf(actorId);
  final farmland = districtById(kFarmlandDistrictId)!;
  if (!town.districts.owns(kFarmlandDistrictId)) return refuse(GameRejection.districtNotOwned);
  if (plotIndex < 0 || plotIndex >= farmland.plotCount) return refuse(GameRejection.invalidPlot);
  final address = PlotAddress(kFarmlandDistrictId, plotIndex);
  final existing = town.districts.buildingAt(address);
  final int tier;
  if (existing == null) {
    if (type == FarmBuildingType.granary &&
        town.districts.buildings.values.any((b) => b.farmType == FarmBuildingType.granary)) {
      return refuse(GameRejection.buildingAlreadyInHall);
    }
    tier = 1;
  } else {
    if (existing.farmType != type) return refuse(GameRejection.plotOccupied);
    if (!existing.isCompleteAt(now)) return refuse(GameRejection.underConstruction);
    tier = existing.tier + 1;
    if (tier > Balance.maxBuildingTier) return refuse(GameRejection.maxTierReached);
  }
  // Farm buildings follow the Central Hall like every non-hall building.
  if (tier > maxTierAllowed(town, BuildingType.storehouse, now)) {
    return refuse(GameRejection.needsCentralHall);
  }
  final bank = existing == null
      ? 0
      : harvestableFood(town, address, now, activeDays: state.townActiveDaysOf(actorId));
  final cost = Balance.farmBuildingCost(type, tier);
  if (state.person(actorId).gems < cost.gems) return refuse(GameRejection.notEnoughGems);
  if (!town.materials.covers(cost.materials)) return refuse(GameRejection.notEnoughMaterials);
  return (rejection: null, tier: tier, cost: cost, bank: bank);
}

/// What harvesting farmland plot [plotIndex] banks now, or why nothing.
({GameRejection? rejection, int amount}) planHarvest(
    GameState state, String actorId, int plotIndex, DateTime now) {
  ({GameRejection? rejection, int amount}) refuse(GameRejection why) =>
      (rejection: why, amount: 0);
  final town = state.townOf(actorId);
  if (!town.districts.owns(kFarmlandDistrictId)) return refuse(GameRejection.districtNotOwned);
  final address = PlotAddress(kFarmlandDistrictId, plotIndex);
  final type = town.districts.buildingAt(address)?.farmType;
  if (type == null) return refuse(GameRejection.noBuilding);
  if (!Balance.farmBuildings[type]!.growsFood) return refuse(GameRejection.notAProducer);
  final activeDays = state.townActiveDaysOf(actorId);
  if (uncollectedFood(town, address, now, activeDays: activeDays) <= 0) {
    return refuse(GameRejection.nothingToCollect);
  }
  final amount = harvestableFood(town, address, now, activeDays: activeDays);
  if (amount <= 0) return refuse(GameRejection.granaryFull);
  return (rejection: null, amount: amount);
}
