/// Expeditions: send the hero to a region, watch the countdown, and bring
/// them home to hear the stored report and bank the loot. Regions open as the
/// Central Hall grows; a locked region says exactly what opens it. Materials
/// from expeditions never depend on logging (rule 10).
///
/// Framed in the pixel tier (wood board, parchment cards, a meter for the
/// trip); the text tier keeps its text panels.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assets/asset_catalog.dart';
import '../config/balance.dart';
import '../data/game_providers.dart';
import '../domain/game_event.dart';
import '../domain/game_values.dart';
import 'expedition_region_card.dart';
import 'hall_common.dart';
import 'hall_framed.dart';
import 'hall_ledger_view.dart';
import 'hall_names.dart';
import 'hall_resource_chips.dart';
import 'hall_voice.dart';
import 'kit/kit.dart';

class ExpeditionsScreen extends ConsumerWidget {
  const ExpeditionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = hallGameState(ref);
    final view = ref.watch(hallLedgerViewProvider);
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    final clock = ref.watch(gameClockProvider);
    return HallTicker(builder: (context) {
      final now = clock.now();
      final me = game.person(view.meId ?? '');
      final trip = me.activeExpedition;
      final hallTier = game.hall.completedTier(BuildingType.centralHall, now);
      final report = me.lastExpedition;
      final compact = MediaQuery.sizeOf(context).width < AdventureTokens.narrowScreen;
      return FramedHallScreen(
        title: 'Expeditions',
        trailing: [storesChip(game.hall.materials, compact: compact)],
        children: [
          FramedSection(
            title: 'The road',
            icon: Icons.explore_outlined,
            child: trip == null
                ? Text(
                    'The hero is home and ready to travel. Hero power '
                    '${me.hero.power} adds to every find.',
                    style: framedBodyStyle(context))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Away in ${HallNames.region(trip.region)}',
                          style: framedBodyStyle(context, weight: FontWeight.w700)),
                      const SizedBox(height: AdventureTokens.gap / 2),
                      if (now.isBefore(trip.endsAt)) ...[
                        FramedMeter(
                          now.difference(trip.startedAt).inSeconds / (trip.durationMinutes * 60),
                          color: AdventureTokens.hpBlue,
                          semanticsLabel: 'Trip progress',
                        ),
                        const SizedBox(height: 4),
                        Text(
                            'Back in '
                            '${HallNames.duration(trip.endsAt.difference(now))}',
                            style: framedMutedStyle(context)),
                      ] else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FramedButton(
                            label: 'Welcome the hero home',
                            onPressed: () => _resolve(context, ref),
                          ),
                        ),
                    ],
                  ),
          ),
          if (report != null)
            FramedSection(
              title: 'Last report — ${HallNames.region(report.region)}',
              icon: Icons.history_edu_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in report.reportLines)
                    Text(line, style: framedBodyStyle(context)),
                ],
              ),
            ),
          FramedGrid(
            children: [
              for (final region in ExpeditionRegion.values)
                ExpeditionRegionCard(
                  region: region,
                  unlocked: hallTier >= Balance.regions[region]!.minHallTier,
                  rejection: previewRejection(
                      game, view.meId, clock, (c) => c.startExpedition(region)),
                  voice: voice,
                  onSend: () async {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    final result = await runHallCommand(
                        context, ref, (s) => s.startExpedition(region));
                    if (result != null && result.accepted) {
                      messenger?.showSnackBar(SnackBar(
                          content: Text(voice.line('expeditionSent',
                              seed: result.events.first.eventId,
                              fill: {'region': HallNames.regionInSentence(region)}))));
                    }
                  },
                ),
            ],
          ),
        ],
      );
    });
  }

  Future<void> _resolve(BuildContext context, WidgetRef ref) async {
    final result = await runHallCommand(context, ref, (s) => s.resolveExpedition());
    if (result == null || !result.accepted || !context.mounted) return;
    final resolved = result.events.whereType<ExpeditionResolved>().firstOrNull;
    if (resolved == null) return;
    await showHallCelebration(
      context,
      sprite: GameAssetKeys.region(resolved.region),
      title: 'The hero is home!',
      lines: [
        ...resolved.reportLines,
        if (!resolved.loot.isEmpty)
          'Added to the stores: ${HallNames.bundle(resolved.loot)}.',
      ],
    );
  }
}
