/// Flutter wiring for the asset-key registry: loads the bundled asset manifest
/// once to discover key-named art, and [AdventureSpriteScope] hands the
/// device's render tier and that registry to every `GameSprite` below it.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_sprite.dart';
import '../skin_prefs.dart';
import 'asset_registry.dart';

/// [AssetRegistry.bundled] plus every key-named PNG the app bundles
/// (`assets/game/<category>.<subject>.<variant>.<state>_<N>f.png`). Falls back
/// to [AssetRegistry.bundled] alone if the manifest cannot be read.
Future<AssetRegistry> loadGameAssetRegistry([AssetBundle? bundle]) async {
  try {
    final manifest =
        await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
    return AssetRegistry.bundled
        .merge(AssetRegistry.discover(manifest.listAssets()));
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
