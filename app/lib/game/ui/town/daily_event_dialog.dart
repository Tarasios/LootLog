/// The day's visitor, opened from its figure or tag in the town: the story
/// line, what changes hands, and the choice — `Trade` / `Not today` for a
/// trader, `Collect` for a windfall or a visitor's gift. Waving a visitor
/// off costs nothing. Every choice goes through `resolveDailyEvent`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/asset_registry.dart';
import '../../assets/pack_sprite.dart';
import '../../assets/game_asset_scope.dart' show gameAssetRegistryProvider;
import '../../data/game_providers.dart';
import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/town/town_event_lines.dart';
import '../hall_common.dart';
import '../hall_framed.dart';
import '../hall_ledger_view.dart';
import '../hall_names.dart';
import '../hall_voice.dart';
import '../kit/kit.dart';
import 'town_loop_view.dart';

/// The visitor's picture in the dialog's scene strip (16 px art).
const int _kSceneScale = 5;

class DailyEventDialog extends StatelessWidget {
  const DailyEventDialog({
    super.key,
    required this.offer,
    required this.building,
    required this.lines,
    required this.registry,
    required this.onChoose,
    this.tradeRefusal,
  });

  final DailyOffer offer;
  final BuildingType? building;
  final TownEventLines lines;
  final AssetRegistry registry;

  /// Called with true to take the offer, false to wave it off.
  final void Function(bool accept) onChoose;

  /// Why a trade cannot happen yet (the pool is short), in plain words.
  final String? tradeRefusal;

  bool get _trader => offer.kind == DailyEventKind.trader;

  @override
  Widget build(BuildContext context) {
    final amount = AdventureTokens.amount(context);
    final tradeRefusal = this.tradeRefusal;
    return GameDialog(
      title: lines.visitorTag(offer, building),
      scene: Center(
        child: PackSprite(
          assetKey: visitorAssetKey(offer.kind, registry),
          label: visitorLabel(offer.kind),
          scale: _kSceneScale,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(lines.offerStory(offer, building), style: framedBodyStyle(context)),
          const SizedBox(height: AdventureTokens.gap),
          if (!offer.gives.isEmpty)
            Text('You give: ${HallNames.bundle(offer.gives)}', style: amount),
          Text('You get: ${HallNames.loot(offer.receives)}', style: amount.copyWith(color: AdventureTokens.gainInk)),
          if (_trader && tradeRefusal != null) ...[
            const SizedBox(height: AdventureTokens.gap),
            Text(tradeRefusal, style: framedMutedStyle(context)),
          ],
        ],
      ),
      actions: _trader
          ? [
              WoodButton(label: 'Not today', tone: WoodButtonTone.secondary, onPressed: () => onChoose(false)),
              WoodButton(label: 'Trade', icon: Icons.swap_horiz, onPressed: tradeRefusal == null ? () => onChoose(true) : null),
            ]
          : [
              // Later leaves the visitor waiting in town for today.
              WoodButton(label: 'Later', tone: WoodButtonTone.secondary, onPressed: () => Navigator.of(context).pop()),
              WoodButton(label: 'Collect', icon: Icons.move_to_inbox, onPressed: () => onChoose(true)),
            ],
    );
  }
}

/// Opens today's [offer]; the player's choice resolves it once.
Future<void> showDailyEventDialog(
  BuildContext context,
  WidgetRef ref, {
  required DailyOffer offer,
  required BuildingType? building,
  required TownEventLines lines,
}) async {
  final accept = await showGameDialog<bool>(
    context,
    builder: (dialogContext) => DailyEventDialog(
      offer: offer,
      building: building,
      lines: lines,
      registry: ref.read(gameAssetRegistryProvider).value ?? AssetRegistry.bundled,
      tradeRefusal: tradeRefusal(ref, offer),
      onChoose: (accept) => Navigator.of(dialogContext).pop(accept),
    ),
  );
  if (accept == null || !context.mounted) return;
  await resolveOffer(context, ref, offer, accept: accept);
}

/// Why [offer]'s trade would be refused right now, or null.
String? tradeRefusal(WidgetRef ref, DailyOffer offer) {
  final game = ref.read(gameStateProvider).value ?? GameState.initial();
  final rejection = previewRejection(
    game,
    ref.read(hallLedgerViewProvider).meId,
    ref.read(gameClockProvider),
    (commands) => commands.resolveDailyEvent(offer.offerId, accept: true),
  );
  if (rejection == null) return null;
  final voice = ref.read(hallVoiceProvider).value ?? HallVoice.empty;
  return voice.rejection(rejection);
}

/// Takes ([accept]) or waves off [offer], with a short thank-you on taking.
Future<void> resolveOffer(BuildContext context, WidgetRef ref, DailyOffer offer, {required bool accept}) async {
  final result = await runHallCommand(
    context,
    ref,
    (service) => service.resolveDailyEvent(offer.offerId, accept: accept),
  );
  if (result == null || !result.accepted || !accept || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text('Brought in ${HallNames.loot(offer.receives)}.')),
  );
}
