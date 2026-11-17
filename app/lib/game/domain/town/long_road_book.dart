/// The town book's long-road pages: one read model of a town's homes,
/// guards and the fields they cover, goods and workshop jobs, and the
/// Castle's progress, every number read through the rules' own functions
/// (`residents.dart`, `guards.dart`, `goods.dart`, `castle.dart`). Also
/// which districts a town can walk into. Display only.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../game_state.dart';
import '../game_values.dart';
import 'districts.dart';
import 'goods.dart';
import 'guards.dart';
import 'prosperity.dart' show nextTier;
import 'residents.dart';

/// Whether a [tier] [town] can open district [districtId]'s map: one it
/// owns, or Castle Hill once it is a city (never bought; the Castle rises
/// there).
bool districtVisitable(HallState town, TownTier tier, String districtId) =>
    town.districts.owns(districtId) || (districtId == kCastleHillDistrictId && tier == TownTier.city);

/// A town's homes, guards, goods and Castle at a glance.
class LongRoadBook {
  const LongRoadBook({
    required this.nextTier,
    required this.housing,
    required this.housingNeeded,
    required this.housed,
    required this.guards,
    required this.guardedFields,
    required this.fieldsOpen,
    required this.restingFarms,
    required this.goods,
    required this.workshops,
    required this.jobsWorking,
    required this.jobsDone,
    required this.castleOpen,
    required this.castleStagesDone,
    required this.castleBuilding,
    required this.castleStageEndsAt,
  });

  /// The tier the town grows into next (null for a city).
  final TownTier? nextTier;

  /// Residents the houses in service hold.
  final int housing;

  /// Homes the next tier needs (0 when it needs none).
  final int housingNeeded;
  final bool housed;

  /// Guard capacity, and how many farm fields work (the unguarded ones and
  /// as many more as the guards cover).
  final int guards;
  final int guardedFields;

  /// Farm fields the town's tier opens.
  final int fieldsOpen;

  /// Farms resting until guards watch their fields.
  final int restingFarms;

  /// Goods in the workshops' lofts.
  final GoodsBundle goods;

  /// Workshops in service, and their jobs at work or done.
  final int workshops;
  final int jobsWorking;
  final int jobsDone;

  /// The town is a city: the Castle may rise on Castle Hill.
  final bool castleOpen;
  final int castleStagesDone;

  /// A stage is rising, finishing at [castleStageEndsAt].
  final bool castleBuilding;
  final DateTime? castleStageEndsAt;

  /// The 1-based stage being raised or to begin next (past the last when
  /// the Castle is complete).
  int get castleNextStage => castleStagesDone + 1;

  bool get castleComplete => castleStagesDone >= Balance.castleStages.length;

  /// Whether the next tier needs homes at all.
  bool get nextTierNeedsHomes => housingNeeded > 0;
}

/// [personId]'s long-road book at [now].
LongRoadBook longRoadBook(GameState state, String personId, DateTime now) {
  final town = state.townOf(personId);
  final tier = state.person(personId).townTier;
  final next = nextTier(tier);
  final farmland = districtById(kFarmlandDistrictId)!;
  final jobs = town.goods.jobs.values;
  final castle = town.castle;
  final stagesDone = castle.stagesCompleteAt(now);
  final building = stagesDone < castle.stagesStarted;
  return LongRoadBook(
    nextTier: next,
    housing: housingAt(town, now),
    housingNeeded: next == null ? 0 : housingNeededFor(next),
    housed: next == null || housedFor(town, next, now),
    guards: guardCapacityAt(town, now),
    guardedFields: guardedFarmPlots(town, now),
    fieldsOpen: districtPlotCount(farmland, tier),
    restingFarms: [
      for (final address in town.districts.buildings.keys)
        if (farmResting(town, address, now)) address,
    ].length,
    goods: town.goods.stored,
    workshops: workshopsAt(town, now).length,
    jobsWorking: jobs.where((job) => !job.isDoneAt(now)).length,
    jobsDone: jobs.where((job) => job.isDoneAt(now)).length,
    castleOpen: tier == TownTier.city,
    castleStagesDone: stagesDone,
    castleBuilding: building,
    castleStageEndsAt: building ? castle.stages.last.completesAt : null,
  );
}
