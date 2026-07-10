/// The adventure-skin dashboard screen: composes [AdventureDashboard] from the
/// same providers the classic dashboard reads, so both skins show identical
/// numbers. It resolves sprites from `assets/game/` and preloads any referenced
/// custom sprite blobs into memory for the pixelated renderer.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/actions.dart';
import '../data/providers.dart';
import '../features/household_context.dart';
import '../features/spoils/spoils_model.dart';
import '../features/spoils/spoils_screen.dart';
import 'adapter.dart';
import 'adventure_dashboard.dart';
import 'game_sprite.dart';
import '../features/settings/visibility_prefs.dart';

/// Reads every custom sprite blob the current state references (member, quest
/// & pet sprites) into an in-memory `sha256 -> bytes` map for
/// [AssetSpriteResolver]. Missing blobs are simply skipped — the sprite falls
/// back to a placeholder.
final customSpriteBlobsProvider =
    FutureProvider<Map<String, Uint8List>>((ref) async {
  final state = ref.watch(householdStateProvider).value;
  if (state == null) return const {};
  final blobs = ref.watch(blobStoreProvider);
  final shas = <String>{
    for (final m in state.members.values)
      if (m.customSpriteSha256 != null) m.customSpriteSha256!,
    for (final q in state.quests.values)
      if (q.customSpriteSha256 != null) q.customSpriteSha256!,
    for (final p in state.pets.values)
      if (p.customSpriteSha256 != null) p.customSpriteSha256!,
  };
  final out = <String, Uint8List>{};
  for (final sha in shas) {
    if (await blobs.exists(sha)) {
      out[sha] = await blobs.read(sha);
    }
  }
  return out;
});

class AdventureDashboardScreen extends ConsumerWidget {
  const AdventureDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final meUserId = ref.watch(meUserIdProvider);
    final names = ref.watch(userNamesProvider);
    final blobs = ref.watch(customSpriteBlobsProvider).value ?? const {};

    if (state == null || meUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final game = buildGameState(state,
        meUserId: meUserId,
        userNames: names,
        includeOtherAdults: ref.watch(showHouseholdBudgetsProvider));
    final ritual =
        buildSpoilsRitual(state, meUserId: meUserId, userNames: names);
    final banner = ritual == null
        ? null
        : AdventureSpoilsBanner(
            monstersToRecap: ritual.sliceLeftovers.length,
            talliesPending: ritual.variableTallies.length,
            daysRemaining: ritual.daysRemaining,
          );

    final actions = ref.read(householdActionsProvider);
    return AdventureDashboard(
      game: game,
      resolver: AssetSpriteResolver(customBlobs: blobs),
      spoilsBanner: banner,
      callbacks: AdventureCallbacks(
        onOpenSpoils: () => unawaited(openSpoilsRitual(context, ref)),
        onSignWrit: (id) {
          if (actions != null) unawaited(actions.approveWithdrawal(id));
        },
        onDeclineWrit: (id) {
          if (actions != null) unawaited(actions.cancelWithdrawal(id));
        },
      ),
    );
  }
}
