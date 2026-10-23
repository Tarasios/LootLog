/// The month-end dungeon's game-voice lines, loaded from
/// `assets/game/text/dungeon_lines.json` rather than hardcoded, so writers
/// can reword them without touching Dart (every set is listed in
/// `docs/voice-lines.md` beside its trigger and intended outcome).
///
/// Same shape as the hall voice: parsing is pure ([DungeonVoice.parse]) so
/// tests validate the shipped file, picks are seeded so a line never flickers
/// between rebuilds, and `{placeholders}` are filled at the call site. Every
/// set falls back to a calm built-in line, so a half-edited file never blanks
/// the screen. Lines decorate the battle; the numbers come from the ledger.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/game_rng.dart';

/// Where the dungeon's lines live.
const kDungeonLinesAsset = 'assets/game/text/dungeon_lines.json';

class DungeonVoice {
  const DungeonVoice({this.sets = const {}});

  /// Before the file loads: the built-in lines only.
  static const empty = DungeonVoice();

  /// The line sets, by name.
  final Map<String, List<String>> sets;

  /// The set names the file is expected to carry, each with the line used
  /// when the set is missing.
  static const fallbacks = <String, String>{
    'gateOpen': "The dungeon gate stands open. Last month's leftovers are yours to wield.",
    'gateClosed':
        "The gate is sealed until the month turns. Keep logging — every coin you don't spend becomes a weapon.",
    'upkeep': 'The gatekeeper tallies the upkeep before you descend.',
    'weaponReady': '{name} gleams with {amount}. Where will you strike?',
    'hitGoal': '{amount} lands on {target}!',
    'hitDebt': '{amount} strikes the OVERBUDGET on {target}!',
    'taxFlies': '{amount} flies to the war chest.',
    'bank': '{amount} goes into your pouch for later.',
    'carry': '{amount} stays with {name} for next month.',
    'bossFalls': '{target} falls! The goal is yours.',
    'victory': 'The party climbs back to town with the spoils.',
    'noLeftovers': "Nothing left over this month — and that's fine. Every budget did its job.",
  };

  /// Parses the JSON document. Keys starting with `_` are comments.
  factory DungeonVoice.parse(String json) {
    final root = (jsonDecode(json) as Map).cast<String, Object?>();
    return DungeonVoice(sets: {
      for (final entry in root.entries)
        if (entry.value is List && !entry.key.startsWith('_'))
          entry.key: [for (final line in entry.value! as List) line as String],
    });
  }

  /// A line from [set], chosen by [seed], with `{name}` placeholders filled
  /// from [fill].
  String line(String set, {Object? seed, Map<String, String> fill = const {}}) {
    final lines = sets[set];
    final String chosen;
    if (lines == null || lines.isEmpty) {
      chosen = fallbacks[set] ?? '';
    } else {
      chosen = lines[seed == null ? 0 : stableHash32('$seed') % lines.length];
    }
    var filled = chosen;
    for (final entry in fill.entries) {
      filled = filled.replaceAll('{${entry.key}}', entry.value);
    }
    return filled;
  }
}

/// Loads the dungeon lines from the bundle ([rootBundle] by default).
Future<DungeonVoice> loadDungeonVoice([AssetBundle? bundle]) async =>
    DungeonVoice.parse(await (bundle ?? rootBundle).loadString(kDungeonLinesAsset));

/// The dungeon lines, loaded once. Screens use `.value ?? DungeonVoice.empty`.
final dungeonVoiceProvider = FutureProvider<DungeonVoice>((ref) => loadDungeonVoice());
