/// The town's read model for one district: what stands on each plot, who
/// lives in each house (the outpost), and what a tap on a cell means.
/// Derived from the game state and the household roster on every build;
/// never stored. Pure Dart.
library;

import '../decor/decor_state.dart' show Placement;
import '../game_state.dart';
import '../game_values.dart';
import '../hall_rules.dart';
import 'districts.dart';
import 'food.dart';
import 'town_layout.dart';

sealed class TownTarget {
  const TownTarget();
}

class PlotTarget extends TownTarget {
  const PlotTarget(this.plotIndex, {this.districtId = kOutpostDistrictId});
  final int plotIndex;

  /// The district the plot is in (the outpost's plots are the hall plots).
  final String districtId;

  @override
  bool operator ==(Object other) =>
      other is PlotTarget && other.plotIndex == plotIndex && other.districtId == districtId;

  @override
  int get hashCode => Object.hash(plotIndex, districtId);
}

class HouseTarget extends TownTarget {
  const HouseTarget(this.personId);
  final String personId;

  @override
  bool operator ==(Object other) => other is HouseTarget && other.personId == personId;

  @override
  int get hashCode => personId.hashCode;
}

class GateTarget extends TownTarget {
  const GateTarget();

  @override
  bool operator ==(Object other) => other is GateTarget;

  @override
  int get hashCode => 0;
}

/// One adult of the household, as the town needs them.
class TownAdult {
  const TownAdult({required this.memberId, required this.name, required this.inAdventure});
  final String memberId;
  final String name;
  final bool inAdventure;
}

class TownPlotView {
  const TownPlotView({
    required this.plotIndex,
    required this.origin,
    required this.unlocked,
    this.districtId = kOutpostDistrictId,
    this.buildingType,
    this.farmType,
    this.tier = 0,
    this.underConstruction = false,
    this.completesAt,
    this.readyToCollect = false,
  });

  final int plotIndex;
  final TownCell origin;
  final bool unlocked;
  final String districtId;

  /// What stands on an outpost plot.
  final BuildingType? buildingType;

  /// What stands on a farmland plot.
  final FarmBuildingType? farmType;
  final int tier;
  final bool underConstruction;
  final DateTime? completesAt;
  final bool readyToCollect;

  @override
  bool operator ==(Object other) =>
      other is TownPlotView &&
      other.plotIndex == plotIndex &&
      other.origin == origin &&
      other.unlocked == unlocked &&
      other.districtId == districtId &&
      other.buildingType == buildingType &&
      other.farmType == farmType &&
      other.tier == tier &&
      other.underConstruction == underConstruction &&
      other.completesAt == completesAt &&
      other.readyToCollect == readyToCollect;

  @override
  int get hashCode => Object.hash(
        plotIndex,
        origin,
        unlocked,
        districtId,
        buildingType,
        farmType,
        tier,
        underConstruction,
        completesAt,
        readyToCollect,
      );
}

class TownResident {
  const TownResident({
    required this.personId,
    required this.name,
    required this.inAdventure,
    required this.houseOrigin,
  });

  final String personId;
  final String name;

  /// False for a Standard-mode adult: drawn with the supply wagon, never
  /// named as missing or blamed (design rule 7).
  final bool inAdventure;
  final TownCell houseOrigin;

  @override
  bool operator ==(Object other) =>
      other is TownResident &&
      other.personId == personId &&
      other.name == name &&
      other.inAdventure == inAdventure &&
      other.houseOrigin == houseOrigin;

  @override
  int get hashCode => Object.hash(personId, name, inAdventure, houseOrigin);
}

class TownView {
  const TownView({
    required this.plots,
    required this.residents,
    this.layout = TownLayout.standard,
    this.dungeonOpen = false,
    this.townPlacements = const [],
    this.goalPictures = const {},
  });

  final List<TownPlotView> plots;
  final List<TownResident> residents;
  final TownLayout layout;

  /// The district this view draws.
  String get districtId => layout.districtId;

  /// A month-end ritual is waiting below the gate, so the gate glows.
  final bool dungeonOpen;

  /// Decorations and statues standing in the town, in a stable order.
  final List<Placement> townPlacements;

  /// questId → picture sha256 of the reached goals whose statues may show
  /// their own picture.
  final Map<String, String> goalPictures;

  /// The district [districtId] of the town [viewerId] sees: their own
  /// town's plots, with (in the outpost) the household's residents and town
  /// decorations. A district with no map yet draws the outpost.
  static TownView from(
    GameState game,
    String viewerId,
    List<TownAdult> adults,
    DateTime now, {
    String districtId = kOutpostDistrictId,
    bool dungeonOpen = false,
    Map<String, String> goalPictures = const {},
  }) {
    final activeDays = game.townActiveDaysOf(viewerId);
    final town = game.townOf(viewerId);
    final layout = TownLayout.forDistrict(districtId) ?? TownLayout.standard;
    if (layout != TownLayout.standard) {
      return TownView(
        layout: layout,
        plots: List.unmodifiable([
          for (var index = 0; index < layout.plotOrigins.length; index++)
            _districtPlotView(town, PlotAddress(layout.districtId, index), layout.plotOrigins[index], now, activeDays),
        ]),
        residents: const [],
      );
    }
    final plots = <TownPlotView>[
      for (var index = 0; index < layout.plotOrigins.length; index++)
        _plotView(town, index, layout.plotOrigins[index], now, activeDays),
    ];
    final residents = <TownResident>[
      for (var slot = 0; slot < adults.length && slot < layout.houseOrigins.length; slot++)
        TownResident(
          personId: adults[slot].memberId,
          name: adults[slot].name,
          inAdventure: adults[slot].inAdventure,
          houseOrigin: layout.houseOrigins[slot],
        ),
    ];
    return TownView(
      plots: List.unmodifiable(plots),
      residents: List.unmodifiable(residents),
      layout: layout,
      dungeonOpen: dungeonOpen,
      townPlacements: List.unmodifiable(
        game.decor.townPlacements..sort((first, second) => first.placementId.compareTo(second.placementId)),
      ),
      goalPictures: Map.unmodifiable(goalPictures),
    );
  }

  static TownPlotView _plotView(
    HallState hall,
    int index,
    TownCell origin,
    DateTime now,
    Set<GameDay> activeDays,
  ) {
    final plot = hall.plots[index];
    final building = plot?.building;
    final underConstruction = building != null && now.isBefore(building.completesAt);
    return TownPlotView(
      plotIndex: index,
      origin: origin,
      unlocked: plot != null,
      buildingType: building?.type,
      tier: building?.tier ?? 0,
      underConstruction: underConstruction,
      completesAt: building?.completesAt,
      readyToCollect:
          building != null &&
              !underConstruction &&
              !collectableNow(hall, index, now, activeDays: activeDays).isEmpty,
    );
  }

  static TownPlotView _districtPlotView(
    HallState town,
    PlotAddress address,
    TownCell origin,
    DateTime now,
    Set<GameDay> activeDays,
  ) {
    final building = town.districts.buildingAt(address);
    final underConstruction = building != null && !building.isCompleteAt(now);
    return TownPlotView(
      plotIndex: address.plotIndex,
      origin: origin,
      unlocked: plotIsOpen(town, address),
      districtId: address.districtId,
      farmType: building?.farmType,
      tier: building?.tier ?? 0,
      underConstruction: underConstruction,
      completesAt: building?.completesAt,
      readyToCollect: building != null &&
          !underConstruction &&
          uncollectedFood(town, address, now, activeDays: activeDays) > 0,
    );
  }

  static bool _covers(TownCell origin, TownCell cell) =>
      cell.column >= origin.column &&
      cell.column < origin.column + TownLayout.footprint &&
      cell.row >= origin.row &&
      cell.row < origin.row + TownLayout.footprint;

  /// Equal when it draws the same town, so the scene only rebuilds on a
  /// real change, not on every fresh read-model.
  @override
  bool operator ==(Object other) =>
      other is TownView &&
      other.layout == layout &&
      other.dungeonOpen == dungeonOpen &&
      _sameItems(other.plots, plots) &&
      _sameItems(other.residents, residents) &&
      _sameItems(other.townPlacements, townPlacements) &&
      _samePictures(other.goalPictures, goalPictures);

  @override
  int get hashCode => Object.hash(
        layout,
        dungeonOpen,
        Object.hashAll(plots),
        Object.hashAll(residents),
        Object.hashAll(townPlacements),
        Object.hashAll(goalPictures.entries.map((entry) => Object.hash(entry.key, entry.value))),
      );

  static bool _samePictures(Map<String, String> first, Map<String, String> second) {
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      if (second[entry.key] != entry.value) return false;
    }
    return true;
  }

  static bool _sameItems<T>(List<T> first, List<T> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  /// What a tap on [cell] means, or null for scenery.
  TownTarget? targetAt(TownCell cell) {
    if (layout.hasGate && cell == layout.gate) return const GateTarget();
    for (final plot in plots) {
      if (_covers(plot.origin, cell)) return PlotTarget(plot.plotIndex, districtId: plot.districtId);
    }
    for (final resident in residents) {
      if (_covers(resident.houseOrigin, cell)) return HouseTarget(resident.personId);
    }
    return null;
  }
}
