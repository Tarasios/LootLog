/// The built-in town-growth lines of the long road: Castle Hill, the civic
/// buildings of the Guard Post, Residential Quarter, Park and Market Row,
/// guards and resting farms, houses, the market trade and the park's
/// festival. Merged into `TownGrowthLines` (`town_growth_lines.dart`) and
/// shipped in `assets/game/text/town_growth.json`; every line is listed in
/// `docs/voice-lines.md`.
///
/// Placeholders: `{guards}`, `{plots}`, `{housing}`, `{needed}`, `{tier}`.
///
/// Pure Dart, zero Flutter imports.
library;

import '../game_values.dart';

/// The keys of civic building [type]'s name and blurb.
String civicBuildingNameKey(CivicBuildingType type) => 'civic.name.${type.name}';
String civicBuildingBlurbKey(CivicBuildingType type) => 'civic.blurb.${type.name}';

const Map<String, String> kLongRoadGrowthLines = {
  'district.name.castleHill': 'Castle Hill',
  'district.blurb.castleHill':
      'A hilltop waiting for a castle. Once your town is a city, raise it stage by stage.',
  'civic.name.watchtower': 'Watchtower',
  'civic.name.barracks': 'Barracks',
  'civic.name.wallSection': 'Wall section',
  'civic.name.cottage': 'Cottage',
  'civic.name.rowhouse': 'Rowhouse',
  'civic.name.well': 'Well',
  'civic.name.garden': 'Garden',
  'civic.name.bandstand': 'Bandstand',
  'civic.name.fountain': 'Fountain',
  'civic.name.stall': 'Market stall',
  'civic.name.workshop': 'Workshop',
  'civic.name.guildHall': 'Guild hall',
  'civic.blurb.watchtower': 'A lookout over the fields. Its guards watch over more farmland.',
  'civic.blurb.barracks': 'Home to the town guard. The most guards of any building.',
  'civic.blurb.wallSection': 'A stretch of stone wall. A few more guards, and a safer town.',
  'civic.blurb.cottage': 'A snug home with a garden. More residents come to live in town.',
  'civic.blurb.rowhouse': 'Homes in a row, for a town on the rise. Houses the most residents.',
  'civic.blurb.well': 'Fresh water for the quarter. A few more families settle nearby.',
  'civic.blurb.garden': 'Flower beds and shady paths. The town grows more prosperous.',
  'civic.blurb.bandstand': 'Music on summer evenings. Adds the most prosperity in the park.',
  'civic.blurb.fountain': 'A splashing fountain where neighbours meet. Adds prosperity.',
  'civic.blurb.stall': 'A trader sets up shop. Brings a market trade on every day you log.',
  'civic.blurb.workshop': 'Craftsfolk turn raw materials into planks, cut stone, tools and cloth.',
  'civic.blurb.guildHall': 'Where the guilds meet. Adds prosperity to Market Row.',
  'guards.capacity': '{guards} guards watch over {plots} fields.',
  'guards.resting':
      'This farm is resting until guards watch over its field. It keeps everything and grows again once guarded.',
  'guards.whatToBuild':
      'Build or raise a watchtower, barracks or wall section in the Guard Post to guard more fields.',
  'guards.resumed': 'Guards are on watch: the farm is growing again.',
  'housing.line': '{housing} residents live in your houses.',
  'book.housingDone': 'Homes for a {tier}: {housing} of {needed}. Ready!',
  'book.housingToGo':
      'Homes for a {tier}: {housing} of {needed}. Build or raise cottages and rowhouses in the Residential Quarter.',
  'book.waitingOnHomes': 'New families are on their way. The town keeps everything while the homes go up.',
  'market.trade': 'A trader at your market stall has a swap for you.',
  'park.festival': 'The park puts everyone in a festive mood: this weekend\'s festival is one size grander.',
};
