/// Expeditions: send the hero to a region, watch the countdown, and bring
/// them home to hear the stored report and bank the loot. Regions open as the
/// Central Hall grows; a locked region says exactly what opens it. Materials
/// from expeditions never depend on logging (rule 10).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme.dart';
import '../assets/asset_catalog.dart';
import '../config/balance.dart';
import '../data/game_providers.dart';
import '../domain/game_event.dart';
import '../domain/game_values.dart';
import '../game_sprite.dart';
import 'hall_common.dart';
import 'hall_ledger_view.dart';
import 'hall_names.dart';
import 'hall_voice.dart';

class ExpeditionsScreen extends ConsumerWidget {
  const ExpeditionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = hallGameState(ref);
    final view = ref.watch(hallLedgerViewProvider);
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    final clock = ref.watch(gameClockProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Expeditions')),
      body: HallTicker(builder: (context) {
        final now = clock.now();
        final me = game.person(view.meId ?? '');
        final trip = me.activeExpedition;
        final hallTier = game.hall.completedTier(BuildingType.centralHall, now);
        final report = me.lastExpedition;
        return HallPage(children: [
          HallSection(
            title: 'The road',
            icon: Icons.explore_outlined,
            child: trip == null
                ? Text(
                    'The hero is home and ready to travel. Hero power '
                    '${me.hero.power} adds to every find.',
                    style: hallBodyStyle(context))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Away in ${HallNames.region(trip.region)}',
                          style: hallBodyStyle(context, weight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.xs),
                      if (now.isBefore(trip.endsAt)) ...[
                        HallBar(now.difference(trip.startedAt).inSeconds /
                            (trip.durationMinutes * 60)),
                        Text(
                            'Back in '
                            '${HallNames.duration(trip.endsAt.difference(now))}',
                            style: hallMutedStyle(context)),
                      ] else
                        FilledButton.icon(
                          onPressed: () => _resolve(context, ref),
                          icon: const Icon(Icons.home_outlined),
                          label: const Text('Welcome the hero home'),
                        ),
                    ],
                  ),
          ),
          if (report != null)
            HallSection(
              title: 'Last report — ${HallNames.region(report.region)}',
              icon: Icons.history_edu_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in report.reportLines)
                    Text(l, style: hallBodyStyle(context)),
                ],
              ),
            ),
          for (final r in ExpeditionRegion.values)
            _RegionCard(
              region: r,
              unlocked: hallTier >= Balance.regions[r]!.minHallTier,
              rejection: previewRejection(
                  game, view.meId, clock, (c) => c.startExpedition(r)),
              voice: voice,
              onSend: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                final res =
                    await runHallCommand(context, ref, (s) => s.startExpedition(r));
                if (res != null && res.accepted) {
                  messenger?.showSnackBar(SnackBar(
                      content: Text(voice.line('expeditionSent',
                          seed: res.events.first.eventId,
                          fill: {'region': HallNames.regionInSentence(r)}))));
                }
              },
            ),
        ]);
      }),
    );
  }

  Future<void> _resolve(BuildContext context, WidgetRef ref) async {
    final r = await runHallCommand(context, ref, (s) => s.resolveExpedition());
    if (r == null || !r.accepted || !context.mounted) return;
    final resolved = r.events.whereType<ExpeditionResolved>().firstOrNull;
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

class _RegionCard extends StatelessWidget {
  const _RegionCard({
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
    final finds = [for (final l in spec.loot) HallNames.material(l.kind)];
    return HallSection(
      title: HallNames.region(region),
      icon: unlocked ? Icons.map_outlined : Icons.lock_outline,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GameSprite.fromKey(GameAssetKeys.region(region),
              label: HallNames.region(region), scale: 2),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(HallNames.regionBlurb(region),
                    style: hallMutedStyle(context)),
                Text(
                    'Trip: ${HallNames.duration(Duration(minutes: spec.durationMinutes))}'
                    ' · finds ${finds.join(', ')}',
                    style: hallBodyStyle(context)),
                if (!unlocked)
                  Text(
                      'Opens when the Central Hall reaches tier '
                      '${spec.minHallTier}.',
                      style: hallBodyStyle(context,
                          color: Theme.of(context).colorScheme.tertiary))
                else if (rejection != null)
                  Text(voice.rejection(rejection!),
                      style: hallMutedStyle(context)),
                const SizedBox(height: AppSpacing.xs),
                FilledButton.tonal(
                  onPressed: rejection == null ? onSend : null,
                  child: const Text('Send the hero'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
