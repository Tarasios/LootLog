/// One region of the Expeditions screen: its picture, what it is, how long
/// the trip takes and what it finds, and the button that sends the hero (or
/// what stands in the way).
library;

import 'package:flutter/material.dart';

import '../assets/asset_catalog.dart';
import '../config/balance.dart';
import '../domain/commands/game_commands.dart' show GameRejection;
import '../domain/game_values.dart';
import '../game_sprite.dart';
import 'hall_common.dart';
import 'hall_framed.dart';
import 'hall_names.dart';
import 'hall_voice.dart';
import 'kit/kit.dart';

class ExpeditionRegionCard extends StatelessWidget {
  const ExpeditionRegionCard({
    super.key,
    required this.region,
    required this.unlocked,
    required this.rejection,
    required this.voice,
    required this.onSend,
  });

  final ExpeditionRegion region;
  final bool unlocked;
  final GameRejection? rejection;
  final HallVoice voice;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final spec = Balance.regions[region]!;
    final finds = [for (final line in spec.loot) HallNames.material(line.kind)];
    final picture = GameSprite.fromKey(GameAssetKeys.region(region),
        label: HallNames.region(region), scale: 2);
    return FramedSection(
      key: ValueKey('region-${region.name}'),
      title: HallNames.region(region),
      icon: unlocked ? Icons.map_outlined : Icons.lock_outline,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          hallTextTier(context)
              ? picture
              : InsetWell(padding: const EdgeInsets.all(4), child: picture),
          const SizedBox(width: AdventureTokens.gapLarge - 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(HallNames.regionBlurb(region), style: framedMutedStyle(context)),
                Text(
                    'Trip: ${HallNames.duration(Duration(minutes: spec.durationMinutes))}'
                    ' · finds ${finds.join(', ')}',
                    style: framedBodyStyle(context)),
                if (!unlocked)
                  Text(
                      'Opens when the Central Hall reaches tier '
                      '${spec.minHallTier}.',
                      style: framedGateStyle(context))
                else if (rejection != null)
                  Text(voice.rejection(rejection!), style: framedMutedStyle(context)),
                const SizedBox(height: AdventureTokens.gap),
                FramedButton(
                  label: 'Send the hero',
                  onPressed: rejection == null ? onSend : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
