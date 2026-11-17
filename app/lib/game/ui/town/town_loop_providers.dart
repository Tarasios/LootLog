/// Riverpod wiring for the town loop: the wording of the town's events
/// (`town_events.json`), and this device's memory of the weekends whose
/// festival celebration it has already shown and of the last town tier it
/// celebrated. The memory is per device: held for
/// the app session and kept in a tiny file in the app documents directory,
/// like the quest board's fold (`quest_board_prefs.dart`). It never syncs.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/game_state.dart' show PersonState;
import '../../domain/game_values.dart';
import '../../domain/town/town_event_lines.dart';

/// The writers' file of town event wording.
const String kTownEventsAsset = 'assets/game/text/town_events.json';

/// The town's event lines, loaded once. Screens use
/// `.value ?? TownEventLines.defaults`.
final townEventLinesProvider = FutureProvider<TownEventLines>((ref) async {
  final text = await rootBundle.loadString(kTownEventsAsset);
  return TownEventLines.fromJson(jsonDecode(text) as Map<String, dynamic>);
});

/// A tier reached longer ago than this is history, not news: a device that
/// never celebrated it (a new phone) does not pop it up.
const Duration kTierCelebrationWindow = Duration(days: 14);

/// What this device has already shown: the week (its Monday) of the last
/// festival celebration, and the last town tier celebrated. [loaded] is
/// false until the stored memory has been read, and nothing pops up before
/// then.
class TownLoopShown {
  const TownLoopShown({this.loaded = false, this.festivalWeek, this.tierShown});

  final bool loaded;
  final GameDay? festivalWeek;
  final TownTier? tierShown;

  /// Whether the festival celebration may open on [today]'s weekend.
  bool festivalDue(GameDay today) => loaded && festivalWeek != today.weekStart;

  /// The tier [person]'s town grew into that this device has not celebrated
  /// yet, if it was reached recently; null when there is nothing to show.
  TownTier? tierDue(PersonState person, DateTime now) {
    final tier = person.townTier;
    final reachedAt = person.tiersReached[tier];
    if (!loaded || tier == TownTier.outpost || reachedAt == null) return null;
    if (tierShown != null && tierShown!.index >= tier.index) return null;
    return now.difference(reachedAt) <= kTierCelebrationWindow ? tier : null;
  }

  String encode() => [
    if (festivalWeek != null) 'festival=${festivalWeek!.toKey()}',
    if (tierShown != null) 'tier=${tierShown!.name}',
  ].join('\n');

  /// Reads [encode]'s text; lines it does not know are ignored.
  static TownLoopShown decode(String text) {
    GameDay? festivalWeek;
    TownTier? tierShown;
    for (final line in const LineSplitter().convert(text)) {
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      final value = line.substring(separator + 1).trim();
      switch (line.substring(0, separator).trim()) {
        case 'festival':
          festivalWeek = _parseDay(value);
        case 'tier':
          tierShown = TownTier.values.where((tier) => tier.name == value).firstOrNull;
      }
    }
    return TownLoopShown(loaded: true, festivalWeek: festivalWeek, tierShown: tierShown);
  }

  /// A stored day, or null when the line is damaged.
  static GameDay? _parseDay(String key) {
    try {
      return GameDay.parse(key);
    } on FormatException {
      return null;
    }
  }
}

/// Holds [TownLoopShown] for the session and writes it through to a file.
/// Tests override [load] and [save] to keep it in memory.
class TownLoopShownNotifier extends Notifier<TownLoopShown> {
  @override
  TownLoopShown build() {
    unawaited(_restore());
    return const TownLoopShown();
  }

  Future<void> _restore() async {
    TownLoopShown restored;
    try {
      restored = await load();
    } on Object {
      // Nothing stored or no documents directory: start fresh.
      restored = const TownLoopShown(loaded: true);
    }
    // A celebration marked during the read wins over the stored memory.
    state = TownLoopShown(
      loaded: true,
      festivalWeek: state.festivalWeek ?? restored.festivalWeek,
      tierShown: state.tierShown ?? restored.tierShown,
    );
  }

  /// Reads the stored memory.
  Future<TownLoopShown> load() async {
    final file = await _file();
    if (!file.existsSync()) return const TownLoopShown(loaded: true);
    return TownLoopShown.decode(file.readAsStringSync());
  }

  /// Writes [shown] through.
  Future<void> save(TownLoopShown shown) async {
    final file = await _file();
    file.writeAsStringSync(shown.encode(), flush: true);
  }

  static Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(p.join(directory.path, 'town_loop_shown.txt'));
  }

  void markFestivalShown(GameDay today) =>
      _update(TownLoopShown(loaded: state.loaded, festivalWeek: today.weekStart, tierShown: state.tierShown));

  void markTierShown(TownTier tier) =>
      _update(TownLoopShown(loaded: state.loaded, festivalWeek: state.festivalWeek, tierShown: tier));

  void _update(TownLoopShown next) {
    state = next;
    unawaited(
      save(next).catchError((Object _) {
        // Not persisted this time; the session still remembers.
      }),
    );
  }
}

final townLoopShownProvider = NotifierProvider<TownLoopShownNotifier, TownLoopShown>(
  TownLoopShownNotifier.new,
);
