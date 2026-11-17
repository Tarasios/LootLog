/// The built-in town-growth lines of the long road's screens: the civic
/// plot sheet, the workshop and Castle sheets, the town book's homes,
/// guards, goods and Castle pages, the farmland's resting fields, the
/// purchase celebrations of the civic quarters and the Castle's stages.
/// Merged into `TownGrowthLines` (`town_growth_lines.dart`) and shipped in
/// `assets/game/text/town_growth.json`; every line is listed in
/// `docs/voice-lines.md`.
///
/// Placeholders: `{district}`, `{building}`, `{stage}` (names), `{count}`,
/// `{tier}` (a tier's name), `{goods}` and `{materials}` (lists), `{time}`
/// (a duration), `{items}` (what is still to gather), `{working}` and
/// `{done}` (numbers).
///
/// Pure Dart, zero Flutter imports.
library;

const Map<String, String> kScreenGrowthLines = {
  'district.bought.guardPost':
      'Stone walls and a watchful gate: the Guard Post is yours. A watchtower brings the first guards.',
  'district.bought.residential':
      'Garden gates and fresh paint: the Residential Quarter is yours. A cottage brings new neighbours.',
  'district.bought.park':
      'Lawns, lamps and a quiet pond: the Park is yours. Plant a garden and the town takes a breath.',
  'district.bought.marketRow':
      'Awnings and cobbles: Market Row is yours. A workshop turns raw materials into fine goods.',
  'district.castleOpen': 'Your city has a hill for its Castle. Visit it to raise the first stage.',
  'civic.plot.empty': 'An empty plot, ready for something new. What should go up here?',
  'civic.plot.locked': 'Buy the {district} to build here.',
  'civic.adds.guards': 'Guards: {count}. Every {per} guards watch over one more farm field.',
  'civic.adds.housing': 'Homes for {count} residents.',
  'civic.adds.prosperity': 'Adds {count} prosperity.',
  'civic.adds.trade': 'A trader stops by your stall on every day you log.',
  'civic.adds.refine': 'Refines up to {count} batches in one job.',
  'civic.built': 'The {building} is going up!',
  'civic.atTop': 'Tier {tier}: as grand as it gets.',
  'refine.takes': 'Takes {materials}.',
  'refine.makes': 'Makes {goods} in {time}.',
  'refine.started': 'The workshop is making {goods}. Ready in {time}.',
  'refine.noWorkshop': 'Build a workshop in Market Row and it will turn raw materials into goods.',
  'refine.allBusy': 'Every workshop is at work. Collect what is ready, then start the next job.',
  'castle.missing': 'Still to gather: {items}.',
  'castle.ready': 'Everything is gathered. The builders are waiting for your word.',
  'castle.started': 'The builders start on the {stage}. Done in {time}.',
  'castle.complete': 'The Castle is complete. Long may its banners fly!',
  'castle.stageReached': '{stage} finished!',
  'book.section.homes': 'Homes',
  'book.homes': '{count} residents live in the houses you built.',
  'book.section.guards': 'Guards and fields',
  'book.fieldsOpen': 'Your town works {count} farm fields.',
  'book.restingFarms': '{count} farms are resting until guards watch over their fields.',
  'book.allGuarded': 'Every farm is guarded and growing.',
  'book.jobs': 'Workshops: {working} at work, {done} ready to collect.',
  'book.stat.homes': 'Homes',
  'book.stat.guards': 'Guards',
  'book.stat.fields': 'Fields',
  'farm.fieldOpensAt': 'This field opens when your town becomes a {tier}.',
};
