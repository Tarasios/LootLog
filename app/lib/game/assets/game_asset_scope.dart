/// Flutter wiring for the asset-key registry: loads the bundled asset manifest
/// once to discover key-named art, and [AdventureSpriteScope] hands the
/// device's render tier and that registry to every `GameSprite` below it.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_sprite.dart';
import '../skin_prefs.dart';
import 'asset_registry.dart';
import 'sprite_region.dart';

/// Matches a pack's regions file in an asset-manifest path and captures the
/// pack folder, whatever prefix or separator the path carries.
final RegExp _packRegionsPath = RegExp(r'packs[/\\]([^/\\]+)[/\\]regions\.json$');

/// [AssetRegistry.bundled], every key-named PNG, and every pack's
/// `regions.json`. Falls back to [AssetRegistry.bundled] alone if the manifest
/// cannot be read; a pack whose regions file fails to parse is skipped.
Future<AssetRegistry> loadGameAssetRegistry([AssetBundle? bundle]) async {
  final assets = bundle ?? rootBundle;
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(assets);
    final paths = manifest.listAssets();
    var registry =
        AssetRegistry.bundled.merge(AssetRegistry.discover(paths));
    for (final path in paths) {
      final packFolder = _packRegionsPath.firstMatch(path)?.group(1);
      if (packFolder == null) continue;
      try {
        final regionsJson =
            jsonDecode(await assets.loadString(path)) as Map<String, dynamic>;
        registry = registry.merge(
            AssetRegistry(const {}, parsePackRegions(packFolder, regionsJson)));
      } on Object {
        continue;
      }
    }
    return registry;
  } catch (_) {
    return AssetRegistry.bundled;
  }
}

/// The app's asset registry, discovered from the bundle once per process.
final gameAssetRegistryProvider =
    FutureProvider<AssetRegistry>((ref) => loadGameAssetRegistry());

/// Wraps a game screen so its sprites follow the device's adventure tier
/// (text mode renders every sprite as its text card) and see discovered art.
/// While the registry loads, [AssetRegistry.bundled] is used.
class AdventureSpriteScope extends ConsumerWidget {
  const AdventureSpriteScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GameSpriteScope(
        tier: ref.watch(adventureTierProvider),
        registry: ref.watch(gameAssetRegistryProvider).value ??
            AssetRegistry.bundled,
        child: child,
      );
}
