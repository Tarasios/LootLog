/// "While you were away": the summary the HUD's "crews made" chip opens
/// when the crews have made something (it never opens by itself, so it
/// never stands between the player and Log purchase). One row per
/// producer (its picture, its name, what it made), a line on how the crews
/// worked, and `Collect all` — one collection per producer — or `Later`.
/// Collecting is never gated; a full Storehouse row just says so.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/asset_catalog.dart';
import '../../assets/pack_sprite.dart';
import '../../domain/game_values.dart';
import '../../domain/town/away_summary.dart';
import '../../domain/town/town_event_lines.dart';
import '../hall_common.dart';
import '../hall_framed.dart';
import '../hall_names.dart';
import '../kit/kit.dart';
import 'town_loop_view.dart';

class AwaySummaryDialog extends StatelessWidget {
  const AwaySummaryDialog({
    super.key,
    required this.summary,
    required this.lines,
    required this.onCollectAll,
    required this.onLater,
  });

  final AwaySummary summary;
  final TownEventLines lines;
  final VoidCallback onCollectAll;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final anythingFits = summary.producers.any((row) => !row.storehouseFull);
    return GameDialog(
      // The ribbon is short on a phone: the welcome rides it, and the
      // summary's own heading opens the body.
      title: lines.line('away.welcome'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(lines.line('away.title'), style: AdventureTokens.label(context)),
          const SizedBox(height: AdventureTokens.gap),
          for (final row in summary.producers) _ProducerRow(row: row, lines: lines),
          const SizedBox(height: AdventureTokens.gap),
          Text(
            lines.shiftNote(quietDays: summary.quietDays, todayLogged: summary.todayLogged),
            key: const ValueKey('away-shift-note'),
            style: framedMutedStyle(context),
          ),
        ],
      ),
      actions: [
        WoodButton(
          label: 'Later',
          tone: WoodButtonTone.secondary,
          onPressed: onLater,
        ),
        WoodButton(
          label: 'Collect all',
          icon: Icons.move_to_inbox,
          onPressed: anythingFits ? onCollectAll : null,
        ),
      ],
    );
  }
}

class _ProducerRow extends StatelessWidget {
  const _ProducerRow({required this.row, required this.lines});

  final AwayProducer row;
  final TownEventLines lines;

  @override
  Widget build(BuildContext context) {
    final name = HallNames.building(row.type);
    final amount = AdventureTokens.amount(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          PackSprite(assetKey: GameAssetKeys.building(row.type, 1), label: name, scale: 1),
          const SizedBox(width: AdventureTokens.gap),
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AdventureTokens.label(context)),
          ),
          const SizedBox(width: AdventureTokens.gap),
          if (row.storehouseFull)
            Text(lines.line('away.storehouseFull'), style: framedMutedStyle(context))
          else
            Flexible(
              child: Text(
                [for (final entry in row.fits.amounts.entries) '+${entry.value} ${HallNames.material(entry.key)}']
                    .join(', '),
                textAlign: TextAlign.end,
                style: amount.copyWith(color: AdventureTokens.gainInk),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows the summary; `Collect all` banks every producer that has room, one
/// collection each, and says what came in.
Future<void> showAwaySummary(
  BuildContext context,
  WidgetRef ref, {
  required AwaySummary summary,
  required TownEventLines lines,
}) async {
  final collect = await showGameDialog<bool>(
    context,
    builder: (dialogContext) => AwaySummaryDialog(
      summary: summary,
      lines: lines,
      onCollectAll: () => Navigator.of(dialogContext).pop(true),
      onLater: () => Navigator.of(dialogContext).pop(false),
    ),
  );
  if (collect != true || !context.mounted) return;
  await collectAll(context, ref, summary);
}

/// Collects each producer in [summary] that has room in the Storehouse.
Future<void> collectAll(BuildContext context, WidgetRef ref, AwaySummary summary) async {
  var banked = const MaterialBundle.empty();
  for (final row in summary.producers) {
    if (row.storehouseFull || !context.mounted) continue;
    final result = await runHallCommand(context, ref, (service) => service.collectMaterials(row.plotIndex));
    if (result != null && result.accepted) banked += row.fits;
  }
  if (banked.isEmpty || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text('Collected ${HallNames.bundle(banked)}.')),
  );
}
