/// The text-mode tier of a sprite: a tiny ASCII emblem, a title and an
/// optional badge, derived from the asset key. This is the first-class
/// text-adventure look (tier 3), not an error state — every key in the game
/// has one, so a screen is complete before a single PNG exists.
///
/// Pure Dart, zero Flutter imports. Art is plain printable ASCII (no emoji, no
/// box-drawing) so it renders identically in every monospace font.
library;

import 'asset_key.dart';

/// The tallest emblem, in lines.
const kTextSpriteMaxLines = 4;

/// The widest emblem line, in characters.
const kTextSpriteMaxWidth = 9;

/// A key's text-mode rendering: [art] lines (all the same width), a [title]
/// and an optional [badge] (`T3`, `OPEN`, `ENRAGED`, ...).
class TextSprite {
  TextSprite({required List<String> art, required this.title, this.badge})
      : art = List.unmodifiable(_padded(art));

  final List<String> art;
  final String title;
  final String? badge;

  static List<String> _padded(List<String> lines) {
    final width = lines.fold<int>(0, (w, l) => l.length > w ? l.length : w);
    return [for (final l in lines) l.padRight(width)];
  }
}

/// The text sprite for [key]. [label] (a member's or quest's name) replaces
/// the derived title; the emblem always comes from the key.
TextSprite textSpriteFor(AssetKey key, {String? label}) => TextSprite(
      art: _artFor(key),
      title: (label != null && label.trim().isNotEmpty) ? label : _titleFor(key),
      badge: _badgeFor(key),
    );

/// The text sprite for a key-less sprite (a legacy filename or a custom blob):
/// the generic emblem under [label].
TextSprite labelTextSprite(String label) =>
    TextSprite(art: _generic, title: label.trim().isEmpty ? '?' : label);

// ---------------------------------------------------------------------------
// Titles & badges
// ---------------------------------------------------------------------------

String _titleFor(AssetKey key) {
  switch (key.category) {
    case 'chest':
      return '${key.displayName} Chest';
    case 'hero':
      if (key.subject == 'portrait') return 'Hero';
      if (key.subject == 'caravan') return 'Supply Caravan';
      return key.displayName;
    case 'ui':
      return key.variant == AssetKey.defaultVariant
          ? key.displayName
          : '${AssetKey.humanize(key.variant)} ${key.displayName}';
    case 'homestead':
      return 'Homestead';
    default:
      return key.displayName;
  }
}

/// Variants that say nothing a title or emblem does not already say.
const _quietVariants = {AssetKey.defaultVariant, 'closed', 'icon', 'banner'};

String? _badgeFor(AssetKey key) {
  final parts = <String>[];
  final v = key.variant;
  final quiet = _quietVariants.contains(v) ||
      key.category == 'ui' ||
      v.length == 1; // dungeon.hero.a / .b: interchangeable looks
  if (!quiet) parts.add(AssetKey.humanize(v).toUpperCase());
  if (key.state != AssetKey.idleState) {
    parts.add(AssetKey.humanize(key.state).toUpperCase());
  }
  return parts.isEmpty ? null : parts.join(' ');
}

// ---------------------------------------------------------------------------
// Emblems
// ---------------------------------------------------------------------------

const _generic = ['.-.', '|*|', "'-'"];

const _hero = [' o ', '/|\\', '/ \\'];
const _boss = ['/\\_/\\', '(>_<)', ' VVV '];
const _chestClosed = [' ____ ', '|_==_|', '|____|'];
const _chestOpen = [' ____ ', '/ \$\$ \\', '|____|'];
const _scroll = ['.--.', '|~~|', "'--'"];

/// Lookup order: `category.subject.variant`, `category.subject@state`,
/// `category.subject`, `category:variant`, `category`, then [_generic].
const Map<String, List<String>> _emblems = {
  // Buildings: one silhouette; the title and tier badge tell them apart.
  'building': [' /\\ ', '/  \\', '|[]|'],
  'building.vault': ['.---.', '|(o)|', "'---'"],
  'building.arcane_well': [' .*. ', '(___)', '|   |'],

  // Chests.
  'chest:closed': _chestClosed,
  'chest:open': _chestOpen,
  'chest': _chestClosed,

  // Materials.
  'material': ['<*>'],
  'material.lumber': ['(o)==', '(o)=='],
  'material.stone': [' __ ', '(__)'],
  'material.ore': [' .. ', '<oo>'],
  'material.herbs': ['\\|/', ' | '],
  'material.hide': ['/~~\\', '\\__/'],
  'material.crystal': ['/\\', '\\/'],
  'material.essence': [' ~ ', '(*)'],
  'material.trophy': ['\\_/', ' T '],

  // Currency.
  'currency': ['(o)'],
  'currency.gem': [' /\\ ', '<  >', ' \\/ '],
  'currency.freeze_token': [' __ ', '(**)', ' -- '],

  // Regions: a hanging banner.
  'region': ['|~~~|', '|   |', ' \\_/ '],

  // Heroes & gear.
  'hero': _hero,
  'hero.caravan': [' ____  ', '|____|>', ' o  o  '],
  'gear': ['  /', ' / ', 'x  '],
  'gear.armor': ['/|=|\\', ' |=| '],
  'gear.helm': [' __ ', '/||\\'],
  'gear.trinket': [' o ', '(*)'],

  // Bosses.
  'boss': _boss,

  // UI & homestead.
  'ui': ['+--+', '|  |', '+--+'],
  'homestead': ['  /\\  ', ' /  \\ ', '/____\\'],

  // Dungeon (existing art).
  'dungeon': ['(?)'],
  'dungeon.hero': _hero,
  'dungeon.monster': ['(o_o)', '/| |\\'],
  'dungeon.monster@enraged': ['(>_<)', '/| |\\'],
  'dungeon.overbudget': ['/\\___/\\', '(O   O)', ' \\VVV/ '],
  'dungeon.pet': ['/\\_/\\', '(o.o)'],
  'dungeon.quest_monster': _boss,
  'dungeon.gold_pouch': [' _ ', '(\$)'],
  'dungeon.war_chest': _chestClosed,
  'dungeon.reserve_cache': ['[+]'],
  'dungeon.coin': ['(o)'],
  'dungeon.trophy': ['\\_/', ' T '],
  'dungeon.campfire': ['  )  ', ' (,) ', '/___\\'],
  'dungeon.anvil': ['____', ' ][ '],
  'dungeon.contract_seal': ['(@)'],
  'dungeon.ransack': ['\\ /', ' X ', '/ \\'],
  'dungeon.scroll_seal': _scroll,
  'dungeon.writ': _scroll,
  'dungeon.supplies': ['[==]', '[==]'],
};

List<String> _artFor(AssetKey key) {
  final c = key.category, s = key.subject;
  return _emblems['$c.$s.${key.variant}'] ??
      _emblems['$c.$s@${key.state}'] ??
      _emblems['$c.$s'] ??
      _emblems['$c:${key.variant}'] ??
      _emblems[c] ??
      _generic;
}
