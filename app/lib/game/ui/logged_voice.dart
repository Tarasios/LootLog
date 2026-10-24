/// The short acknowledgements shown right after a purchase is logged, loaded
/// from `assets/game/text/purchase_logged.json` rather than hardcoded, so
/// writers can add lines without touching Dart (listed in
/// `docs/voice-lines.md`). Picks are seeded so a line never flickers; the
/// optional `{merchant}` and `{amount}` placeholders are dropped cleanly when
/// the screen has no value for them, and a missing or half-edited file
/// falls back to a calm built-in line.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/game_rng.dart';

/// Where the lines live.
const kPurchaseLoggedAsset = 'assets/game/text/purchase_logged.json';

class LoggedVoice {
  const LoggedVoice({this.lines = const []});

  /// Before the file loads: the built-in line only.
  static const empty = LoggedVoice();

  /// Used when the file has no lines.
  static const fallback = 'Logged. The streak lives on.';

  final List<String> lines;

  /// Parses the JSON document (`{"lines": [...]}`).
  factory LoggedVoice.parse(String json) {
    final root = (jsonDecode(json) as Map).cast<String, Object?>();
    final lines = root['lines'];
    return LoggedVoice(
      lines: lines is List ? [for (final line in lines) line as String] : const [],
    );
  }

  /// A line chosen by [seed], with `{name}` placeholders filled from [fill]
  /// and any left unfilled dropped along with one neighbouring space.
  String line({Object? seed, Map<String, String> fill = const {}}) {
    final chosen = lines.isEmpty
        ? fallback
        : lines[seed == null ? 0 : stableHash32('$seed') % lines.length];
    var filled = chosen;
    for (final entry in fill.entries) {
      filled = filled.replaceAll('{${entry.key}}', entry.value);
    }
    return filled
        .replaceAll(RegExp(r' ?\{[a-z]+\}'), '')
        .replaceAll(RegExp(' {2,}'), ' ')
        .trim();
  }
}

/// Loads the lines from the bundle ([rootBundle] by default).
Future<LoggedVoice> loadLoggedVoice([AssetBundle? bundle]) async =>
    LoggedVoice.parse(await (bundle ?? rootBundle).loadString(kPurchaseLoggedAsset));

/// The logged lines, loaded once. Screens use `.value ?? LoggedVoice.empty`.
final loggedVoiceProvider = FutureProvider<LoggedVoice>((ref) => loadLoggedVoice());
