/// The district catalogue ([kDistricts]): every district a town can own,
/// in the order a town grows into them, with the tier that opens it, its
/// price, its plots and the buildings allowed there; and the lookups from a
/// district or building key to this build's catalogue (a key a newer build
/// adds reads as null, so the projection can set it aside).
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../game_values.dart';

const String kOutpostDistrictId = 'outpost';
const String kFarmlandDistrictId = 'farmland';
const String kGuardPostDistrictId = 'guardPost';
const String kResidentialDistrictId = 'residential';
const String kParkDistrictId = 'park';
const String kMarketRowDistrictId = 'marketRow';
const String kCastleHillDistrictId = 'castleHill';

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
  DistrictSpec(
    id: kGuardPostDistrictId,
    requiredTier: TownTier.village,
    gemPrice: Balance.guardPostGemPrice,
    materialPrice: Balance.guardPostMaterialPrice,
    plotCount: Balance.guardPostPlotCount,
    buildingKeys: ['watchtower', 'barracks', 'wallSection'],
    tilesetKey: 'district.guardPost.ground',
  ),
  DistrictSpec(
    id: kResidentialDistrictId,
    requiredTier: TownTier.village,
    gemPrice: Balance.residentialGemPrice,
    materialPrice: Balance.residentialMaterialPrice,
    plotCount: Balance.residentialPlotCount,
    buildingKeys: ['cottage', 'rowhouse', 'well'],
    tilesetKey: 'district.residential.ground',
  ),
  DistrictSpec(
    id: kParkDistrictId,
    requiredTier: TownTier.town,
    gemPrice: Balance.parkGemPrice,
    materialPrice: Balance.parkMaterialPrice,
    plotCount: Balance.parkPlotCount,
    buildingKeys: ['garden', 'bandstand', 'fountain'],
    tilesetKey: 'district.park.ground',
  ),
  DistrictSpec(
    id: kMarketRowDistrictId,
    requiredTier: TownTier.town,
    gemPrice: Balance.marketRowGemPrice,
    materialPrice: Balance.marketRowMaterialPrice,
    plotCount: Balance.marketRowPlotCount,
    buildingKeys: ['stall', 'workshop', 'guildHall'],
    tilesetKey: 'district.marketRow.ground',
  ),
  // Castle Hill is never bought: it is listed as a teaser until the city,
  // and then the Castle rises there stage by stage (`castle.dart`).
  DistrictSpec(
    id: kCastleHillDistrictId,
    requiredTier: TownTier.city,
    plotCount: 0,
    buildingKeys: [],
    tilesetKey: 'district.castleHill.ground',
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

/// How many plots [district] has for a [tier] town: the farmland gains
/// fields at the town and the city ([Balance.farmlandPlotsByTier]); with no
/// tier, the district's base plot count.
int districtPlotCount(DistrictSpec district, [TownTier? tier]) {
  if (district.id != kFarmlandDistrictId || tier == null) return district.plotCount;
  return Balance.farmlandPlotsByTier[tier] ?? district.plotCount;
}

/// The most plots [district] ever has (at any tier): what the projection
/// accepts, so a field a later tier opened is never set aside.
int districtMaxPlotCount(DistrictSpec district) {
  var most = district.plotCount;
  if (district.id != kFarmlandDistrictId) return most;
  for (final count in Balance.farmlandPlotsByTier.values) {
    if (count > most) most = count;
  }
  return most;
}

/// The civic building named [key], or null for a key this build lacks.
CivicBuildingType? civicBuildingByKey(String key) {
  for (final type in CivicBuildingType.values) {
    if (type.name == key) return type;
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
