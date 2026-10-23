/// The guild hall's game-voice lines, loaded from
/// `assets/game/text/hall_lines.json` rather than hardcoded, so writers can
/// reword them without touching Dart (every set is listed in
/// `docs/voice-lines.md` beside its trigger and intended outcome).
///
/// Parsing is pure ([HallVoice.parse]) so tests validate the shipped file;
/// [loadHallVoice] is the thin bundle wrapper. Picks are seeded (usually by
/// the event id being celebrated) so a line never flickers between rebuilds
/// and every device shows the same one.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/commands/game_commands.dart';

/// Where the hall's lines live.
const kHallLinesAsset = 'assets/game/text/hall_lines.json';

/// The parsed hall lines. Every getter degrades to a calm built-in line when a
/// set is missing, so a half-edited file never blanks a screen.
class HallVoice {
  const HallVoice({
    this.sets = const {},
    this.reasons = const {},
    this.rejections = const {},
  });

  /// Before the file loads.
  static const empty = HallVoice();

  /// The line sets that are picked from (`greetings`, `chestOpened`, ...).
  final Map<String, List<String>> sets;

  /// Plain descriptions of reward reason codes (`log.daily` -> "Showed up").
  final Map<String, String> reasons;

  /// Friendly copy for each [GameRejection], by name.
  final Map<String, String> rejections;

  /// The set names the file is expected to carry.
  static const setNames = [
    'greetings',
    'noSpendDone',
    'reconcileDone',
    'chestOpened',
    'rewardClaimed',
    'buildStarted',
    'upgradeStarted',
    'collected',
    'expeditionSent',
    'caravan',
  ];

  /// The single-line sets that label a button or a place, each with the
  /// line used when the file lacks it, so no button is ever blank.
  static const fallbacks = <String, String>{
    'dungeonCallout':
        '{month}: the dungeon below the town gate is open. Aim each leftover '
            'at a goal boss or an OVERBUDGET, then return for the spoils chest.',
    'dungeonCalloutButton': 'Enter the dungeon',
    'dungeonPlaceDone': 'All done for now. The next one opens when the month ends.',
    'dungeonPlaceReadyOne': '{n} month ready for the dungeon',
    'dungeonPlaceReadyMany': '{n} months ready for the dungeon',
  };

  /// Parses the JSON document. Keys starting with `_` are comments.
  factory HallVoice.parse(String json) {
    final root = (jsonDecode(json) as Map).cast<String, Object?>();
    Map<String, String> strings(Object? v) => {
          for (final e in ((v as Map?) ?? const {}).entries)
            e.key as String: e.value as String,
        };
    return HallVoice(
      sets: {
        for (final e in root.entries)
          if (e.value is List && !e.key.startsWith('_'))
            e.key: [for (final l in e.value! as List) l as String],
      },
      reasons: strings(root['reasons']),
      rejections: strings(root['rejections']),
    );
  }

  /// A line from [set], chosen by [seed], with `{name}` placeholders filled
  /// from [fill]. A missing set falls back to its built-in line in
  /// [fallbacks], or is empty.
  String line(String set, {Object? seed, Map<String, String> fill = const {}}) {
    final lines = sets[set] ?? const <String>[];
    final fallback = fallbacks[set];
    if (lines.isEmpty && fallback == null) return '';
    var out = lines.isEmpty
        ? fallback!
        : lines[seed == null ? 0 : _stableHash('$seed') % lines.length];
    for (final e in fill.entries) {
      out = out.replaceAll('{${e.key}}', e.value);
    }
    return out;
  }

  /// Friendly copy for [rejection].
  String rejection(GameRejection rejection) =>
      rejections[rejection.name] ?? "That can't be done just yet.";

  /// A plain description of a reward's [reasonCode].
  String reason(String reasonCode) => reasons[reasonCode] ?? 'A reward';

  /// A deterministic string hash (Dart's `hashCode` is not stable across
  /// runs), so a seeded pick is the same on every device.
  static int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }
}

/// Loads the hall lines from the bundle ([rootBundle] by default).
Future<HallVoice> loadHallVoice([AssetBundle? bundle]) async =>
    HallVoice.parse(await (bundle ?? rootBundle).loadString(kHallLinesAsset));

/// The hall lines, loaded once. Screens use `.value ?? HallVoice.empty`.
final hallVoiceProvider = FutureProvider<HallVoice>((ref) => loadHallVoice());
