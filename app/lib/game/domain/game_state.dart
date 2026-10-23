/// The guild-hall [GameState]: a deterministic projection over the game event
/// log (see `game_projection.dart`). Party-level hall state plus per-person
/// state. Immutable; [GameState.apply] returns a new state.
///
/// Distinct from `DungeonState` (`lib/game/dungeon_state.dart`), the dungeon
/// adapter's read-model of the ledger.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../domain/time.dart';
import '../config/balance.dart';
import 'decor/decor_state.dart';
import 'game_event.dart';
import 'game_projection.dart';
import 'game_values.dart';

/// Why the projection recorded a [GameWarning]. Warnings never block: the
/// event log is the truth, so the projection applies what it safely can and
/// notes the inconsistency (typically a race between two devices).
enum GameWarningCode {
  /// A gem debit exceeded the wallet; the wallet was clamped at zero.
  gemsClamped,

  /// A material debit exceeded the shared pool; that kind was clamped at zero.
  materialsClamped,

  /// A freeze-token debit exceeded the person's tokens; clamped at zero.
  tokensClamped,

  /// The plot was already unlocked; nothing was charged.
  duplicateUnlock,

  /// A building was started on a plot that is not unlocked; applied anyway.
  plotLocked,

  /// A different building already stands on the plot; ignored, not charged.
  plotOccupied,

  /// The plot already holds this building at this tier or higher; ignored.
  duplicateBuild,

  /// The slot already holds this gear at this tier or higher; ignored.
  duplicateGear,

  /// A claim for a reward that is not waiting unclaimed; credited nothing.
  unknownReward,

  /// An open for a chest that is not waiting unopened; credited nothing.
  unknownChest,

  /// Materials collected from a building the hall does not have; credited.
  unknownBuilding,

  /// An expedition started while one was active; ignored.
  expeditionAlreadyActive,

  /// An expedition resolved with none active (or a different region);
  /// credited nothing.
  noActiveExpedition,

  /// A second boss fight for a month already fought; ignored.
  duplicateBossFight,

  /// Left a party the person is not in; ignored.
  notInParty,

  /// A credit would have pushed a material past the Storehouse capacity; the
  /// excess was dropped (typically two devices collecting at once).
  materialsCapped,

  /// An acquisition id already seen; the duplicate grant was ignored.
  duplicateAcquisition,

  /// Placing a decoration the person has no free copy of; ignored.
  decorNotOwned,

  /// Storing a placement that does not exist; ignored.
  unknownPlacement,
}

/// One recorded inconsistency, tied to the event that caused it.
class GameWarning {
  const GameWarning(this.eventId, this.code, [this.detail = '']);

  final String eventId;
  final GameWarningCode code;
  final String detail;

  @override
  bool operator ==(Object other) =>
      other is GameWarning &&
      other.eventId == eventId &&
      other.code == code &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(eventId, code, detail);

  @override
  String toString() => 'GameWarning($eventId, ${code.name}, $detail)';
}

/// The id of the building standing on hall plot [plotIndex]. Stable across
/// upgrades, so production and collection keep their history.
String buildingIdForPlot(int plotIndex) => 'plot-$plotIndex';

/// A building on a plot: what it is, its tier, and its build window.
class BuildingState {
  const BuildingState({
    required this.type,
    required this.tier,
    required this.startedAt,
    required this.completesAt,
  });

  final BuildingType type;
  final int tier;
  final DateTime startedAt;

  /// When the current construction or upgrade finishes.
  final DateTime completesAt;

  /// Whether the current construction or upgrade has finished by [at].
  bool isCompleteAt(DateTime at) => !at.isBefore(completesAt);

  /// The tier in service at [at]: the previous tier while an upgrade is
  /// under way (0 while first being built).
  int tierAt(DateTime at) => isCompleteAt(at) ? tier : tier - 1;

  @override
  bool operator ==(Object other) =>
      other is BuildingState &&
      other.type == type &&
      other.tier == tier &&
      other.startedAt == startedAt &&
      other.completesAt == completesAt;

  @override
  int get hashCode => Object.hash(type, tier, startedAt, completesAt);
}

/// An unlocked hall plot, empty or built on.
class PlotState {
  const PlotState(this.index, [this.building]);

  final int index;
  final BuildingState? building;

  String get buildingId => buildingIdForPlot(index);

  @override
  bool operator ==(Object other) =>
      other is PlotState && other.index == index && other.building == building;

  @override
  int get hashCode => Object.hash(index, building);
}

/// The party-level guild hall.
class HallState {
  const HallState({
    required this.plots,
    required this.materials,
    required this.lastCollectedAt,
  });

  /// Unlocked plots by index.
  final Map<int, PlotState> plots;

  /// The shared material pool.
  final MaterialBundle materials;

  /// The last collection instant per building id.
  final Map<String, DateTime> lastCollectedAt;

  /// The plot holding a building of [type] (lowest index), or null.
  PlotState? plotOf(BuildingType type) {
    final indices = plots.keys.toList()..sort();
    for (final i in indices) {
      if (plots[i]!.building?.type == type) return plots[i];
    }
    return null;
  }

  /// The tier of [type] in service at [at] (0 when the hall has none).
  int completedTier(BuildingType type, DateTime at) =>
      plotOf(type)?.building?.tierAt(at) ?? 0;

  /// How much of each (capped) material the shared pool may hold at [at].
  int storageCapacityAt(DateTime at) => Balance.storehouseCapacityByTier[
      completedTier(BuildingType.storehouse, at)];

  HallState copyWith({
    Map<int, PlotState>? plots,
    MaterialBundle? materials,
    Map<String, DateTime>? lastCollectedAt,
  }) =>
      HallState(
        plots: plots ?? this.plots,
        materials: materials ?? this.materials,
        lastCollectedAt: lastCollectedAt ?? this.lastCollectedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is HallState &&
      _mapsEqual(other.plots, plots) &&
      other.materials == materials &&
      _mapsEqual(other.lastCollectedAt, lastCollectedAt);

  @override
  int get hashCode => Object.hash(plots.length, materials);
}

/// What a hero wears in one slot.
class GearPiece {
  const GearPiece(this.gearType, this.tier);

  final String gearType;
  final int tier;

  @override
  bool operator ==(Object other) =>
      other is GearPiece && other.gearType == gearType && other.tier == tier;

  @override
  int get hashCode => Object.hash(gearType, tier);

  @override
  String toString() => 'GearPiece($gearType, $tier)';
}

/// A person's hero: cosmetic fields and gear by slot.
class HeroState {
  const HeroState({this.cosmetics = const {}, this.gear = const {}});

  final Map<String, String> cosmetics;
  final Map<String, GearPiece> gear;

  /// The hero's power: the sum of every worn gear tier. Improves expedition
  /// loot and boss-fight damage.
  int get power => gear.values.fold(0, (sum, g) => sum + g.tier);

  @override
  bool operator ==(Object other) =>
      other is HeroState &&
      _mapsEqual(other.cosmetics, cosmetics) &&
      _mapsEqual(other.gear, gear);

  @override
  int get hashCode => Object.hash(cosmetics.length, gear.length);
}

/// A granted reward still waiting to be claimed.
class PendingReward {
  const PendingReward({
    required this.rewardId,
    required this.kind,
    required this.reasonCode,
    required this.loot,
    required this.grantedAt,
  });

  final String rewardId;
  final String kind;
  final String reasonCode;
  final Loot loot;
  final DateTime grantedAt;

  @override
  bool operator ==(Object other) =>
      other is PendingReward &&
      other.rewardId == rewardId &&
      other.kind == kind &&
      other.reasonCode == reasonCode &&
      other.loot == loot &&
      other.grantedAt == grantedAt;

  @override
  int get hashCode => Object.hash(rewardId, kind, reasonCode, loot, grantedAt);
}

/// A person's logging streak, derived from the set of covered household-local
/// days (logged, checked in, or frozen).
class StreakState {
  const StreakState([this.coveredDays = const {}, this.frozenDays = const {}]);

  final Set<GameDay> coveredDays;

  /// The covered days a freeze token covered. Never overlaps a logged day: a
  /// freeze for a day that is already covered is ignored.
  final Set<GameDay> frozenDays;

  /// The days the person actually showed up (logged or checked in).
  Set<GameDay> get loggedDays => coveredDays.difference(frozenDays);

  /// The most recent covered day, or null if none.
  GameDay? get lastDay => coveredDays.isEmpty
      ? null
      : coveredDays.reduce((latest, day) => latest.compareTo(day) >= 0 ? latest : day);

  /// The length of the run of consecutive covered days ending at [lastDay].
  /// Whether that run is still alive "today" is the caller's question, since
  /// the projection has no clock.
  int get count {
    var day = lastDay;
    var length = 0;
    while (day != null && coveredDays.contains(day)) {
      length++;
      day = day.previous();
    }
    return length;
  }

  @override
  bool operator ==(Object other) =>
      other is StreakState &&
      _setsEqual(other.coveredDays, coveredDays) &&
      _setsEqual(other.frozenDays, frozenDays);

  @override
  int get hashCode => coveredDays.length;
}

/// A hero currently away on an expedition.
class ActiveExpedition {
  const ActiveExpedition({
    required this.region,
    required this.startedAt,
    required this.durationMinutes,
  });

  final ExpeditionRegion region;
  final DateTime startedAt;
  final int durationMinutes;

  DateTime get endsAt => startedAt.add(Duration(minutes: durationMinutes));

  @override
  bool operator ==(Object other) =>
      other is ActiveExpedition &&
      other.region == region &&
      other.startedAt == startedAt &&
      other.durationMinutes == durationMinutes;

  @override
  int get hashCode => Object.hash(region, startedAt, durationMinutes);
}

/// The outcome of a hero's most recent expedition.
class ExpeditionReport {
  const ExpeditionReport({
    required this.region,
    required this.loot,
    required this.reportLines,
    required this.returnedAt,
  });

  final ExpeditionRegion region;
  final MaterialBundle loot;
  final List<String> reportLines;
  final DateTime returnedAt;

  @override
  bool operator ==(Object other) =>
      other is ExpeditionReport &&
      other.region == region &&
      other.loot == loot &&
      _listsEqual(other.reportLines, reportLines) &&
      other.returnedAt == returnedAt;

  @override
  int get hashCode => Object.hash(region, loot, returnedAt);
}

/// A month's resolved boss fight.
class BossResult {
  const BossResult({
    required this.bossKey,
    required this.won,
    required this.turns,
    required this.rewards,
  });

  final String bossKey;
  final bool won;
  final int turns;
  final Loot rewards;

  @override
  bool operator ==(Object other) =>
      other is BossResult &&
      other.bossKey == bossKey &&
      other.won == won &&
      other.turns == turns &&
      other.rewards == rewards;

  @override
  int get hashCode => Object.hash(bossKey, won, turns, rewards);
}

/// One person's progress through one month's spoils ritual.
class RitualProgress {
  const RitualProgress({this.steps = const {}, this.boss});

  final Set<RitualStep> steps;
  final BossResult? boss;

  @override
  bool operator ==(Object other) =>
      other is RitualProgress && _setsEqual(other.steps, steps) && other.boss == boss;

  @override
  int get hashCode => Object.hash(steps.length, boss);
}

const Object _unset = Object();

/// Everything the game tracks for one person.
class PersonState {
  const PersonState({
    required this.personId,
    this.hero = const HeroState(),
    this.gems = 0,
    this.freezeTokens = 0,
    this.unopenedChests = const {},
    this.unclaimedRewards = const {},
    this.streak = const StreakState(),
    this.activeExpedition,
    this.lastExpedition,
    this.ritual = const {},
    this.partyId,
    this.seenRewardIds = const {},
    this.seenChestIds = const {},
  });

  final String personId;
  final HeroState hero;

  /// The personal gem wallet.
  final int gems;
  final int freezeTokens;

  /// Chests waiting to be opened, by chest id.
  final Map<String, ChestType> unopenedChests;

  /// Rewards waiting to be claimed, by reward id.
  final Map<String, PendingReward> unclaimedRewards;
  final StreakState streak;
  final ActiveExpedition? activeExpedition;
  final ExpeditionReport? lastExpedition;

  /// Ritual progress per month.
  final Map<Month, RitualProgress> ritual;

  /// The party this person adventures with, or null (e.g. a Standard-mode
  /// adult backing the party as its supply caravan).
  final String? partyId;

  /// Every reward id ever granted to this person, claimed or not, so a
  /// duplicate grant is never credited twice.
  final Set<String> seenRewardIds;

  /// Every chest id ever granted to this person, opened or not.
  final Set<String> seenChestIds;

  PersonState copyWith({
    HeroState? hero,
    int? gems,
    int? freezeTokens,
    Map<String, ChestType>? unopenedChests,
    Map<String, PendingReward>? unclaimedRewards,
    StreakState? streak,
    Object? activeExpedition = _unset,
    ExpeditionReport? lastExpedition,
    Map<Month, RitualProgress>? ritual,
    Object? partyId = _unset,
    Set<String>? seenRewardIds,
    Set<String>? seenChestIds,
  }) =>
      PersonState(
        personId: personId,
        hero: hero ?? this.hero,
        gems: gems ?? this.gems,
        freezeTokens: freezeTokens ?? this.freezeTokens,
        unopenedChests: unopenedChests ?? this.unopenedChests,
        unclaimedRewards: unclaimedRewards ?? this.unclaimedRewards,
        streak: streak ?? this.streak,
        activeExpedition: identical(activeExpedition, _unset)
            ? this.activeExpedition
            : activeExpedition as ActiveExpedition?,
        lastExpedition: lastExpedition ?? this.lastExpedition,
        ritual: ritual ?? this.ritual,
        partyId: identical(partyId, _unset) ? this.partyId : partyId as String?,
        seenRewardIds: seenRewardIds ?? this.seenRewardIds,
        seenChestIds: seenChestIds ?? this.seenChestIds,
      );

  @override
  bool operator ==(Object other) =>
      other is PersonState &&
      other.personId == personId &&
      other.hero == hero &&
      other.gems == gems &&
      other.freezeTokens == freezeTokens &&
      _mapsEqual(other.unopenedChests, unopenedChests) &&
      _mapsEqual(other.unclaimedRewards, unclaimedRewards) &&
      other.streak == streak &&
      other.activeExpedition == activeExpedition &&
      other.lastExpedition == lastExpedition &&
      _mapsEqual(other.ritual, ritual) &&
      other.partyId == partyId &&
      _setsEqual(other.seenRewardIds, seenRewardIds) &&
      _setsEqual(other.seenChestIds, seenChestIds);

  @override
  int get hashCode => Object.hash(personId, gems, freezeTokens, partyId);
}

/// The whole guild-hall game state.
class GameState {
  const GameState({
    required this.hall,
    this.people = const {},
    this.warnings = const [],
    this.cursor,
    this.decor = DecorState.empty,
  });

  /// The state before any event: the starting plots unlocked and empty.
  factory GameState.initial() => GameState(
        hall: HallState(
          plots: Map.unmodifiable({
            for (var i = 0; i < Balance.startingPlotCount; i++) i: PlotState(i),
          }),
          materials: const MaterialBundle.empty(),
          lastCollectedAt: const {},
        ),
      );

  final HallState hall;

  /// Per-person state, for everyone any event has touched.
  final Map<String, PersonState> people;

  /// Inconsistencies noted while projecting, in event order.
  final List<GameWarning> warnings;

  /// The last event applied (null before any). Bookkeeping for incremental
  /// application; not part of equality.
  final GameEvent? cursor;

  /// Decoration inventories, placements and worn outfits and titles.
  final DecorState decor;

  /// [personId]'s state, or an empty person if no event has touched them.
  PersonState person(String personId) =>
      people[personId] ?? PersonState(personId: personId);

  /// Applies one event incrementally. Events must arrive in canonical
  /// `(occurredAt, eventId)` order: re-applying the cursor event is a no-op,
  /// and an event ordering before it throws [StateError] (rebuild with
  /// `projectGameState` instead).
  GameState apply(GameEvent event) => applyGameEvent(this, event);

  GameState copyWith({
    HallState? hall,
    Map<String, PersonState>? people,
    List<GameWarning>? warnings,
    GameEvent? cursor,
    DecorState? decor,
  }) =>
      GameState(
        hall: hall ?? this.hall,
        people: people ?? this.people,
        warnings: warnings ?? this.warnings,
        cursor: cursor ?? this.cursor,
        decor: decor ?? this.decor,
      );

  @override
  bool operator ==(Object other) =>
      other is GameState &&
      other.hall == hall &&
      _mapsEqual(other.people, people) &&
      _listsEqual(other.warnings, warnings) &&
      other.decor == decor;

  @override
  int get hashCode => Object.hash(hall, people.length, warnings.length);

  @override
  String toString() => 'GameState(people: ${people.keys.toList()}, '
      'pool: ${hall.materials}, warnings: $warnings)';
}

bool _mapsEqual<K, V>(Map<K, V> first, Map<K, V> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    if (!second.containsKey(entry.key) || second[entry.key] != entry.value) return false;
  }
  return true;
}

bool _setsEqual<T>(Set<T> first, Set<T> second) =>
    identical(first, second) || (first.length == second.length && first.containsAll(second));

bool _listsEqual<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}
