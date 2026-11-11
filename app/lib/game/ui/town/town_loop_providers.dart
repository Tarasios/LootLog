/// Riverpod wiring for the town loop: the wording of the town's events
/// (`town_events.json`), and this device's memory of which once-a-day and
/// once-a-weekend pop-ups it has already shown — the "while you were away"
/// summary and the festival celebration. The memory is per device: held for
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

/// What this device has already shown: the day of the last away summary and
/// the week (its Monday) of the last festival celebration. [loaded] is false
/// until the stored memory has been read, and nothing pops up before then.
class TownLoopShown {
  const TownLoopShown({this.loaded = false, this.awayDay, this.festivalWeek});

  final bool loaded;
  final GameDay? awayDay;
  final GameDay? festivalWeek;

  /// Whether the away summary may open on [today].
  bool awayDue(GameDay today) => loaded && awayDay != today;

  /// Whether the festival celebration may open on [today]'s weekend.
  bool festivalDue(GameDay today) => loaded && festivalWeek != today.weekStart;

  String encode() => [
    if (awayDay case final day?) 'away=${day.toKey()}',
    if (festivalWeek case final week?) 'festival=${week.toKey()}',
  ].join('\n');

  static TownLoopShown decode(String text) {
    GameDay? awayDay;
    GameDay? festivalWeek;
    for (final line in const LineSplitter().convert(text)) {
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      final day = _parseDay(line.substring(separator + 1).trim());
      switch (line.substring(0, separator).trim()) {
        case 'away':
          awayDay = day;
        case 'festival':
          festivalWeek = day;
      }
    }
    return TownLoopShown(loaded: true, awayDay: awayDay, festivalWeek: festivalWeek);
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
    // A pop-up marked during the read wins over the stored memory.
    state = TownLoopShown(
      loaded: true,
      awayDay: state.awayDay ?? restored.awayDay,
      festivalWeek: state.festivalWeek ?? restored.festivalWeek,
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

  void markAwayShown(GameDay today) =>
      _update(TownLoopShown(loaded: state.loaded, awayDay: today, festivalWeek: state.festivalWeek));

  void markFestivalShown(GameDay today) => _update(
    TownLoopShown(loaded: state.loaded, awayDay: state.awayDay, festivalWeek: today.weekStart),
  );

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
