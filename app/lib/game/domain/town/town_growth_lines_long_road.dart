/// The built-in town-growth lines of the long road: Castle Hill, the civic
/// buildings of the Guard Post, Residential Quarter, Park and Market Row,
/// guards and resting farms, houses, the market trade, the park's
/// festival, refined goods and the Castle. Merged into `TownGrowthLines`
/// (`town_growth_lines.dart`) and shipped in
/// `assets/game/text/town_growth.json`; every line is listed in
/// `docs/voice-lines.md`.
///
/// Placeholders: `{guards}`, `{plots}`, `{housing}`, `{needed}`, `{tier}`,
/// `{goods}` (a list of goods), `{time}` (when a job or stage is done),
/// `{stage}` (a stage's name), `{count}`.
///
/// Pure Dart, zero Flutter imports.
library;

import '../game_values.dart';

/// The keys of civic building [type]'s name and blurb.
String civicBuildingNameKey(CivicBuildingType type) => 'civic.name.${type.name}';
String civicBuildingBlurbKey(CivicBuildingType type) => 'civic.blurb.${type.name}';

/// The key of [kind]'s name.
String goodsNameKey(GoodsKind kind) => 'goods.name.${kind.name}';

/// The keys of Castle stage [stageKey]'s name and the line that greets it
/// finished.
String castleStageNameKey(String stageKey) => 'castle.stage.$stageKey';
String castleStageDoneKey(String stageKey) => 'castle.done.$stageKey';

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
  'goods.name.planks': 'Planks',
  'goods.name.cutStone': 'Cut stone',
  'goods.name.tools': 'Tools',
  'goods.name.cloth': 'Cloth',
  'goods.title': 'Goods',
  'goods.stored': 'In the workshop lofts: {goods}.',
  'goods.none': 'No goods yet. A Market Row workshop turns raw materials into them.',
  'refine.title': 'Workshop',
  'refine.choose': 'What should the workshop make?',
  'refine.working': 'Making {goods}. Ready {time}.',
  'refine.ready': '{goods} ready to collect!',
  'refine.collected': 'Collected {goods}. The lofts are filling up!',
  'refine.idle': 'The workshop is ready for a new job.',
  'castle.title': 'The Castle',
  'castle.teaser': 'When your town becomes a city, a castle can rise on the hill.',
  'castle.stage.foundation': 'Foundation',
  'castle.stage.keep': 'Keep',
  'castle.stage.walls': 'Walls',
  'castle.stage.towers': 'Towers',
  'castle.stage.banners': 'Banners',
  'castle.next': 'Next: the {stage}.',
  'castle.building': 'The builders are raising the {stage}. Done {time}.',
  'castle.progress': '{count} of 5 stages built.',
  'castle.done.foundation': 'The foundation is laid! Stone by stone, the Castle begins.',
  'castle.done.keep': 'The keep stands tall over the town.',
  'castle.done.walls': 'Walls ring the hill. The Castle takes shape.',
  'castle.done.towers': 'Towers rise at every corner of the Castle.',
  'castle.done.banners':
      'Banners fly from every tower: the Castle is complete! A year of logging built this.',
  'castle.titleEarned': 'You are now Keeper of the Castle.',
};
