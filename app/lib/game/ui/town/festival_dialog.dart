/// The weekend festival's celebration, on the first town visit of the
/// weekend: the festival's name on the ribbon, its line, and its gifts —
/// already granted by the rules as rewards in the inbox, so `Claim` takes
/// them through the ordinary claim command and nothing new is granted here.
/// A market day is just as cheerful as a grand festival.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/reason_codes.dart';
import '../../domain/town/festival.dart';
import '../../domain/town/town_event_lines.dart';
import '../hall_common.dart';
import '../hall_framed.dart';
import '../hall_names.dart';
import '../kit/kit.dart';
import 'pennant_strip.dart';
import 'town_loop_view.dart';

class FestivalDialog extends StatelessWidget {
  const FestivalDialog({
    super.key,
    required this.tier,
    required this.rewards,
    required this.lines,
    required this.onClaim,
    required this.onClose,
  });

  final FestivalTier tier;

  /// The festival's gifts still in the inbox (the joint bonus included).
  final List<PendingReward> rewards;
  final TownEventLines lines;
  final VoidCallback onClaim;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final joint = rewards.any((reward) => reward.reasonCode == GameReasonCodes.festivalJoint);
    final total = rewards.fold(
      Loot.none,
      (sum, reward) => Loot(
        gems: sum.gems + reward.loot.gems,
        materials: sum.materials + reward.loot.materials,
        tokens: sum.tokens + reward.loot.tokens,
      ),
    );
    return GameDialog(
      title: capitalised(lines.festivalName(tier)),
      onClose: onClose,
      scene: PennantStrip(rows: tier.index + 1),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(lines.line(festivalFlavourKey(tier)), style: framedBodyStyle(context)),
          if (joint) ...[
            const SizedBox(height: AdventureTokens.gap),
            Text(lines.line(kJointFestivalFlavourKey), style: framedBodyStyle(context)),
          ],
          const SizedBox(height: AdventureTokens.gap),
          Text(
            rewards.isEmpty
                ? lines.line('festival.claimed')
                : fillLine(lines.line('festival.reward'), {'reward': HallNames.loot(total)}),
            style: AdventureTokens.amount(context).copyWith(color: AdventureTokens.gainInk),
          ),
        ],
      ),
      actions: rewards.isEmpty
          ? [WoodButton(label: 'Hooray!', onPressed: onClose)]
          : [
              WoodButton(label: 'Later', tone: WoodButtonTone.secondary, onPressed: onClose),
              WoodButton(label: 'Claim', icon: Icons.celebration, onPressed: onClaim),
            ],
    );
  }
}

/// Celebrates today's festival; `Claim` claims each waiting gift once.
Future<void> showFestivalDialog(
  BuildContext context,
  WidgetRef ref, {
  required FestivalTier tier,
  required List<PendingReward> rewards,
  required TownEventLines lines,
}) async {
  final claim = await showGameDialog<bool>(
    context,
    builder: (dialogContext) => FestivalDialog(
      tier: tier,
      rewards: rewards,
      lines: lines,
      onClaim: () => Navigator.of(dialogContext).pop(true),
      onClose: () => Navigator.of(dialogContext).pop(false),
    ),
  );
  if (claim != true || !context.mounted) return;
  await claimFestivalGifts(context, ref, rewards);
}

/// Claims [rewards] through the ordinary claim command.
Future<void> claimFestivalGifts(BuildContext context, WidgetRef ref, List<PendingReward> rewards) async {
  for (final reward in rewards) {
    if (!context.mounted) return;
    await runHallCommand(context, ref, (service) => service.claimReward(reward.rewardId));
  }
}
