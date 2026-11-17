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
/// `DistrictBuildingStarted` (farmland) or `CivicBuildingStarted` (the
/// civic quarters), which name their district and building by key, so a
/// building or district a newer build adds is set aside here rather than
/// hiding the whole event. The catalogue itself is `district_catalog.dart`.
///
/// Pure Dart, zero Flutter imports.
library;

import '../game_event.dart';
import '../game_state.dart';
import '../game_values.dart';
import 'district_catalog.dart';

export 'district_catalog.dart';

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

  /// The civic building it is, or null when it is not one.
  CivicBuildingType? get civicType => civicBuildingByKey(key);

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
  const TownDistricts({this.purchasedAt = const {}, this.buildings = const {}});

  static const TownDistricts none = TownDistricts();

  /// When each bought district was bought (the outpost is owned from the
  /// start and is never listed). The earliest purchase stands.
  final Map<String, DateTime> purchasedAt;

  /// Bought district ids.
  Iterable<String> get purchased => purchasedAt.keys;

  /// Buildings on district plots beyond the outpost.
  final Map<PlotAddress, DistrictBuildingState> buildings;

  bool owns(String districtId) =>
      districtId == kOutpostDistrictId || purchasedAt.containsKey(districtId);

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

  /// The highest tier in service at [at] of any [type] building (0 if none).
  int completedCivicTier(CivicBuildingType type, DateTime at) {
    var best = 0;
    for (final building in buildings.values) {
      if (building.civicType != type) continue;
      final tier = building.tierAt(at);
      if (tier > best) best = tier;
    }
    return best;
  }

  TownDistricts copyWith({
    Map<String, DateTime>? purchasedAt,
    Map<PlotAddress, DistrictBuildingState>? buildings,
  }) =>
      TownDistricts(
        purchasedAt: purchasedAt ?? this.purchasedAt,
        buildings: buildings ?? this.buildings,
      );

  @override
  bool operator ==(Object other) =>
      other is TownDistricts &&
      other.purchasedAt.length == purchasedAt.length &&
      purchasedAt.entries.every((entry) => other.purchasedAt[entry.key] == entry.value) &&
      other.buildings.length == buildings.length &&
      buildings.entries.every((entry) => other.buildings[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(purchasedAt.length, buildings.length);
}

/// Whether [address] is a plot [town] can build on: an unlocked outpost
/// plot, or any plot of a district it owns (as many as a [tier] town has;
/// with no tier, the district's base plots).
bool plotIsOpen(HallState town, PlotAddress address, [TownTier? tier]) {
  if (address.districtId == kOutpostDistrictId) {
    return town.plots.containsKey(address.plotIndex);
  }
  final district = districtById(address.districtId);
  return district != null &&
      town.districts.owns(address.districtId) &&
      address.plotIndex >= 0 &&
      address.plotIndex < districtPlotCount(district, tier);
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
        purchasedAt: Map.unmodifiable(
            {...town.districts.purchasedAt, district.id: purchase.occurredAt})),
    warning: null,
  );
}

/// [town]'s districts after [started] (a farmland building), or why it
/// changes nothing (and is not charged); see [placeDistrictBuilding].
({TownDistricts? districts, GameWarningCode? warning}) applyDistrictBuilding(
        HallState town, DistrictBuildingStarted started) =>
    placeDistrictBuilding(
      town,
      districtId: started.districtId,
      plotIndex: started.plotIndex,
      buildingKey: started.buildingKey,
      tier: started.tier,
      startedAt: started.occurredAt,
      completesAt: started.completesAt,
      knownKey: (key) => farmBuildingByKey(key) != null,
    );

/// [town]'s districts with [buildingKey] at [tier] on [plotIndex] of
/// [districtId], or why it changes nothing (and is not charged): a district
/// or building this build lacks (or one [knownKey] rejects), a district the
/// town does not own, a plot off the district, another building on the
/// plot, or a tier that does not follow from the plot (a repeat, or a stale
/// upgrade from another device).
({TownDistricts? districts, GameWarningCode? warning}) placeDistrictBuilding(
  HallState town, {
  required String districtId,
  required int plotIndex,
  required String buildingKey,
  required int tier,
  required DateTime startedAt,
  required DateTime completesAt,
  required bool Function(String key) knownKey,
}) {
  final district = districtById(districtId);
  if (district == null ||
      district.ownedFromStart ||
      !district.allows(buildingKey) ||
      !knownKey(buildingKey)) {
    return (districts: null, warning: GameWarningCode.unknownDistrict);
  }
  if (!town.districts.owns(district.id)) {
    return (districts: null, warning: GameWarningCode.districtNotOwned);
  }
  if (plotIndex < 0 || plotIndex >= districtMaxPlotCount(district)) {
    return (districts: null, warning: GameWarningCode.plotLocked);
  }
  final address = PlotAddress(district.id, plotIndex);
  final existing = town.districts.buildingAt(address);
  if (existing != null && existing.key != buildingKey) {
    return (districts: null, warning: GameWarningCode.plotOccupied);
  }
  final standingTier = existing?.tier ?? 0;
  if (standingTier >= tier) {
    return (districts: null, warning: GameWarningCode.duplicateBuild);
  }
  if (tier != standingTier + 1) {
    return (districts: null, warning: GameWarningCode.unknownBuilding);
  }
  return (
    districts: town.districts.copyWith(
      buildings: Map.unmodifiable({
        ...town.districts.buildings,
        address: DistrictBuildingState(
          key: buildingKey,
          tier: tier,
          startedAt: startedAt,
          completesAt: completesAt,
        ),
      }),
    ),
    warning: null,
  );
}
