/// Maps asset keys to bundled art files in `app/assets/game/`.
///
/// Two sources feed it: the explicit [AssetRegistry.bundled] map (the legacy,
/// pre-key dungeon filenames) and [AssetRegistry.discover], which picks up any
/// file named after its key (`building.lumberyard.t2.idle_4f.png`) from the
/// app's asset manifest — so an artist ships a sprite by dropping a correctly
/// named PNG into `app/assets/game/`, with no code change. A key with no file
/// on its fallback chain resolves to null, and `GameSprite` renders its
/// text/ASCII card.
///
/// Pure Dart, zero Flutter imports.
library;

import 'art_source.dart';
import 'asset_key.dart';
import 'sprite_region.dart';

/// An immutable `key value -> filename` map with fallback-chain lookup.
/// Filenames are relative to `assets/game/` and carry the `_<N>f` frame-count
/// suffix the sprite renderer reads.
class AssetRegistry {
  const AssetRegistry(this.files, [this.regions = const {}]);

  /// No art at all: every key renders as text.
  static const empty = AssetRegistry({});

  /// The art bundled today, keyed explicitly because these files predate the
  /// key naming convention. New art should be named after its key instead
  /// (see [discover]) rather than added here.
  static const bundled = AssetRegistry({
    'dungeon.hero.a.idle': 'hero_a_idle_4f.png',
    'dungeon.hero.b.idle': 'hero_b_idle_4f.png',
    'dungeon.monster.default.idle': 'monster_idle_4f.png',
    'dungeon.monster.default.enraged': 'monster_enraged_4f.png',
    'dungeon.pet.default.idle': 'pet_idle_4f.png',
    'dungeon.quest_monster.default.idle': 'quest_monster_4f.png',
    'dungeon.gold_pouch.default.idle': 'gold_pouch_1f.png',
    'dungeon.war_chest.default.idle': 'war_chest_1f.png',
    'dungeon.reserve_cache.default.idle': 'reserve_cache_1f.png',
    'dungeon.coin.default.idle': 'coin_spin_6f.png',
    'dungeon.trophy.default.idle': 'trophy_1f.png',
    'dungeon.anvil.default.idle': 'anvil_1f.png',
    'dungeon.contract_seal.default.idle': 'contract_seal_1f.png',
    'dungeon.ransack.default.idle': 'ransack_1f.png',
    'dungeon.scroll_seal.default.idle': 'scroll_seal_1f.png',
    'dungeon.supplies.default.idle': 'supplies_1f.png',
    'dungeon.writ.default.idle': 'writ_1f.png',
  });

  /// Key value (`building.forge.t3.idle`) -> filename under `assets/game/`.
  final Map<String, String> files;

  /// Key value -> a region of a bundled pack sheet.
  final Map<String, SpriteRegion> regions;

  /// The first file on [key]'s [AssetKey.fallbackChain], or null when none of
  /// its keys has art (→ the text/ASCII card).
  String? fileFor(AssetKey key) {
    for (final k in key.fallbackChain) {
      final file = files[k.value];
      if (file != null) return file;
    }
    return null;
  }

  /// The art for [key]: walking its fallback chain, the first key with an
  /// artist file or a pack region wins, and at the same key a file beats a
  /// region (an artist's PNG overrides the pack). Null -> the text card.
  ArtSource? artFor(AssetKey key) {
    for (final candidate in key.fallbackChain) {
      final fileName = files[candidate.value];
      if (fileName != null) return ArtFile(fileName);
      final region = regions[candidate.value];
      if (region != null) return ArtRegion(region);
    }
    return null;
  }

  /// Whether [key] resolves to any art (file or region).
  bool hasArt(AssetKey key) => artFor(key) != null;

  /// This registry with [other]'s entries added, [other] winning on clashes.
  AssetRegistry merge(AssetRegistry other) => AssetRegistry(
        Map.unmodifiable({...files, ...other.files}),
        Map.unmodifiable({...regions, ...other.regions}),
      );

  /// The directory prefix asset-manifest paths carry for game art.
  static const assetDir = 'assets/game/';

  static final RegExp _keyedFile =
      RegExp(r'^([a-z0-9_]+\.[a-z0-9_]+\.[a-z0-9_]+\.[a-z0-9_]+?)(_(\d+)f)?\.png$');

  /// Builds a registry from asset-manifest paths, keeping only PNGs directly
  /// in `assets/game/` whose name is a valid key plus an optional `_<N>f`
  /// frame suffix: `assets/game/chest.gold.open.idle_1f.png`. When two files
  /// share a key, the one with more frames wins (an animated strip upgrades a
  /// still).
  static AssetRegistry discover(Iterable<String> assetPaths) {
    final found = <String, String>{};
    final frames = <String, int>{};
    for (final path in assetPaths) {
      if (!path.startsWith(assetDir)) continue;
      final name = path.substring(assetDir.length);
      if (name.contains('/')) continue;
      final match = _keyedFile.firstMatch(name);
      if (match == null) continue;
      final key = AssetKey.tryParse(match.group(1)!);
      if (key == null) continue;
      final n = int.tryParse(match.group(3) ?? '') ?? 1;
      final previous = frames[key.value];
      if (previous != null && previous >= n) continue;
      found[key.value] = name;
      frames[key.value] = n;
    }
    return AssetRegistry(Map.unmodifiable(found));
  }
}
