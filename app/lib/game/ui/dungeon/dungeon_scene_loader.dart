/// Builds the month-end dungeon's pixel scene for a battle: decodes the goal
/// pictures, reads the art registry and dresses the hero in this adult's
/// outfit. Never used in the text tier.
library;

import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../features/household_context.dart';
import '../../../ui/format.dart';
import '../../assets/asset_key.dart';
import '../../assets/asset_registry.dart';
import '../../assets/game_asset_scope.dart';
import '../../battle/month_end_battle.dart';
import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/game_state.dart';
import '../../scenes/dungeon/dungeon_game.dart';
import '../../scenes/pack_atlas.dart';

/// The default hero, for an adventurer with no outfit on.
const AssetKey _defaultHeroKey = AssetKey('hero', 'body');

/// [memberId]'s outfit sprite, or null for the default hero.
AssetKey? outfitKeyOf(GameState game, DecorCatalog catalog, String memberId) {
  final outfitId = game.decor.outfitOf(memberId);
  return outfitId == null ? null : catalog.itemFor(outfitId)?.assetKey;
}

/// A built scene and the pictures it draws, which the caller disposes.
typedef DungeonSceneLoad = ({DungeonGame game, Map<String, ui.Image> pictures});

/// Builds [battle]'s scene. Reads through [container], so it is safe to call
/// from a screen that may close while it runs; the caller disposes the
/// pictures if it no longer wants the scene.
Future<DungeonSceneLoad> loadDungeonScene(ProviderContainer container, MonthEndBattle battle) async {
  final pictures = await _decodePictures(container, battle);
  AssetRegistry registry;
  try {
    registry = await container.read(gameAssetRegistryProvider.future);
  } on Object {
    registry = AssetRegistry.bundled;
  }
  final game = container.read(gameStateProvider).value ?? GameState.initial();
  final meId = container.read(meUserIdProvider) ?? '';
  final catalog = container.read(decorCatalogProvider).value ?? DecorCatalog.empty;
  return (
    game: DungeonGame(
      atlas: PackAtlas.shared(registry),
      bosses: battle.bosses,
      debts: battle.debts,
      heroKey: outfitKeyOf(game, catalog, meId) ?? _defaultHeroKey,
      pictures: pictures,
      moneyLabel: money,
    ),
    pictures: pictures,
  );
}

Future<Map<String, ui.Image>> _decodePictures(ProviderContainer container, MonthEndBattle battle) async {
  final pictures = <String, ui.Image>{};
  for (final boss in battle.bosses) {
    final sha = boss.pictureSha256;
    if (sha == null) continue;
    try {
      final codec = await ui.instantiateImageCodec(await container.read(blobStoreProvider).read(sha));
      pictures[boss.questId] = (await codec.getNextFrame()).image;
    } on Object {
      // A missing or unreadable picture just leaves the boss on its own.
      continue;
    }
  }
  return pictures;
}
