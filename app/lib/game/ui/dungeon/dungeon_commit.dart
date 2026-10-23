/// Finishing the month-end dungeon: the one ledger write (through the shared
/// spoils path), then the cosmetic spoils chest and on-time bonus, then the
/// celebration. Shared by the pixel battle and the text-tier battle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/spoils/spoils_model.dart';
import '../../../features/spoils/spoils_move.dart';
import '../../assets/asset_catalog.dart';
import '../../data/game_providers.dart';
import '../../domain/game_event.dart';
import '../../domain/game_values.dart';
import '../hall_common.dart';
import '../hall_voice.dart';
import 'dungeon_providers.dart';
import 'dungeon_voice.dart';

/// Writes [result] for [ritual] through the spoils writer, then grants the
/// spoils chest and bonus. Returns the game command's result, or null when
/// this device has no game command service yet (the ledger write still
/// happened). Throws when the ledger write fails, before any game event.
///
/// Reads through [container] so it keeps working after the screen that
/// started it has closed.
Future<GameCommandResult?> commitMonthEnd(
  ProviderContainer container,
  SpoilsRitual ritual,
  SpoilsResult result,
) async {
  await container.read(spoilsWriterProvider)(ritual, result);
  final service = container.read(gameCommandsServiceProvider);
  if (service == null) return null;
  final onTimeMonths = await container.read(onTimeRitualMonthsProvider.future);
  return service.finishMonthRitual(ritual.month, onTimeRitualMonths: onTimeMonths);
}

/// The lines celebrating a finished dungeon: the chest, any bonus, or (when
/// the chest was already granted) the friendly "already home" copy.
List<String> monthEndCelebrationLines(
  GameCommandResult? outcome, {
  required DungeonVoice dungeonVoice,
  required HallVoice hallVoice,
  required Object seed,
}) {
  final victory = dungeonVoice.line('victory', seed: seed);
  if (outcome == null) return [victory, 'Your leftovers are divided.'];
  final rejection = outcome.rejection;
  if (rejection != null) return [victory, hallVoice.rejection(rejection)];
  final bonusGems = outcome.events.whereType<RewardGranted>().fold(0, (sum, reward) => sum + reward.gems);
  return [
    victory,
    'A spoils chest waits in your inbox.',
    if (bonusGems > 0) 'Bonus: $bonusGems gems for keeping the ritual going.',
  ];
}

/// Shows the celebration for a finished dungeon.
Future<void> showMonthEndCelebration(
  BuildContext context,
  ProviderContainer container,
  GameCommandResult? outcome, {
  required Object seed,
}) =>
    showHallCelebration(
      context,
      sprite: GameAssetKeys.chest(ChestType.spoils),
      title: 'The spoils are home',
      lines: monthEndCelebrationLines(
        outcome,
        dungeonVoice: container.read(dungeonVoiceProvider).value ?? DungeonVoice.empty,
        hallVoice: container.read(hallVoiceProvider).value ?? HallVoice.empty,
        seed: seed,
      ),
    );

/// Tells the person a save went wrong, without blame.
void showMonthEndSaveFailed(BuildContext context) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text("The spoils couldn't be saved just now. Please try again.")),
    );
