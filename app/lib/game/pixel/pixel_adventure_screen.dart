/// The pixel-adventure entry point (tiers 1–2): the dungeon-crawler main screen.
/// Composes [PixelAdventureView] from the same providers the classic dashboard
/// reads — identical numbers — resolving sprites from `assets/game/` and any
/// referenced custom sprite blobs. The global text-mode toggle drops to the
/// text-adventure tier (tier 3); Classic drops to the plain ledger.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../features/entry/expense_entry_screen.dart';
import '../../features/household_context.dart';
import '../../features/spoils/spoils_model.dart';
import '../../features/spoils/spoils_screen.dart';
import '../adapter.dart';
import '../adventure_screen.dart' show customSpriteBlobsProvider;
import '../game_sprite.dart';
import '../skin_prefs.dart';
import '../text_mode/text_adventure_screen.dart' show narrativeProvider;
import 'pixel_adventure_view.dart';

class PixelAdventureScreen extends ConsumerWidget {
  const PixelAdventureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final events = ref.watch(eventLogProvider).value ?? const [];
    final meUserId = ref.watch(meUserIdProvider);
    final names = ref.watch(userNamesProvider);
    final narrative = ref.watch(narrativeProvider).value;
    final blobs = ref.watch(customSpriteBlobsProvider).value ?? const {};

    if (state == null || meUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final game = buildGameState(state, meUserId: meUserId, userNames: names);
    final log = buildAdventureLog(state, events,
        meUserId: meUserId, userNames: names, limit: 40);
    final ritual =
        buildSpoilsRitual(state, meUserId: meUserId, userNames: names);
    final encouragement = (game.heroWounded && narrative != null)
        ? narrative.overspendLine()
        : null;

    final actions = ref.read(householdActionsProvider);
    return PixelAdventureView(
      game: game,
      log: log,
      resolver: AssetSpriteResolver(customBlobs: blobs),
      encouragement: encouragement,
      spoilsPending: ritual != null,
      callbacks: PixelAdventureCallbacks(
        onStrikeMonster: () => ExpenseEntryScreen.open(context),
        onOpenSpoils: () => unawaited(openSpoilsRitual(context, ref)),
        onSwitchToText: () => unawaited(
            ref.read(adventureTierProvider.notifier).select(AdventureTier.text)),
        onSwitchToClassic: () => unawaited(
            ref.read(appSkinProvider.notifier).select(AppSkin.classic)),
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
