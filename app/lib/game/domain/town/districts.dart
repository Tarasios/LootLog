/// A town's districts: the outpost every town starts with, and the
/// districts bought as it grows. Districts are data ([kDistricts]) so a
/// later stage adds one without a new code path: its id, the tier that
/// opens it, its price, its plot count, the buildings allowed there and its
/// tileset key.
///
/// Plots are addressed by `(districtId, plotIndex)` ([PlotAddress]). The
/// outpost's plots are the hall plots of stage 1 (`HallState.plots`), and
/// every older event, which names no district, means the outpost. Other
/// districts' buildings live in [TownDistricts] and are built through
/// `DistrictBuildingStarted`, which names its district and building by key,
/// so a building or district a newer build adds is set aside here rather
/// than hiding the whole event.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../game_event.dart';
import '../game_state.dart';
import '../game_values.dart';

const String kOutpostDistrictId = 'outpost';
const String kFarmlandDistrictId = 'farmland';

/// One district in the catalogue.
class DistrictSpec {
  const DistrictSpec({
    required this.id,
    required this.requiredTier,
    required this.plotCount,
    required this.buildingKeys,
    required this.tilesetKey,
    this.gemPrice = 0,
    this.materialPrice = const {},
    this.purchasable = true,
  });

  final String id;

  /// The town tier at which it can be bought.
  final TownTier requiredTier;
  final int gemPrice;
  final Map<MaterialKind, int> materialPrice;
  final int plotCount;

  /// The building keys allowed on its plots ([BuildingType] names in the
  /// outpost, [FarmBuildingType] names in the farmland).
  final List<String> buildingKeys;

  /// The asset key of its ground tiles.
  final String tilesetKey;

  /// False for a district listed as a teaser: shown with its tier, not yet
  /// for sale.
  final bool purchasable;

  /// Owned by every town from the start (the outpost).
  bool get ownedFromStart => id == kOutpostDistrictId;

  /// What buying it costs.
  Loot get price => Loot(gems: gemPrice, materials: MaterialBundle(materialPrice));

  bool allows(String buildingKey) => buildingKeys.contains(buildingKey);
}

/// Every district, in the order a town grows into them.
const List<DistrictSpec> kDistricts = [
  DistrictSpec(
    id: kOutpostDistrictId,
    requiredTier: TownTier.outpost,
    plotCount: Balance.maxPlots,
    buildingKeys: [
      'centralHall', 'scribesDesk', 'storehouse', 'forge', 'vault', 'lumberyard',
      'quarry', 'mine', 'herbGarden', 'huntersLodge', 'arcaneWell',
    ],
    tilesetKey: 'district.outpost.ground',
  ),
  DistrictSpec(
    id: kFarmlandDistrictId,
    requiredTier: TownTier.hamlet,
    gemPrice: Balance.farmlandGemPrice,
    materialPrice: Balance.farmlandMaterialPrice,
    plotCount: Balance.farmlandPlotCount,
    buildingKeys: ['farm', 'orchard', 'granary'],
    tilesetKey: 'district.farmland.ground',
  ),
  // Teasers: listed with the tier that will open them; they arrive in a
  // later stage with their buildings and prices.
  DistrictSpec(
    id: 'guardPost',
    requiredTier: TownTier.village,
    plotCount: 0,
    buildingKeys: [],
    tilesetKey: 'district.guardPost.ground',
    purchasable: false,
  ),
  DistrictSpec(
    id: 'residential',
    requiredTier: TownTier.village,
    plotCount: 0,
    buildingKeys: [],
    tilesetKey: 'district.residential.ground',
    purchasable: false,
  ),
  DistrictSpec(
    id: 'park',
    requiredTier: TownTier.town,
    plotCount: 0,
    buildingKeys: [],
    tilesetKey: 'district.park.ground',
    purchasable: false,
  ),
  DistrictSpec(
    id: 'marketRow',
    requiredTier: TownTier.town,
    plotCount: 0,
    buildingKeys: [],
    tilesetKey: 'district.marketRow.ground',
    purchasable: false,
  ),
];

/// The catalogue entry for [id], or null for a district this build lacks.
DistrictSpec? districtById(String id) {
  for (final district in kDistricts) {
    if (district.id == id) return district;
  }
  return null;
}

/// The farm building named [key], or null for a key this build lacks.
FarmBuildingType? farmBuildingByKey(String key) {
  for (final type in FarmBuildingType.values) {
    if (type.name == key) return type;
  }
  return null;
}

/// A plot in a district.
class PlotAddress {
  const PlotAddress(this.districtId, this.plotIndex);

  final String districtId;
  final int plotIndex;

  /// The id production and harvests are kept under.
  String get buildingId => '$districtId-$plotIndex';

  @override
  bool operator ==(Object other) =>
      other is PlotAddress && other.districtId == districtId && other.plotIndex == plotIndex;

  @override
  int get hashCode => Object.hash(districtId, plotIndex);

  @override
  String toString() => 'PlotAddress($districtId, $plotIndex)';
}

/// A building on a district plot beyond the outpost.
class DistrictBuildingState {
  const DistrictBuildingState({
    required this.key,
    required this.tier,
    required this.startedAt,
    required this.completesAt,
  });

  final String key;
  final int tier;
  final DateTime startedAt;
  final DateTime completesAt;

  /// The farm building it is, or null when it is not one.
  FarmBuildingType? get farmType => farmBuildingByKey(key);

  bool isCompleteAt(DateTime at) => !at.isBefore(completesAt);

  /// The tier in service at [at]: the previous tier while an upgrade is
  /// under way (0 while first being built).
  int tierAt(DateTime at) => isCompleteAt(at) ? tier : tier - 1;

  @override
  bool operator ==(Object other) =>
      other is DistrictBuildingState &&
      other.key == key &&
      other.tier == tier &&
      other.startedAt == startedAt &&
      other.completesAt == completesAt;

  @override
  int get hashCode => Object.hash(key, tier, startedAt, completesAt);
}

/// The districts a town owns beyond the outpost, and their buildings.
class TownDistricts {
  const TownDistricts({this.purchased = const {}, this.buildings = const {}});

  static const TownDistricts none = TownDistricts();

  /// Bought district ids (the outpost is owned from the start and is never
  /// listed).
  final Set<String> purchased;

  /// Buildings on district plots beyond the outpost.
  final Map<PlotAddress, DistrictBuildingState> buildings;

  bool owns(String districtId) =>
      districtId == kOutpostDistrictId || purchased.contains(districtId);

  DistrictBuildingState? buildingAt(PlotAddress address) => buildings[address];

  /// The highest tier in service at [at] of any [type] building (0 if none).
  int completedFarmTier(FarmBuildingType type, DateTime at) {
    var best = 0;
    for (final building in buildings.values) {
      if (building.farmType != type) continue;
      final tier = building.tierAt(at);
      if (tier > best) best = tier;
    }
    return best;
  }

  /// Every district building's tier in service at [at], summed.
  int completedTiersAt(DateTime at) =>
      buildings.values.fold(0, (sum, building) => sum + building.tierAt(at));

  TownDistricts copyWith({
    Set<String>? purchased,
    Map<PlotAddress, DistrictBuildingState>? buildings,
  }) =>
      TownDistricts(
        purchased: purchased ?? this.purchased,
        buildings: buildings ?? this.buildings,
      );

  @override
  bool operator ==(Object other) =>
      other is TownDistricts &&
      other.purchased.length == purchased.length &&
      other.purchased.containsAll(purchased) &&
      other.buildings.length == buildings.length &&
      buildings.entries.every((entry) => other.buildings[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(purchased.length, buildings.length);
}

/// Whether [address] is a plot [town] can build on: an unlocked outpost
/// plot, or any plot of a district it owns.
bool plotIsOpen(HallState town, PlotAddress address) {
  if (address.districtId == kOutpostDistrictId) {
    return town.plots.containsKey(address.plotIndex);
  }
  final district = districtById(address.districtId);
  return district != null &&
      town.districts.owns(address.districtId) &&
      address.plotIndex >= 0 &&
      address.plotIndex < district.plotCount;
}

/// [town]'s districts after [purchase], or why it changes nothing: a
/// district this build lacks (or a teaser) is set aside, and one already
/// owned is not bought (or charged) twice.
({TownDistricts? districts, GameWarningCode? warning}) applyDistrictPurchase(
    HallState town, DistrictPurchased purchase) {
  final district = districtById(purchase.districtId);
  if (district == null || !district.purchasable) {
    return (districts: null, warning: GameWarningCode.unknownDistrict);
  }
  if (town.districts.owns(district.id)) {
    return (districts: null, warning: GameWarningCode.duplicateDistrict);
  }
  return (
    districts: town.districts.copyWith(
        purchased: Set.unmodifiable({...town.districts.purchased, district.id})),
    warning: null,
  );
}

/// [town]'s districts after [started], or why it changes nothing (and is
/// not charged): a district or building this build lacks, a district the
/// town does not own, a plot off the district, another building on the
/// plot, or a tier that does not follow from the plot (a repeat, or a stale
/// upgrade from another device).
({TownDistricts? districts, GameWarningCode? warning}) applyDistrictBuilding(
    HallState town, DistrictBuildingStarted started) {
  final district = districtById(started.districtId);
  if (district == null ||
      district.ownedFromStart ||
      !district.allows(started.buildingKey) ||
      farmBuildingByKey(started.buildingKey) == null) {
    return (districts: null, warning: GameWarningCode.unknownDistrict);
  }
  if (!town.districts.owns(district.id)) {
    return (districts: null, warning: GameWarningCode.districtNotOwned);
  }
  if (started.plotIndex < 0 || started.plotIndex >= district.plotCount) {
    return (districts: null, warning: GameWarningCode.plotLocked);
  }
  final address = PlotAddress(district.id, started.plotIndex);
  final existing = town.districts.buildingAt(address);
  if (existing != null && existing.key != started.buildingKey) {
    return (districts: null, warning: GameWarningCode.plotOccupied);
  }
  final standingTier = existing?.tier ?? 0;
  if (standingTier >= started.tier) {
    return (districts: null, warning: GameWarningCode.duplicateBuild);
  }
  if (started.tier != standingTier + 1) {
    return (districts: null, warning: GameWarningCode.unknownBuilding);
  }
  return (
    districts: town.districts.copyWith(
      buildings: Map.unmodifiable({
        ...town.districts.buildings,
        address: DistrictBuildingState(
          key: started.buildingKey,
          tier: started.tier,
          startedAt: started.occurredAt,
          completesAt: started.completesAt,
        ),
      }),
    ),
    warning: null,
  );
}
