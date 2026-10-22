/// The game-voice lines the commands write into events (expedition reports).
/// They are stored in the event when the command runs, so every device shows
/// the same report forever after; editing a line here changes future reports
/// only. Writers can change these without touching any logic.
///
/// (Display-time narrative lives under `app/assets/game/text/`; these are
/// here because the pure game domain composes them at command time.)
///
/// Pure Dart, zero Flutter imports.
library;

import '../domain/game_values.dart';

abstract final class Narration {
  /// How each region reads in a report.
  static const Map<ExpeditionRegion, String> regionNames = {
    ExpeditionRegion.marketCatacombs: 'the Market Catacombs',
    ExpeditionRegion.tavernCellars: 'the Tavern Cellars',
    ExpeditionRegion.oldRoads: 'the Old Roads',
    ExpeditionRegion.hearthstoneKeep: 'Hearthstone Keep',
    ExpeditionRegion.bazaarOfWhims: 'the Bazaar of Whims',
    ExpeditionRegion.subscriptionSwamp: 'the Subscription Swamp',
    ExpeditionRegion.theWilds: 'the Wilds',
  };

  /// The report's first line; `{region}` is replaced. One is picked with the
  /// event-seeded RNG.
  static const List<String> expeditionOpeners = [
    'Back from {region}, boots muddy and pack full!',
    'The hero returns from {region} with tales to tell.',
    '{region} explored. Time to unpack the haul.',
  ];

  /// One line per material found; `{n}` and `{material}` are replaced.
  static const String foundLine = 'Found {n} {material}.';

  /// When the Storehouse had no room for some of a find.
  static const String leftBehindLine =
      'The storehouse is full: {n} {material} left by the road.';

  /// When nothing was found at all.
  static const String emptyHanded =
      'Nothing worth carrying this time, but the road was good practice.';
}
