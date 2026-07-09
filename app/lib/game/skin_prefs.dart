/// Device-local persistence and Riverpod wiring for the presentation skin.
///
/// The Classic / Adventure choice is a per-device cosmetic preference, not
/// household data, so — like the receipt-library root — it lives in a tiny file
/// in the app documents directory rather than the event log. Both skins render
/// from the same providers with identical numbers; only the widgets differ.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Which presentation skin the dashboard renders in.
enum AppSkin { classic, adventure }

Future<File> _skinFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'app_skin.txt'));
}

/// Loads the persisted skin, defaulting to [AppSkin.adventure] — the game is
/// the product, so Adventure is the primary experience on every platform until
/// a device explicitly chooses Classic.
Future<AppSkin> loadAppSkin() async {
  final f = await _skinFile();
  if (!f.existsSync()) return AppSkin.adventure;
  final s = f.readAsStringSync().trim();
  return s == AppSkin.classic.name ? AppSkin.classic : AppSkin.adventure;
}

/// Persists the chosen [skin].
Future<void> saveAppSkin(AppSkin skin) async {
  final f = await _skinFile();
  f.writeAsStringSync(skin.name, flush: true);
}

/// The current skin. Loads the persisted value on first build (defaulting to
/// Classic until it arrives) and writes through on [select].
class AppSkinNotifier extends Notifier<AppSkin> {
  @override
  AppSkin build() {
    // Kick off the load; the Adventure default stands until it resolves.
    unawaited(_restore());
    return AppSkin.adventure;
  }

  Future<void> _restore() async {
    final loaded = await loadAppSkin();
    if (loaded != state) state = loaded;
  }

  Future<void> select(AppSkin skin) async {
    state = skin;
    await saveAppSkin(skin);
  }

  void toggle() {
    unawaited(select(
      state == AppSkin.classic ? AppSkin.adventure : AppSkin.classic,
    ));
  }
}

/// The device's chosen presentation skin.
final appSkinProvider =
    NotifierProvider<AppSkinNotifier, AppSkin>(AppSkinNotifier.new);

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

/// Loads the persisted tier, defaulting to [AdventureTier.pixel] — the pixel
/// presentation is the target experience; missing sprites degrade on their own.
Future<AdventureTier> loadAdventureTier() async {
  final f = await _tierFile();
  if (!f.existsSync()) return AdventureTier.pixel;
  final s = f.readAsStringSync().trim();
  return s == AdventureTier.text.name ? AdventureTier.text : AdventureTier.pixel;
}

/// Persists the chosen [tier].
Future<void> saveAdventureTier(AdventureTier tier) async {
  final f = await _tierFile();
  f.writeAsStringSync(tier.name, flush: true);
}

/// The current adventure render tier. Loads the persisted value on first build
/// (defaulting to pixel until it arrives) and writes through on [select].
class AdventureTierNotifier extends Notifier<AdventureTier> {
  @override
  AdventureTier build() {
    unawaited(_restore());
    return AdventureTier.pixel;
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
