/// How a town grows: its prosperity, and the tiers (outpost, hamlet,
/// village, town, city) its peak prosperity opens.
///
/// Prosperity is a pure function of the town as it stands: what has been
/// built, how it is decorated, and the festivals it has held. It can dip (a
/// decoration stored away), so the reward engine stores the highest value
/// seen in a `ProsperityReached` event and tiers read that peak. A tier past
/// the hamlet also needs the town's food in store (`food.dart`); a town
/// that is short simply waits, and nothing is ever taken from it.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../game_state.dart';
import '../game_values.dart';

/// [town]'s prosperity at [at]:
/// - [Balance.prosperityPerBuildingTier] for every completed building tier
///   in every district (an upgrade under way counts its previous tier),
/// - [Balance.prosperityPerDistrict] for each district bought beyond the
///   outpost,
/// - [Balance.prosperityPerDecoration] for each town decoration on display,
///   up to [Balance.prosperityDecorationCap] of them,
/// - [Balance.prosperityPerFestival] for every weekend festival held.
int townProsperity(
  HallState town, {
  required int townDecorationsPlaced,
  required int festivalsHeld,
  required DateTime at,
}) {
  var buildingTiers = town.districts.completedTiersAt(at);
  for (final plot in town.plots.values) {
    final building = plot.building;
    if (building != null) buildingTiers += building.tierAt(at);
  }
  final decorations = townDecorationsPlaced.clamp(0, Balance.prosperityDecorationCap);
  return buildingTiers * Balance.prosperityPerBuildingTier +
      town.districts.purchased.length * Balance.prosperityPerDistrict +
      decorations * Balance.prosperityPerDecoration +
      festivalsHeld * Balance.prosperityPerFestival;
}

/// [personId]'s town prosperity at [at], as the engine and the town book
/// read it from the state: the person's own town and festivals, and the
/// household's town decorations on display.
int prosperityOf(GameState state, String personId, DateTime at) => townProsperity(
      state.townOf(personId),
      townDecorationsPlaced: state.decor.townPlacements.length,
      festivalsHeld: state.person(personId).festivals.length,
      at: at,
    );

/// The prosperity [tier] needs.
int tierThreshold(TownTier tier) => Balance.tierProsperity[tier]!;

/// The tier after [tier], or null for a city.
TownTier? nextTier(TownTier tier) =>
    tier.index + 1 < TownTier.values.length ? TownTier.values[tier.index + 1] : null;

/// Whether growing into [tier] needs food in store: the village and beyond.
bool tierNeedsFood(TownTier tier) => tier.index >= TownTier.village.index;

/// The tiers a town at [current] grows into now, in order: each one whose
/// threshold the [peak] meets, stopping at the first that needs food when
/// [foodSecureFrom] (asked with the tier being left) says the stores are
/// short. A short town keeps everything it has; it only waits.
List<TownTier> tiersDue({
  required TownTier current,
  required int peak,
  required bool Function(TownTier from) foodSecureFrom,
}) {
  final due = <TownTier>[];
  var from = current;
  for (var next = nextTier(from); next != null; next = nextTier(from)) {
    if (peak < tierThreshold(next)) break;
    if (tierNeedsFood(next) && !foodSecureFrom(from)) break;
    due.add(next);
    from = next;
  }
  return due;
}

/// The reward id of [who]'s reward for reaching [tier]. One per person per
/// tier, so two devices that both see the tier grant it once.
String tierRewardId(String who, TownTier tier) => 'tier:$who:${tier.name}';
