/// The town loop in the guild-hall home (the text tier's town): what the
/// crews made while you were away with `Collect all`, the day's visitor with
/// its choice, the week's town spirit, and the weekend festival with `Claim`
/// — the same features the pixel town shows, as plain sections and buttons.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/theme.dart';
import '../../domain/game_values.dart';
import '../../domain/town/festival.dart';
import '../../domain/town/town_event_lines.dart';
import '../hall_common.dart';
import '../hall_home_sections.dart' show HallHomeData;
import '../hall_names.dart';
import 'away_summary_dialog.dart' show collectAll;
import 'daily_event_dialog.dart' show resolveOffer, tradeRefusal;
import 'festival_dialog.dart' show claimFestivalGifts;
import 'town_loop_providers.dart';
import 'town_loop_view.dart';

class TownLoopPanel extends ConsumerWidget {
  const TownLoopPanel(this.data, {super.key});

  final HallHomeData data;

  static const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meId = data.view.meId;
    if (meId == null || meId.isEmpty) return const SizedBox.shrink();
    final lines = ref.watch(townEventLinesProvider).value ?? TownEventLines.defaults;
    final view = TownLoopView.from(data.game, meId, data.now);
    final body = hallBodyStyle(context);
    final heading = hallBodyStyle(context, weight: FontWeight.w700);
    final muted = hallMutedStyle(context);
    const gap = SizedBox(height: AppSpacing.md);
    final away = view.away;
    final offer = view.offer;
    final festival = view.festival;
    final refusal = offer != null && offer.kind == DailyEventKind.trader ? tradeRefusal(ref, offer) : null;
    return HallSection(
      title: 'The town today',
      icon: Icons.holiday_village_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!away.isEmpty) ...[
            Text(lines.line('away.title'), style: heading),
            for (final row in away.producers)
              Text(
                '${HallNames.building(row.type)}: '
                '${row.storehouseFull ? lines.line('away.storehouseFull') : '+${HallNames.bundle(row.fits)}'}',
                style: body,
              ),
            Text(lines.shiftNote(quietDays: away.quietDays, todayLogged: away.todayLogged), style: muted),
            OutlinedButton.icon(
              onPressed: away.producers.every((row) => row.storehouseFull)
                  ? null
                  : () => unawaited(collectAll(context, ref, away)),
              icon: const Icon(Icons.move_to_inbox),
              label: const Text('Collect all'),
            ),
            gap,
          ],
          if (offer != null) ...[
            Text(lines.visitorTag(offer, view.offerBuilding), style: heading),
            Text(lines.offerStory(offer, view.offerBuilding), style: body),
            if (!offer.gives.isEmpty) Text('You give: ${HallNames.bundle(offer.gives)}', style: body),
            Text('You get: ${HallNames.loot(offer.receives)}', style: body),
            if (refusal != null) Text(refusal, style: muted),
            Wrap(
              spacing: AppSpacing.sm,
              children: offer.kind == DailyEventKind.trader
                  ? [
                      OutlinedButton(
                        onPressed: refusal == null
                            ? () => unawaited(resolveOffer(context, ref, offer, accept: true))
                            : null,
                        child: const Text('Trade'),
                      ),
                      TextButton(
                        onPressed: () => unawaited(resolveOffer(context, ref, offer, accept: false)),
                        child: const Text('Not today'),
                      ),
                    ]
                  : [
                      OutlinedButton(
                        onPressed: () => unawaited(resolveOffer(context, ref, offer, accept: true)),
                        child: const Text('Collect'),
                      ),
                    ],
            ),
            gap,
          ] else if (!view.dayOpened) ...[
            Text(lines.line('tag.openTown'), style: muted),
            gap,
          ],
          Text(lines.line('spirit.title'), style: heading),
          Text(
            [
              for (final (index, logged) in view.spiritDays.indexed) '${_weekdays[index]} ${logged ? '■' : '□'}',
              'Festival ${view.weekend ? '⚑' : '·'}',
            ].join('  '),
            style: body,
          ),
          for (final line in lines.spiritLines(view)) Text(line, style: muted),
          if (festival != null) ...[
            gap,
            Text(capitalised(lines.festivalName(festival)), style: heading),
            Text(lines.line(festivalFlavourKey(festival)), style: body),
            if (view.festivalRewards.isEmpty)
              Text(lines.line('festival.claimed'), style: muted)
            else
              OutlinedButton.icon(
                onPressed: () => unawaited(claimFestivalGifts(context, ref, view.festivalRewards)),
                icon: const Icon(Icons.celebration),
                label: Text(
                  'Claim ${HallNames.loot(view.festivalRewards.map((reward) => reward.loot).reduce(_add))}',
                ),
              ),
          ],
        ],
      ),
    );
  }

  static Loot _add(Loot first, Loot second) => Loot(
    gems: first.gems + second.gems,
    materials: first.materials + second.materials,
    tokens: first.tokens + second.tokens,
  );
}
