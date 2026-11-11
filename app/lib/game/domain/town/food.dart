/// A town's food: what its farms grow, what the granary holds, what its
/// residents eat, and whether the stores are enough to grow past the
/// hamlet.
///
/// Farms grow food by the hour under the same working shift as every
/// producer (`hall_rules.dart`): the whole day on days the town's adult
/// logged, the short shift on the rest. Harvesting banks it, up to the
/// granary's capacity. Each household day since the first harvest the
/// residents eat their need (`FoodConsumed`, written by the reward engine
/// once per day; a larger copy for the same day tops up the difference). The
/// stores never go below zero, and a hungry town loses nothing else: it only
/// waits to grow.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../game_state.dart';
import '../game_values.dart';
import '../hall_rules.dart';
import 'districts.dart';

/// A town's food stores.
class FoodStore {
  const FoodStore({
    this.stored = 0,
    this.since,
    this.eatenByDay = const {},
    this.lastHarvestedAt = const {},
  });

  static const FoodStore empty = FoodStore();

  /// Food in store; never negative.
  final int stored;

  /// The household day of the first harvest: residents eat from then on.
  final GameDay? since;

  /// The need recorded for each eaten day (the largest copy seen), whether
  /// or not the stores covered it, so a day is never eaten twice.
  final Map<GameDay, int> eatenByDay;

  /// The last harvest instant per farm plot.
  final Map<PlotAddress, DateTime> lastHarvestedAt;

  FoodStore copyWith({
    int? stored,
    GameDay? since,
    Map<GameDay, int>? eatenByDay,
    Map<PlotAddress, DateTime>? lastHarvestedAt,
  }) =>
      FoodStore(
        stored: stored ?? this.stored,
        since: since ?? this.since,
        eatenByDay: eatenByDay ?? this.eatenByDay,
        lastHarvestedAt: lastHarvestedAt ?? this.lastHarvestedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is FoodStore &&
      other.stored == stored &&
      other.since == since &&
      _mapsEqual(other.eatenByDay, eatenByDay) &&
      _mapsEqual(other.lastHarvestedAt, lastHarvestedAt);

  @override
  int get hashCode => Object.hash(stored, since, eatenByDay.length);
}

/// Residents of a [tier] town.
int populationOf(TownTier tier) => Balance.populationByTier[tier]!;

/// Food a [tier] town eats a day: its residents times what each eats.
int dailyFoodNeed(TownTier tier) => populationOf(tier) * Balance.foodPerResident[tier]!;

/// How much food [town] can store at [at], by its granary's completed tier.
int foodCapacityAt(HallState town, DateTime at) => Balance.granaryFoodCapacityByTier[
    town.districts.completedFarmTier(FarmBuildingType.granary, at)];

/// Whether [town]'s stores hold [Balance.foodSecureDays] days of a [tier]
/// town's need.
bool foodSecure(HallState town, TownTier tier) =>
    town.food.stored >= Balance.foodSecureDays * dailyFoodNeed(tier);

/// The food the farm building on [address] grew since its last harvest (or
/// its first completion), as of [now], before the granary's cap: only the
/// minutes the crew worked count (see `workedMinutes`), at the old tier
/// until an upgrade completes. Zero for an empty plot or a granary.
int uncollectedFood(
  HallState town,
  PlotAddress address,
  DateTime now, {
  required Set<GameDay> activeDays,
}) {
  final building = town.districts.buildingAt(address);
  final type = building?.farmType;
  if (building == null || type == null) return 0;
  final rates = Balance.farmBuildings[type]!.foodPerHour;
  if (rates.isEmpty) return 0;
  final from = town.food.lastHarvestedAt[address] ??
      (building.tier == 1 ? building.completesAt : building.startedAt);
  if (!now.isAfter(from)) return 0;
  final completesAt = building.completesAt;
  final oldTierEnd = now.isBefore(completesAt) ? now : completesAt;
  final newTierStart = from.isAfter(completesAt) ? from : completesAt;
  int rate(int tier) => tier < 1 ? 0 : rates[tier - 1];
  return (rate(building.tier - 1) * workedMinutes(from, oldTierEnd, activeDays) +
          rate(building.tier) * workedMinutes(newTierStart, now, activeDays)) ~/
      60;
}

/// What harvesting [address] at [now] would bank: what it grew, trimmed to
/// the room left in the granary.
int harvestableFood(
  HallState town,
  PlotAddress address,
  DateTime now, {
  required Set<GameDay> activeDays,
}) {
  final grown = uncollectedFood(town, address, now, activeDays: activeDays);
  final room = foodCapacityAt(town, now) - town.food.stored;
  return grown < room ? grown : (room < 0 ? 0 : room);
}

/// The days the residents still have to eat, with what each needs: every
/// household day from the first harvest (or [oldest], if later) up to, not
/// including, [today], whose recorded need is below the need of the tier the
/// town held that day ([tierOn]).
List<({GameDay day, int amount})> foodConsumptionDue({
  required FoodStore food,
  required TownTier Function(GameDay day) tierOn,
  required GameDay oldest,
  required GameDay today,
}) {
  final since = food.since;
  if (since == null) return const [];
  final due = <({GameDay day, int amount})>[];
  for (var day = since > oldest ? since : oldest; day < today; day = day.next()) {
    final need = dailyFoodNeed(tierOn(day));
    if (need > (food.eatenByDay[day] ?? 0)) due.add((day: day, amount: need));
  }
  return due;
}

/// [food] after a harvest of [amount] from [address] at [at], kept to
/// [capacity] (never below what was already stored); also whether any was
/// left in the field.
({FoodStore food, bool capped}) harvestInto(
  FoodStore food, {
  required PlotAddress address,
  required int amount,
  required int capacity,
  required DateTime at,
}) {
  final cap = food.stored > capacity ? food.stored : capacity;
  var stored = food.stored + amount;
  final capped = stored > cap;
  if (capped) stored = cap;
  final day = GameDay.fromInstant(at);
  final since = food.since;
  final last = food.lastHarvestedAt[address];
  return (
    food: FoodStore(
      stored: stored,
      since: since == null || day < since ? day : since,
      eatenByDay: food.eatenByDay,
      lastHarvestedAt: last == null || at.isAfter(last)
          ? Map.unmodifiable({...food.lastHarvestedAt, address: at})
          : food.lastHarvestedAt,
    ),
    capped: capped,
  );
}

/// [food] after the residents ate [amount] on [day]: a day already eaten
/// eats only what a larger copy adds, and the stores stop at zero.
FoodStore eatFrom(FoodStore food, {required GameDay day, required int amount}) {
  final eaten = food.eatenByDay[day] ?? 0;
  if (amount <= eaten) return food;
  final stored = food.stored - (amount - eaten);
  return food.copyWith(
    stored: stored < 0 ? 0 : stored,
    eatenByDay: Map.unmodifiable({...food.eatenByDay, day: amount}),
  );
}

bool _mapsEqual<K, V>(Map<K, V> first, Map<K, V> second) =>
    identical(first, second) ||
    (first.length == second.length &&
        first.entries.every((entry) =>
            second.containsKey(entry.key) && second[entry.key] == entry.value));
