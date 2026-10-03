/// Device-local persistence and Riverpod wiring for the Adventure render tier.
///
/// Whether a person sees the game at all is their per-person play mode
/// (`features/settings/play_mode.dart`, which replaced the old per-device
/// Classic / Adventure skin file). Within Adventure, pixel vs. text is a
/// per-device cosmetic preference, so it lives in a tiny file in the app
/// documents directory rather than the event log.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ===========================================================================
// Adventure render tier: pixel (tiers 1–2) vs. text mode (tier 3).
// ===========================================================================

/// Within the Adventure skin, which tier the dashboard renders in. Pixel is the
/// target look (full pixel art, degrading per-asset to labelled placeholders);
/// text is the first-class text-adventure fallback. This is the *global text
/// mode toggle* — a per-device cosmetic choice, independent of the art files
/// present, so a device can prefer text even where art exists.
enum AdventureTier { pixel, text }

Future<File> _tierFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'adventure_tier.txt'));
}

/// The tier a device starts on before it makes an explicit choice.
///
/// Text mode today: Adventure reads as a text-based RPG unless real art is
/// provided, and the sprites currently bundled are script-generated
/// placeholders (tool/generate_placeholder_sprites.dart), not the
/// commissioned art. When the real pixel art lands in `assets/game/`, flip
/// this to [AdventureTier.pixel] — the persisted per-device choice always
/// wins either way.
const AdventureTier defaultAdventureTier = AdventureTier.text;

/// Loads the persisted tier, defaulting to [defaultAdventureTier].
Future<AdventureTier> loadAdventureTier() async {
  final f = await _tierFile();
  if (!f.existsSync()) return defaultAdventureTier;
  final s = f.readAsStringSync().trim();
  if (s == AdventureTier.text.name) return AdventureTier.text;
  if (s == AdventureTier.pixel.name) return AdventureTier.pixel;
  return defaultAdventureTier;
}

/// Persists the chosen [tier].
Future<void> saveAdventureTier(AdventureTier tier) async {
  final f = await _tierFile();
  f.writeAsStringSync(tier.name, flush: true);
}

/// The current adventure render tier. Loads the persisted value on first build
/// (holding [defaultAdventureTier] until it arrives) and writes through on
/// [select].
class AdventureTierNotifier extends Notifier<AdventureTier> {
  @override
  AdventureTier build() {
    unawaited(_restore());
    return defaultAdventureTier;
  }

  Future<void> _restore() async {
    final loaded = await loadAdventureTier();
    if (loaded != state) state = loaded;
  }

  Future<void> select(AdventureTier tier) async {
    state = tier;
    await saveAdventureTier(tier);
  }

  void toggle() {
    unawaited(select(
      state == AdventureTier.text ? AdventureTier.pixel : AdventureTier.text,
    ));
  }
}

/// The device's chosen adventure render tier (pixel vs. text mode).
final adventureTierProvider =
    NotifierProvider<AdventureTierNotifier, AdventureTier>(
        AdventureTierNotifier.new);
