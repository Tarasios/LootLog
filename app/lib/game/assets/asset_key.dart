/// The asset key: the one name every game visual goes through.
///
/// A key has four dot-separated segments, `category.subject.variant.state`,
/// e.g. `building.lumberyard.t2.idle` or `chest.gold.open.idle`. Each segment
/// is lower snake_case starting with a letter (`[a-z][a-z0-9]*(_[a-z0-9]+)*`).
/// `GameSprite` renders a key as pixel art when the registry has a file for it
/// and as a text/ASCII card otherwise (see `asset_registry.dart` and
/// `text_sprite.dart`).
///
/// Pure Dart, zero Flutter imports.
library;

/// One `category.subject.variant.state` asset key. Value-equal by its segments.
///
/// The const constructor does not validate (Dart cannot run a regex in a const
/// context); use [isValid] for const keys, or [AssetKey.checked] / [parse] to
/// validate at runtime. The catalogue's tests assert every shipped key is valid.
class AssetKey {
  const AssetKey(
    this.category,
    this.subject, [
    this.variant = defaultVariant,
    this.state = idleState,
  ]);

  /// Builds a key, throwing a [FormatException] if any segment is malformed.
  factory AssetKey.checked(
    String category,
    String subject, [
    String variant = defaultVariant,
    String state = idleState,
  ]) {
    final key = AssetKey(category, subject, variant, state);
    if (!key.isValid) {
      throw FormatException('Invalid asset key segment', key.value);
    }
    return key;
  }

  /// Parses `category.subject.variant.state`, throwing [FormatException] when
  /// the string does not have exactly four valid segments.
  factory AssetKey.parse(String source) {
    final key = tryParse(source);
    if (key == null) throw FormatException('Invalid asset key', source);
    return key;
  }

  /// Like [AssetKey.parse] but returns null for a malformed key.
  static AssetKey? tryParse(String source) {
    final parts = source.split('.');
    if (parts.length != 4) return null;
    final key = AssetKey(parts[0], parts[1], parts[2], parts[3]);
    return key.isValid ? key : null;
  }

  /// The variant every fallback chain ends on (`hero.portrait.default.idle`).
  static const defaultVariant = 'default';

  /// The state every fallback chain ends on.
  static const idleState = 'idle';

  static final RegExp _segment = RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$');

  /// What kind of thing: `building`, `chest`, `material`, `region`, `hero`,
  /// `gear`, `boss`, `currency`, `ui`, `homestead`, `dungeon`, ...
  final String category;

  /// Which one: `lumberyard`, `gold`, `ore`, `subscription_swamp`, ...
  final String subject;

  /// Which look of it: a tier (`t2`), `closed` / `open`, `icon`, `banner`, or
  /// `default`.
  final String variant;

  /// What it is doing: `idle` (always the fallback), `constructing`,
  /// `enraged`, `defeated`, ...
  final String state;

  /// Whether a [segment] is lower snake_case starting with a letter.
  static bool isValidSegment(String segment) => _segment.hasMatch(segment);

  bool get isValid =>
      isValidSegment(category) &&
      isValidSegment(subject) &&
      isValidSegment(variant) &&
      isValidSegment(state);

  /// The canonical dotted string, e.g. `building.lumberyard.t2.idle`.
  String get value => '$category.$subject.$variant.$state';

  AssetKey withState(String state) =>
      AssetKey(category, subject, variant, state);

  AssetKey withVariant(String variant) =>
      AssetKey(category, subject, variant, state);

  /// The keys tried, in order, when looking up art: the key itself, then the
  /// same variant at [idleState], then the [defaultVariant] at this state, then
  /// [defaultVariant] at [idleState]. Never crosses subject or category, and
  /// holds no duplicates.
  List<AssetKey> get fallbackChain {
    final chain = <AssetKey>[
      this,
      withState(idleState),
      withVariant(defaultVariant),
      AssetKey(category, subject, defaultVariant, idleState),
    ];
    final seen = <AssetKey>{};
    return [
      for (final k in chain)
        if (seen.add(k)) k,
    ];
  }

  /// Turns an enum name (`centralHall`), a display name (`Bazaar of Whims`) or
  /// free text (`frost-wyrm 2`) into a valid key segment (`central_hall`,
  /// `bazaar_of_whims`, `frost_wyrm_2`). Apostrophes are dropped
  /// (`Scribe's Desk` -> `scribes_desk`); an empty result reads `unknown` and a
  /// leading digit gains an `x` prefix.
  static String snakeSegment(String name) {
    final spaced = name
        .replaceAll("'", '')
        .replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .toLowerCase();
    final words = spaced
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'unknown';
    final joined = words.join('_');
    return RegExp(r'^[0-9]').hasMatch(joined) ? 'x$joined' : joined;
  }

  /// The subject as a human name: `subscription_swamp` -> `Subscription Swamp`,
  /// `bazaar_of_whims` -> `Bazaar of Whims`, `scribes_desk` -> `Scribe's Desk`.
  String get displayName => humanize(subject);

  /// Humanises one snake_case segment (see [displayName]).
  static String humanize(String segment) {
    final override = _displayOverrides[segment];
    if (override != null) return override;
    final words = segment.split('_').where((w) => w.isNotEmpty).toList();
    return [
      for (var i = 0; i < words.length; i++)
        (i > 0 && _minorWords.contains(words[i]))
            ? words[i]
            : words[i][0].toUpperCase() + words[i].substring(1),
    ].join(' ');
  }

  static const _minorWords = {'of', 'the', 'and', 'a', 'an', 'in', 'on'};

  /// Names whose apostrophe a snake_case segment cannot carry.
  static const _displayOverrides = {
    'scribes_desk': "Scribe's Desk",
    'hunters_lodge': "Hunter's Lodge",
  };

  @override
  bool operator ==(Object other) =>
      other is AssetKey &&
      other.category == category &&
      other.subject == subject &&
      other.variant == variant &&
      other.state == state;

  @override
  int get hashCode => Object.hash(category, subject, variant, state);

  @override
  String toString() => value;
}
