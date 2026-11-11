/// The wording of the town's daily events (and, from the festival, its
/// weekend festivals), read from `assets/game/text/town_events.json` with a
/// built-in line for every key, so a half-edited file never blanks a story.
/// Every line is listed in `docs/voice-lines.md` beside its trigger.
///
/// Placeholders the screen fills: `{gives}` and `{receives}` (amounts, in
/// game words), `{building}` (the producer having a good day).
///
/// Pure Dart, zero Flutter imports.
library;

/// The town's event lines by key (`trader.1`, `windfall.2`, ...).
class TownEventLines {
  const TownEventLines._(this._lines);

  /// The built-in lines, used before the file loads and for any key it lacks.
  static const TownEventLines defaults = TownEventLines._(_builtIn);

  /// Reads `town_events.json`. A missing, empty or non-text key keeps its
  /// built-in line; keys the build does not know are ignored.
  factory TownEventLines.fromJson(Map<String, dynamic> json) =>
      TownEventLines._({
        for (final entry in _builtIn.entries)
          entry.key: switch (json[entry.key]) {
            final String text when text.trim().isNotEmpty => text,
            _ => entry.value,
          },
      });

  final Map<String, String> _lines;

  /// Every key this build has a line for.
  Iterable<String> get keys => _lines.keys;

  /// The line for [key]. A key this build lacks (a newer device rolled a
  /// line not shipped here) reads as the first line of its kind (`trader.9`
  /// becomes `trader.1`); a key of no known kind is empty.
  String line(String key) {
    final known = _lines[key];
    if (known != null) return known;
    final dot = key.indexOf('.');
    if (dot <= 0) return '';
    return _lines['${key.substring(0, dot)}.1'] ?? '';
  }

  @override
  bool operator ==(Object other) =>
      other is TownEventLines &&
      other._lines.length == _lines.length &&
      _lines.entries.every((entry) => other._lines[entry.key] == entry.value);

  @override
  int get hashCode => Object.hashAll(_lines.values);
}

const Map<String, String> _builtIn = {
  'trader.1':
      'A travelling trader sets up by the well. Swap {gives} for {receives}?',
  'trader.2':
      'A cart rolls in with just what the yard is short of: {receives} for {gives}.',
  'trader.3':
      "A merchant tips her hat. \"I'll take {gives} off your hands for {receives}.\"",
  'windfall.1':
      'The {building} crew is in fine form today: {receives} extra, ready to bring in.',
  'windfall.2':
      'A lucky find at the {building}! {receives} waiting to be stacked.',
  'windfall.3':
      'The {building} had a cracking morning. {receives} more for the stores.',
  'visitor.1': 'An old friend stops by with a gift: {receives}.',
  'visitor.2': 'A neighbour leaves a parcel at your door: {receives}.',
  'visitor.3': 'A wandering bard pays for supper with {receives}.',
};
