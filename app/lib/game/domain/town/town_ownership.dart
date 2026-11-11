/// Whose town is whose. Each Adventure adult owns their own town, a
/// neighbour of the others'. Until the one-time `TownsSplit` the household
/// shares a single town (the legacy shared hall); at the split that town
/// goes, whole, to the adult who built most of it, and every other adult's
/// town starts from [HallState.starter] plus the split's welcome grant.
///
/// The rules here are pure and order-independent: the projection folds
/// events in `(occurredAt, eventId)` order, so the earliest split stands on
/// every device and any later one (a second device's copy) is ignored. A
/// town event stamped before the split always applies to the shared town,
/// whichever order it arrived in.
///
/// Pure Dart, zero Flutter imports.
library;

import '../game_event.dart';
import '../game_state.dart';
import '../game_values.dart';

/// The split that stands: who kept the shared town, and what every other
/// adult's town started with.
class TownsSplitRecord {
  const TownsSplitRecord({
    required this.eventId,
    required this.ownerId,
    required this.welcome,
    required this.splitAt,
  });

  final String eventId;
  final String ownerId;
  final MaterialBundle welcome;
  final DateTime splitAt;

  /// The household day the towns became neighbours (the trade road opens).
  GameDay get day => GameDay.fromInstant(splitAt);

  @override
  bool operator ==(Object other) =>
      other is TownsSplitRecord &&
      other.eventId == eventId &&
      other.ownerId == ownerId &&
      other.welcome == welcome &&
      other.splitAt == splitAt;

  @override
  int get hashCode => Object.hash(eventId, ownerId, welcome, splitAt);
}

/// The household's town bookkeeping beside `GameState.towns`: the shared
/// town before the split, the split itself, and (before the split) how many
/// town commands each adult wrote, which decides who keeps the shared town.
class TownOwnership {
  const TownOwnership({
    required this.sharedHall,
    this.split,
    this.hallCommandCounts = const {},
  });

  /// Before any event: the starter town, shared.
  factory TownOwnership.initial() =>
      TownOwnership(sharedHall: HallState.starter());

  /// The household's one town until the split. Meaningless after it.
  final HallState sharedHall;

  /// The split that stands, or null while the town is still shared.
  final TownsSplitRecord? split;

  /// `PlotUnlocked`, `BuildingStarted` and `MaterialsCollected` events per
  /// actor, counted before the split.
  final Map<String, int> hallCommandCounts;

  bool get isSplit => split != null;

  /// [personId]'s town: the shared town before the split; after it, their
  /// own, or the starter town with the welcome grant if they have none yet.
  HallState townOf(String personId, Map<String, HallState> towns) {
    final standing = split;
    if (standing == null) return sharedHall;
    return towns[personId] ?? welcomeTown(standing.welcome);
  }

  /// One more town command by [actorId]; nothing changes once split.
  TownOwnership countHallCommand(String actorId) => isSplit
      ? this
      : TownOwnership(
          sharedHall: sharedHall,
          hallCommandCounts: Map.unmodifiable({
            ...hallCommandCounts,
            actorId: (hallCommandCounts[actorId] ?? 0) + 1,
          }),
        );

  TownOwnership withSharedHall(HallState hall) => TownOwnership(
        sharedHall: hall,
        split: split,
        hallCommandCounts: hallCommandCounts,
      );

  @override
  bool operator ==(Object other) =>
      other is TownOwnership &&
      other.split == split &&
      (split != null || other.sharedHall == sharedHall) &&
      _countsEqual(other.hallCommandCounts, hallCommandCounts);

  @override
  int get hashCode => Object.hash(split, hallCommandCounts.length);
}

/// A new neighbour's town: the starter town holding [welcome].
HallState welcomeTown(MaterialBundle welcome) =>
    HallState.starter().copyWith(materials: welcome);

/// Applies [event] to the town bookkeeping, or returns null when a split
/// already stands (a later or second-device split is ignored).
({TownOwnership ownership, Map<String, HallState> towns})? applyTownsSplit(
  TownOwnership ownership,
  Map<String, HallState> towns,
  TownsSplit event,
) {
  if (ownership.isSplit) return null;
  return (
    ownership: TownOwnership(
      sharedHall: ownership.sharedHall,
      split: TownsSplitRecord(
        eventId: event.eventId,
        ownerId: event.ownerId,
        welcome: event.welcome,
        splitAt: event.occurredAt,
      ),
    ),
    towns: Map.unmodifiable({...towns, event.ownerId: ownership.sharedHall}),
  );
}

/// Who keeps the shared town at the split: of [adventurerIds], the one with
/// the most town commands in [hallCommandCounts], ties to the smallest member
/// id; with no town activity at all, the smallest id. Null with no
/// Adventure adult.
String? townsSplitOwner(
  Map<String, int> hallCommandCounts,
  Iterable<String> adventurerIds,
) {
  final candidates = adventurerIds.toList()..sort();
  String? owner;
  var most = -1;
  for (final candidate in candidates) {
    final count = hallCommandCounts[candidate] ?? 0;
    if (count > most) {
      owner = candidate;
      most = count;
    }
  }
  return owner;
}

/// [personId]'s town as it will stand once [ownerId] keeps the shared town
/// of the unsplit [state] (for the engine run that writes the split).
HallState townAfterSplit(
  GameState state,
  String personId, {
  required String ownerId,
  required MaterialBundle welcome,
}) {
  if (state.townsSplit) return state.townOf(personId);
  return personId == ownerId
      ? state.ownership.sharedHall
      : welcomeTown(welcome);
}

bool _countsEqual(Map<String, int> first, Map<String, int> second) =>
    first.length == second.length &&
    first.entries.every((entry) => second[entry.key] == entry.value);
