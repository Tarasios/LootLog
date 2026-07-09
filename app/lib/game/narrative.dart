/// Narrative & encouragement strings, loaded from `assets/game/text/` rather
/// than hardcoded, so writers can add or reword lines without touching Dart.
///
/// Everything here is cosmetic (the firewall): these lines decorate real events
/// but never change a cent. Parsing is a pure function ([parseNarrative]) so it
/// can be unit-tested against the shipped asset files; [loadNarrative] is the
/// thin Flutter wrapper that reads the bundle.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// A streak tier: the shortest streak (`minDays`) that unlocks a set of lines.
class StreakTier {
  const StreakTier({required this.minDays, required this.lines});

  final int minDays;
  final List<String> lines;
}

/// The parsed contents of the four narrative files.
class Narrative {
  const Narrative({
    required this.purchaseLogged,
    required this.streakTiers,
    required this.ritualCelebrations,
    required this.overspendSupport,
  });

  /// Acknowledgments after a purchase is logged. May contain `{amount}` /
  /// `{merchant}` placeholders.
  final List<String> purchaseLogged;

  /// Streak celebrations, sorted ascending by [StreakTier.minDays]. Lines may
  /// contain the `{n}` placeholder for the streak length.
  final List<StreakTier> streakTiers;

  /// Celebrations for completing the monthly wrap-up.
  final List<String> ritualCelebrations;

  /// Supportive, never-shaming lines for an over-limit budget.
  final List<String> overspendSupport;

  /// A random purchase acknowledgment with placeholders filled in. [rng] is
  /// injectable for deterministic tests.
  String purchaseAck({String? amount, String? merchant, Random? rng}) {
    final line = _pick(purchaseLogged, rng);
    return _fill(line, amount: amount, merchant: merchant);
  }

  /// A random supportive line for an over-limit budget.
  String overspendLine({Random? rng}) => _pick(overspendSupport, rng);

  /// A random ritual-completion celebration.
  String ritualLine({Random? rng}) => _pick(ritualCelebrations, rng);

  /// The celebration for a [streakDays]-day streak: the highest tier the streak
  /// reaches, a line at random, `{n}` filled in. Null when no tier applies yet.
  String? streakLine(int streakDays, {Random? rng}) {
    StreakTier? best;
    for (final tier in streakTiers) {
      if (streakDays >= tier.minDays) best = tier;
    }
    if (best == null || best.lines.isEmpty) return null;
    return _pick(best.lines, rng).replaceAll('{n}', '$streakDays');
  }

  static String _fill(String line, {String? amount, String? merchant}) {
    var out = line;
    // Drop a placeholder (and any trailing space it leaves) when unfilled so a
    // line never shows a literal "{merchant}".
    out = amount == null
        ? out.replaceAll('{amount}', '').replaceAll('  ', ' ')
        : out.replaceAll('{amount}', amount);
    out = merchant == null
        ? out.replaceAll('{merchant}', '').replaceAll('  ', ' ')
        : out.replaceAll('{merchant}', merchant);
    return out.trim();
  }

  static String _pick(List<String> lines, Random? rng) {
    if (lines.isEmpty) return '';
    if (lines.length == 1) return lines.first;
    return lines[(rng ?? Random()).nextInt(lines.length)];
  }
}

/// The asset paths, in one place so the loader and tests agree.
abstract final class NarrativeAssets {
  static const dir = 'assets/game/text';
  static const purchaseLogged = '$dir/purchase_logged.json';
  static const streakCelebrations = '$dir/streak_celebrations.json';
  static const ritualCelebrations = '$dir/ritual_celebrations.json';
  static const overspendSupport = '$dir/overspend_support.json';
}

/// Parses the four raw JSON documents into a [Narrative]. Pure — no I/O — so it
/// can be tested directly against the shipped files.
Narrative parseNarrative({
  required String purchaseLoggedJson,
  required String streakCelebrationsJson,
  required String ritualCelebrationsJson,
  required String overspendSupportJson,
}) {
  final streaks = <StreakTier>[
    for (final raw in _list(
        (jsonDecode(streakCelebrationsJson) as Map)['tiers'] as List))
      StreakTier(
        minDays: (raw as Map)['minDays'] as int,
        lines: _stringList(raw['lines']),
      ),
  ]..sort((a, b) => a.minDays.compareTo(b.minDays));

  return Narrative(
    purchaseLogged:
        _linesOf(purchaseLoggedJson),
    streakTiers: streaks,
    ritualCelebrations: _linesOf(ritualCelebrationsJson),
    overspendSupport: _linesOf(overspendSupportJson),
  );
}

/// Reads the `lines` array of a `{ "lines": [...] }` document.
List<String> _linesOf(String json) =>
    _stringList((jsonDecode(json) as Map)['lines']);

List<dynamic> _list(Object? v) => (v as List?) ?? const [];

List<String> _stringList(Object? v) =>
    [for (final e in _list(v)) e as String];

/// Loads the narrative from the asset bundle. Defaults to [rootBundle].
Future<Narrative> loadNarrative([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  final results = await Future.wait([
    b.loadString(NarrativeAssets.purchaseLogged),
    b.loadString(NarrativeAssets.streakCelebrations),
    b.loadString(NarrativeAssets.ritualCelebrations),
    b.loadString(NarrativeAssets.overspendSupport),
  ]);
  return parseNarrative(
    purchaseLoggedJson: results[0],
    streakCelebrationsJson: results[1],
    ritualCelebrationsJson: results[2],
    overspendSupportJson: results[3],
  );
}
