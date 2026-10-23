/// Provider overrides for the town shell tests: the guild-hall harness's
/// in-memory game log, fixed clock and fixed tier, plus a fixed game state and
/// a registry that never decodes an image (unless a test hands one in).
library;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/data/game_providers.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/scenes/town/town_game.dart' show TownsfolkEntry;
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/town/town_townsfolk.dart';

import '../hall_harness.dart';

/// The hall harness overrides plus [game] (default: the lived-in sample hall;
/// or, with a [liveStore], the state projected live from that log so commands
/// show up),
/// no townsfolk (unless given), and [registry] (default: [AssetRegistry.empty], so every
/// sprite is a labelled placeholder and no image is decoded).
List<Override> townTestOverrides({
  required AdventureTier tier,
  GameState? game,
  InMemoryGameEventStore? liveStore,
  bool registryFails = false,
  AssetRegistry registry = AssetRegistry.empty,
  List<TownsfolkEntry> townsfolk = const [],
  AdventureTierNotifier? tierNotifier,
}) {
  final state = game ?? projectGameState(sampleEvents());
  return [
    ...hallOverrides(
      store: liveStore ?? InMemoryGameEventStore(),
      tier: tier,
      registry: registry,
      registryFails: registryFails,
      tierNotifier: tierNotifier,
    ),
    if (liveStore == null) gameStateProvider.overrideWith((ref) => Stream.value(state)),
    townsfolkProvider.overrideWithValue(townsfolk),
  ];
}
