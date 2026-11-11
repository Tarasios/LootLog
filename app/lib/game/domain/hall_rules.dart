/// Read-side rules of the guild hall that both the commands and the UI need:
/// what a building has produced, what fits in the Storehouse, how high a
/// building may go. Pure functions of the [HallState] and an instant.
///
/// Production follows the working shift: on a household day the town's own
/// adult showed up (`GameState.townActiveDaysOf`) the crews work the whole
/// day; on any other day only the first [Balance.shortShiftHours]. Days are calendar days in
/// the household timezone ([GameDay]), never the device's local time.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../domain/time.dart';
import '../config/balance.dart';
import 'content.dart';
import 'game_state.dart';
import 'game_values.dart';

/// Minutes of [from, to) a crew actually worked, given the days the town's
/// adult showed up ([activeDays]). Each household day it touches contributes its
/// overlap with that day's shift: the whole day when active, the first
/// [Balance.shortShiftHours] otherwise.
int workedMinutes(DateTime from, DateTime to, Set<GameDay> activeDays) {
  if (!to.isAfter(from)) return 0;
  var worked = Duration.zero;
  for (var day = GameDay.fromInstant(from);; day = day.next()) {
    final dayStart = _dayStartUtc(day);
    if (!dayStart.isBefore(to)) break;
    final nextDayStart = _dayStartUtc(day.next());
    final shiftHours = activeDays.contains(day)
        ? Balance.fullShiftHours
        : Balance.shortShiftHours;
    final shiftEnd = shiftHours >= Duration.hoursPerDay
        ? nextDayStart
        : _earlier(dayStart.add(Duration(hours: shiftHours)), nextDayStart);
    final overlapStart = _later(from, dayStart);
    final overlapEnd = _earlier(to, shiftEnd);
    if (overlapEnd.isAfter(overlapStart)) {
      worked += overlapEnd.difference(overlapStart);
    }
  }
  return worked.inMinutes;
}

/// What the building on [plotIndex] has produced since it was last collected
/// (or since it was built), as of [now], before any Storehouse cap. Empty for
/// an empty plot or a building that produces nothing. Only the minutes the
/// crew worked count (see [workedMinutes]).
///
/// While an upgrade is under way the building keeps producing at its old
/// tier; from the moment it completes, at the new one.
MaterialBundle uncollectedProduction(
  HallState hall,
  int plotIndex,
  DateTime now, {
  required Set<GameDay> activeDays,
}) {
  final producer = _producerOn(hall, plotIndex);
  if (producer == null) return const MaterialBundle.empty();
  final (:building, :spec, :from) = producer;
  if (!now.isAfter(from)) return const MaterialBundle.empty();

  final completesAt = building.completesAt;
  final oldTierEnd = now.isBefore(completesAt) ? now : completesAt;
  final oldTierMinutes = workedMinutes(from, oldTierEnd, activeDays);
  final newTierStart = from.isAfter(completesAt) ? from : completesAt;
  final newTierMinutes = workedMinutes(newTierStart, now, activeDays);

  int rate(List<int> rates, int tier) => tier < 1 ? 0 : rates[tier - 1];
  return MaterialBundle({
    for (final e in spec.productionPerHour.entries)
      e.key: (rate(e.value, building.tier - 1) * oldTierMinutes +
              rate(e.value, building.tier) * newTierMinutes) ~/
          60,
  });
}

/// How the current stretch since the last collection was worked, for the UI:
/// the minutes the crew worked against every minute that has passed. Both
/// zero for an empty plot or a building that produces nothing.
({int workedMinutes, int possibleMinutes}) shiftSummary(
  HallState hall,
  int plotIndex,
  DateTime now, {
  required Set<GameDay> activeDays,
}) {
  final producer = _producerOn(hall, plotIndex);
  if (producer == null || !now.isAfter(producer.from)) {
    return (workedMinutes: 0, possibleMinutes: 0);
  }
  return (
    workedMinutes: workedMinutes(producer.from, now, activeDays),
    possibleMinutes: now.difference(producer.from).inMinutes,
  );
}

/// When [plotIndex]'s uncollected stretch began (its last collection, or
/// its first completion), or null for an empty plot or a building that
/// produces nothing. Read-only, for the town's "while you were away" note.
DateTime? producerStretchStart(HallState hall, int plotIndex) =>
    _producerOn(hall, plotIndex)?.from;

/// The producer on [plotIndex] and the instant its uncollected stretch
/// starts, or null for an empty plot or a building that produces nothing.
({BuildingState building, BuildingSpec spec, DateTime from})? _producerOn(
    HallState hall, int plotIndex) {
  final plot = hall.plots[plotIndex];
  final building = plot?.building;
  if (plot == null || building == null) return null;
  final spec = Balance.buildings[building.type]!;
  if (!spec.isProducer) return null;
  // A never-collected building produces from its first completion. Upgrades
  // bank production first, so a never-collected building is still tier 1
  // (its startedAt is the fallback for a race between devices).
  final from = hall.lastCollectedAt[plot.buildingId] ??
      (building.tier == 1 ? building.completesAt : building.startedAt);
  return (building: building, spec: spec, from: from);
}

/// The instant (UTC) [day] starts: household midnight. The offset is read
/// half a day earlier, as [Month.startInstantUtc] does, so a midnight next to
/// a daylight-saving change uses the offset in force at that midnight.
DateTime _dayStartUtc(GameDay day) {
  final midnightAsUtc = DateTime.utc(day.year, day.month, day.day);
  final offset =
      vancouverUtcOffset(midnightAsUtc.subtract(const Duration(hours: 12)));
  return midnightAsUtc.subtract(offset);
}

DateTime _earlier(DateTime first, DateTime second) =>
    first.isBefore(second) ? first : second;

DateTime _later(DateTime first, DateTime second) =>
    first.isAfter(second) ? first : second;

/// The part of [wanted] the town has room for at [now]: each capped kind is
/// limited to the Storehouse capacity minus what the town holds.
MaterialBundle fitInStorehouse(HallState hall, MaterialBundle wanted, DateTime now) {
  final capacity = hall.storageCapacityAt(now);
  return MaterialBundle({
    for (final e in wanted.amounts.entries)
      e.key: Balance.uncappedMaterials.contains(e.key)
          ? e.value
          : _min(e.value, _max(0, capacity - hall.materials[e.key])),
  });
}

/// What collecting [plotIndex] at [now] would bank, given the days the
/// town's adult showed up ([activeDays]).
MaterialBundle collectableNow(
  HallState hall,
  int plotIndex,
  DateTime now, {
  required Set<GameDay> activeDays,
}) =>
    fitInStorehouse(
        hall,
        uncollectedProduction(hall, plotIndex, now, activeDays: activeDays),
        now);

/// The highest tier [type] may be built to at [now]: [Balance.maxBuildingTier]
/// for the Central Hall itself; for everything else the Central Hall's
/// completed tier (or [Balance.maxTierWithoutCentralHall] without one).
int maxTierAllowed(HallState hall, BuildingType type, DateTime now) {
  if (type == BuildingType.centralHall) return Balance.maxBuildingTier;
  return maxTierUnderCentralHall(hall, now);
}

/// The highest tier any building other than the Central Hall may reach in
/// [hall] at [now] (outpost buildings and every district's buildings alike):
/// the Central Hall's completed tier, or [Balance.maxTierWithoutCentralHall]
/// before it rises that far.
int maxTierUnderCentralHall(HallState hall, DateTime now) {
  final hallTier = hall.completedTier(BuildingType.centralHall, now);
  return _min(Balance.maxBuildingTier,
      _max(Balance.maxTierWithoutCentralHall, hallTier));
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;
