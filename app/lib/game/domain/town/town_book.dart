/// The town book: one read model of a town's growth for the UI — its tier
/// and prosperity, what the next tier needs, its food, and every district
/// with whether it is owned or for sale. Display only.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../game_state.dart';
import '../game_values.dart';
import 'districts.dart';
import 'food.dart';
import 'prosperity.dart';

/// One catalogue district as a town sees it.
class DistrictListing {
  const DistrictListing({required this.spec, required this.owned, required this.forSale});

  final DistrictSpec spec;
  final bool owned;

  /// Purchasable and the town's tier has reached it (affordability is the
  /// command's to say).
  final bool forSale;
}

/// A town's growth at a glance.
class TownBook {
  const TownBook({
    required this.tier,
    required this.prosperity,
    required this.peakProsperity,
    required this.nextTier,
    required this.nextTierProsperity,
    required this.population,
    required this.dailyFoodNeed,
    required this.foodStored,
    required this.foodCapacity,
    required this.foodSecureTarget,
    required this.foodSecure,
    required this.districts,
  });

  final TownTier tier;

  /// Prosperity right now (it can dip; tiers read [peakProsperity]).
  final int prosperity;
  final int peakProsperity;

  /// The tier after this one and the prosperity it needs; null for a city.
  final TownTier? nextTier;
  final int? nextTierProsperity;

  final int population;
  final int dailyFoodNeed;
  final int foodStored;
  final int foodCapacity;

  /// Food in store that makes the town food-secure.
  final int foodSecureTarget;
  final bool foodSecure;

  /// Every catalogue district, in catalogue order.
  final List<DistrictListing> districts;

  /// Whether growing into [nextTier] needs food in store.
  bool get nextTierNeedsFood {
    final next = nextTier;
    return next != null && tierNeedsFood(next);
  }

  /// The peak is enough for the next tier, and only the food stores are
  /// short. Nothing is taken meanwhile; the book says what is needed.
  bool get waitingOnFood {
    final needed = nextTierProsperity;
    return needed != null && peakProsperity >= needed && nextTierNeedsFood && !foodSecure;
  }
}

/// [personId]'s town book at [now].
TownBook townBook(GameState state, String personId, DateTime now) {
  final person = state.person(personId);
  final town = state.townOf(personId);
  final tier = person.townTier;
  final next = nextTier(tier);
  final prosperity = prosperityOf(state, personId, now);
  return TownBook(
    tier: tier,
    prosperity: prosperity,
    peakProsperity: prosperity > person.peakProsperity ? prosperity : person.peakProsperity,
    nextTier: next,
    nextTierProsperity: next == null ? null : tierThreshold(next),
    population: populationOf(tier),
    dailyFoodNeed: dailyFoodNeed(tier),
    foodStored: town.food.stored,
    foodCapacity: foodCapacityAt(town, now),
    foodSecureTarget: Balance.foodSecureDays * dailyFoodNeed(tier),
    foodSecure: foodSecure(town, tier),
    districts: [
      for (final spec in kDistricts)
        DistrictListing(
          spec: spec,
          owned: town.districts.owns(spec.id),
          forSale: spec.purchasable &&
              !town.districts.owns(spec.id) &&
              tier.index >= spec.requiredTier.index,
        ),
    ],
  );
}
