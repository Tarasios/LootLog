/// One gear slot of the Forge screen: the current piece, the gear types the
/// slot takes, the next tier's cost, why an upgrade can't happen yet, and the
/// button that forges it. Anyone may pay for anyone's gear.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assets/asset_catalog.dart';
import '../config/balance.dart';
import '../data/game_providers.dart';
import '../domain/game_state.dart';
import '../game_sprite.dart';
import 'hall_common.dart';
import 'hall_framed.dart';
import 'hall_names.dart';
import 'hall_voice.dart';
import 'kit/kit.dart';

class ForgeGearSlot extends ConsumerWidget {
  const ForgeGearSlot({
    super.key,
    required this.game,
    required this.heroId,
    required this.hero,
    required this.slot,
    required this.types,
    required this.chosenType,
    required this.onChooseType,
    required this.voice,
    required this.meId,
  });

  final GameState game;
  final String heroId;
  final HeroState hero;

  /// The slot's name ("weapon") and the gear types it accepts.
  final String slot;
  final List<String> types;

  /// The type picked for the next upgrade (null: keep the worn type).
  final String? chosenType;
  final ValueChanged<String> onChooseType;
  final HallVoice voice;

  /// This device's adult, who pays.
  final String? meId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.read(gameClockProvider);
    final current = hero.gear[slot];
    final type = chosenType ?? current?.gearType ?? types.first;
    final next = (current?.tier ?? 0) + 1;
    final atMax = next > Balance.maxGearTier;
    final rejection = atMax
        ? null
        : previewRejection(game, meId, clock,
            (c) => c.upgradeGear(heroId: heroId, slot: slot, gearType: type));
    final text = hallTextTier(context);
    final picture = GameSprite.fromKey(GameAssetKeys.gear(slot, tier: current?.tier),
        label: HallNames.gearSlot(slot), scale: 2);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            current == null
                ? '${HallNames.gearSlot(slot)}: empty'
                : '${HallNames.gearSlot(slot)}: '
                    '${HallNames.gearType(current.gearType)} '
                    'T${current.tier}',
            style: framedBodyStyle(context, weight: FontWeight.w700)),
        if (atMax)
          Text('At its finest.', style: framedMutedStyle(context))
        else ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: AdventureTokens.gap,
            runSpacing: 4,
            children: [
              for (final gearType in types)
                FramedChoice(
                  label: HallNames.gearType(gearType),
                  selected: gearType == type,
                  onSelected: () => onChooseType(gearType),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Tier $next: ${HallNames.cost(Balance.gearCost(slot, next))}',
              style: framedBodyStyle(context)),
          if (rejection != null)
            Text(voice.rejection(rejection), style: framedGateStyle(context)),
          const SizedBox(height: AdventureTokens.gap),
          FramedButton(
            label: 'Forge tier $next',
            onPressed: rejection == null ? () => _forge(context, ref, type, next) : null,
          ),
        ],
      ],
    );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        picture,
        const SizedBox(width: AdventureTokens.gapLarge - 4),
        Expanded(child: details),
      ],
    );
    if (text) {
      return Padding(padding: const EdgeInsets.only(bottom: 12), child: row);
    }
    return InsetWell(key: ValueKey('forge-slot-$slot'), child: row);
  }

  Future<void> _forge(BuildContext context, WidgetRef ref, String type, int tier) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await runHallCommand(
        context, ref, (s) => s.upgradeGear(heroId: heroId, slot: slot, gearType: type));
    if (result != null && result.accepted) {
      messenger?.showSnackBar(
          SnackBar(content: Text('Forged: ${HallNames.gearType(type)} T$tier.')));
    }
  }
}
