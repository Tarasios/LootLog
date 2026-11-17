/// The wording of the road between neighbouring towns: the signpost, a
/// visit to a neighbour's town, the gift dialog, cheers, and the trade-road
/// caravans in the inbox. Read from `assets/game/text/neighbours.json` with a
/// built-in line for every key, so a half-edited file never blanks a page.
/// Every line is listed in `docs/voice-lines.md` beside its trigger.
///
/// Placeholders the screen fills: `{name}` (a neighbour's name), `{tier}` (a
/// tier's name), `{goods}` (materials, e.g. "12 lumber"), `{capacity}`,
/// `{prosperity}` (numbers). No line ever names a neighbour as inactive or
/// blames anyone (design rule 7).
///
/// Pure Dart, zero Flutter imports.
library;

/// The neighbourly lines by key.
class NeighbourLines {
  const NeighbourLines._(this._lines);

  /// The built-in lines, used before the file loads and for any key it lacks.
  static const NeighbourLines defaults = NeighbourLines._(_builtIn);

  /// Reads `neighbours.json`. A missing, empty or non-text key keeps its
  /// built-in line; keys the build does not know are ignored.
  factory NeighbourLines.fromJson(Map<String, dynamic> json) => NeighbourLines._({
        for (final entry in _builtIn.entries)
          entry.key: switch (json[entry.key]) {
            final String text when text.trim().isNotEmpty => text,
            _ => entry.value,
          },
      });

  final Map<String, String> _lines;

  /// Every key this build has a line for.
  Iterable<String> get keys => _lines.keys;

  /// The line for [key], with each `{name}` in [fill] replaced.
  String line(String key, [Map<String, String> fill = const {}]) {
    var text = _lines[key] ?? '';
    for (final entry in fill.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }

  @override
  bool operator ==(Object other) =>
      other is NeighbourLines &&
      other._lines.length == _lines.length &&
      _lines.entries.every((entry) => other._lines[entry.key] == entry.value);

  @override
  int get hashCode => Object.hashAll(_lines.values);
}

const Map<String, String> _builtIn = {
  'signpost.title': 'The road to the neighbours',
  'signpost.body': 'Neighbouring towns lie down the east road. Whose town will you visit?',
  'signpost.caravan': 'A supply caravan is camped by the road. It keeps the neighbouring towns stocked.',
  'visit.header': 'Visiting {name}',
  'visit.welcome':
      "You're a guest in {name}'s {tier}. Look around, send a gift or cheer them on!",
  'visit.empty':
      "An open plot, ready for {name}'s next build.",
  'visit.locked': 'Wild ground, not cleared yet.',
  'visit.building': 'Tier {tier}. Built with care.',
  'visit.underConstruction': 'Under construction: tier {tier} is on its way.',
  'gift.title': 'Send a gift',
  'gift.intro':
      "Choose what to send from your stores. It travels the road to {name}'s town.",
  'gift.room':
      "{name}'s storehouse holds up to {capacity} of each material. Each row shows the room left.",
  'gift.nothing': 'Your stores are empty for now. Collect from your buildings, then send a gift.',
  'gift.sent':
      "Sent {goods} to {name}'s town. What a neighbour!",
  'gift.trimmed':
      "{name}'s storehouse took {goods}. The rest is still in yours.",
  'cheer.sent':
      "You cheered {name}'s town!",
  'cheer.done': 'Cheered today',
  'cheer.received': '{name} cheered your town',
  'cheer.section': 'Cheers from the neighbours',
  'trade.fromTown':
      "A caravan from {name}'s town brought {goods}",
  'trade.fromCaravan': 'The supply caravan brought {goods} down the trade road',
  'text.title': 'Neighbouring towns',
  'text.town':
      "{name}'s {tier}: prosperity {prosperity}.",
  'text.caravan': 'The supply caravan camps by the road, keeping the neighbouring towns stocked.',
};
