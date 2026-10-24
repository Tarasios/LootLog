/// Finishing the month-end dungeon, in two separate phases shared by the
/// pixel battle and the text-tier battle:
///
/// 1. [writeMonthEndLedger]: the one ledger write, through the shared spoils
///    path. A battle calls it at most once: after it succeeds the caller
///    records that and never calls it again for that battle. Ledger events
///    are the permanent audit log, so writing them twice would duplicate
///    them for good.
/// 2. [finishMonthEndGame]: the cosmetic spoils chest and on-time bonus. Its
///    failure is never fatal: the leftovers are already divided. The caller
///    says so and offers to retry this phase alone (`finishMonthRitual` is
///    idempotent: a second success is refused as already finished).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/time.dart';
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

/// Phase 1: writes [result] for [ritual] to the ledger. Throws when the
/// write fails.
///
/// Reads through [container] so it keeps working after the screen that
/// started it has closed.
Future<void> writeMonthEndLedger(ProviderContainer container, SpoilsRitual ritual, SpoilsResult result) =>
    container.read(spoilsWriterProvider)(ritual, result);

/// What the game phase granted.
class MonthEndGameOutcome {
  const MonthEndGameOutcome({required this.result, required this.onTimeRitualMonths});

  /// The game command's result, or null when this device has no game
  /// command service yet (nothing to grant).
  final GameCommandResult? result;

  /// The on-time streak the bonus was computed from.
  final int onTimeRitualMonths;
}

/// Phase 2: grants [month]'s spoils chest and bonus. Throws when reading the
/// on-time streak or appending the game events fails; the ledger is never
/// touched here. The streak is re-read on every attempt, so it includes the
/// ledger write that just happened and a failed read is not cached.
Future<MonthEndGameOutcome> finishMonthEndGame(ProviderContainer container, Month month) async {
  final service = container.read(gameCommandsServiceProvider);
  if (service == null) return const MonthEndGameOutcome(result: null, onTimeRitualMonths: 0);
  final onTimeMonths = await container.refresh(onTimeRitualMonthsProvider.future);
  final result = await service.finishMonthRitual(month, onTimeRitualMonths: onTimeMonths);
  return MonthEndGameOutcome(result: result, onTimeRitualMonths: onTimeMonths);
}

/// The lines celebrating a finished dungeon: the chest, any bonus, or (when
/// the chest was already granted) the friendly "already home" copy.
List<String> monthEndCelebrationLines(
  MonthEndGameOutcome outcome, {
  required DungeonVoice dungeonVoice,
  required HallVoice hallVoice,
  required Object seed,
}) {
  final victory = dungeonVoice.line('victory', seed: seed);
  final result = outcome.result;
  if (result == null) return [victory, dungeonVoice.line('dividedNoChest', seed: seed)];
  final rejection = result.rejection;
  if (rejection != null) return [victory, hallVoice.rejection(rejection)];
  final bonusGems = result.events.whereType<RewardGranted>().fold(0, (sum, reward) => sum + reward.gems);
  return [
    victory,
    dungeonVoice.line('chestWaiting', seed: seed),
    if (bonusGems > 0)
      outcome.onTimeRitualMonths > 0
          ? dungeonVoice.line('bonusOnTime',
              seed: seed, fill: {'gems': '$bonusGems', 'months': '${outcome.onTimeRitualMonths}'})
          : dungeonVoice.line('bonusGear', seed: seed, fill: {'gems': '$bonusGems'}),
  ];
}

/// Shows the celebration for a finished dungeon.
Future<void> showMonthEndCelebration(
  BuildContext context,
  ProviderContainer container,
  MonthEndGameOutcome outcome, {
  required Object seed,
}) =>
    showHallCelebration(
      context,
      sprite: GameAssetKeys.chest(ChestType.spoils),
      title: 'The spoils are home',
      lines: monthEndCelebrationLines(
        outcome,
        dungeonVoice: _dungeonVoice(container),
        hallVoice: container.read(hallVoiceProvider).value ?? HallVoice.empty,
        seed: seed,
      ),
    );

DungeonVoice _dungeonVoice(ProviderContainer container) =>
    container.read(dungeonVoiceProvider).value ?? DungeonVoice.empty;

/// The ledger write failed: nothing to celebrate yet, and no blame.
void showMonthEndSaveFailed(BuildContext context, ProviderContainer container) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(_dungeonVoice(container).line('saveFailed'))),
    );

/// The ledger write succeeded but the chest did not arrive: asks whether to
/// try the chest again. True to retry.
Future<bool> askRetryChest(BuildContext context, ProviderContainer container) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('The leftovers are divided'),
        content: Text(_dungeonVoice(container).line('chestPending'), key: const ValueKey('chest-pending')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Try again')),
        ],
      ),
    ) ??
    false;
