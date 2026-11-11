/// The wording of the town's growth: tier names and the line that greets
/// each new tier, district names and blurbs, farm building names, and the
/// town book's lines. Read from `assets/game/text/town_growth.json` with a
/// built-in line for every key, so a half-edited file never blanks a page.
/// Every line is listed in `docs/voice-lines.md` beside its trigger.
///
/// Placeholders the screen fills: `{tier}` (a tier's name), `{prosperity}`,
/// `{needed}`, `{stored}`, `{capacity}`, `{need}` and `{food}` (numbers),
/// `{days}` ([Balance.foodSecureDays]).
///
/// Pure Dart, zero Flutter imports.
library;

import '../game_values.dart';

/// The key of [tier]'s name.
String tierNameKey(TownTier tier) => 'tier.name.${tier.name}';

/// The key of the line celebrating a town that grew into [tier].
String tierReachedKey(TownTier tier) => 'tier.reached.${tier.name}';

/// The keys of district [districtId]'s name and blurb.
String districtNameKey(String districtId) => 'district.name.$districtId';
String districtBlurbKey(String districtId) => 'district.blurb.$districtId';

/// The key of [type]'s name.
String farmBuildingNameKey(FarmBuildingType type) => 'farm.name.${type.name}';

/// The town's growth lines by key.
class TownGrowthLines {
  const TownGrowthLines._(this._lines);

  /// The built-in lines, used before the file loads and for any key it lacks.
  static const TownGrowthLines defaults = TownGrowthLines._(_builtIn);

  /// Reads `town_growth.json`. A missing, empty or non-text key keeps its
  /// built-in line; keys the build does not know are ignored.
  factory TownGrowthLines.fromJson(Map<String, dynamic> json) => TownGrowthLines._({
        for (final entry in _builtIn.entries)
          entry.key: switch (json[entry.key]) {
            final String text when text.trim().isNotEmpty => text,
            _ => entry.value,
          },
      });

  final Map<String, String> _lines;

  /// Every key this build has a line for.
  Iterable<String> get keys => _lines.keys;

  /// The line for [key]; empty for a key this build lacks (a district a
  /// newer build added reads as its id until this build updates).
  String line(String key) => _lines[key] ?? '';

  @override
  bool operator ==(Object other) =>
      other is TownGrowthLines &&
      other._lines.length == _lines.length &&
      _lines.entries.every((entry) => other._lines[entry.key] == entry.value);

  @override
  int get hashCode => Object.hashAll(_lines.values);
}

const Map<String, String> _builtIn = {
  'tier.name.outpost': 'Outpost',
  'tier.name.hamlet': 'Hamlet',
  'tier.name.village': 'Village',
  'tier.name.town': 'Town',
  'tier.name.city': 'City',
  'tier.reached.hamlet':
      'Smoke from new chimneys: the outpost is a hamlet now. Every day you logged built this.',
  'tier.reached.village':
      'Bells ring over full granaries. The hamlet has grown into a village!',
  'tier.reached.town':
      'Market stalls, cobbled streets, a town hall: your village is a town.',
  'tier.reached.city':
      'Towers on the skyline and lights in every window. Welcome to your city.',
  'district.name.outpost': 'The Outpost',
  'district.name.farmland': 'Farmland',
  'district.name.guardPost': 'Guard Post',
  'district.name.residential': 'Residential Quarter',
  'district.name.park': 'Park',
  'district.name.marketRow': 'Market Row',
  'district.blurb.outpost': 'Where the town began: the hall, the yards and the workshops.',
  'district.blurb.farmland':
      'Six fields beyond the wall. Farms and orchards grow food; a granary keeps it.',
  'district.blurb.guardPost': 'Watchtowers for a village that has something worth guarding.',
  'district.blurb.residential': 'Cottages and gardens for the people your town draws in.',
  'district.blurb.park': 'Lawns, a pond and a bandstand for a town at ease.',
  'district.blurb.marketRow': 'A street of shopfronts for a town that trades.',
  'district.opensAt': 'Opens at {tier}',
  'district.comingLater': 'Arrives in a later season',
  'farm.name.farm': 'Farm',
  'farm.name.orchard': 'Orchard',
  'farm.name.granary': 'Granary',
  'book.title': 'Town book',
  'book.prosperity': 'Prosperity {prosperity}. A {tier} needs {needed}.',
  'book.top': 'Prosperity {prosperity}. The town has grown as grand as it can, for now.',
  'book.food': '{stored} of {capacity} food in store. The residents eat {need} a day.',
  'book.foodNeeded':
      'To grow into a {tier}, the stores need {food} food: {days} days of meals. '
          'The town keeps everything while it waits.',
  'book.foodSecure': 'The stores are well stocked.',
};
