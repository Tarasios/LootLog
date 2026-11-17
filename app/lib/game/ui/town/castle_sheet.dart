/// The Castle sheet, from Castle Hill: the Castle as it stands, how many of
/// its five stages are built (a meter), the stage ladder with each stage's
/// cost and build days, a progress meter for the stage rising now, and for
/// the next stage what is still to gather and a Start button (the real
/// command, dry-run for its gate). Before the city it only shows the
/// promise.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/theme.dart';
import '../../assets/asset_catalog.dart';
import '../../assets/pack_sprite.dart';
import '../../config/balance.dart';
import '../../data/game_providers.dart';
import '../../domain/content.dart';
import '../../domain/game_state.dart';
import '../../domain/town/long_road_book.dart';
import '../../domain/town/town_growth_lines.dart';
import '../hall_common.dart';
import '../hall_framed.dart';
import '../hall_ledger_view.dart';
import '../hall_names.dart';
import '../hall_voice.dart';
import '../kit/kit.dart';
import 'long_road_ui.dart';
import 'town_growth_providers.dart';
import 'town_loop_view.dart' show fillLine;

/// Opens the Castle sheet.
Future<void> showCastleSheet(BuildContext context) => showLongRoadSheet(context, const CastleSheet());

class CastleSheet extends ConsumerWidget {
  const CastleSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = hallGameState(ref);
    final meId = ref.watch(hallLedgerViewProvider).meId ?? '';
    final clock = ref.watch(gameClockProvider);
    final lines = ref.watch(townGrowthLinesProvider).value ?? TownGrowthLines.defaults;
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    return HallTicker(builder: (context) {
      final now = clock.now();
      final book = longRoadBook(game, meId, now);
      final stages = Balance.castleStages.length;
      final children = <Widget>[
        if (!book.castleOpen)
          Text(lines.line('castle.teaser'), style: framedBodyStyle(context))
        else ...[
          Text(fillLine(lines.line('castle.progress'), {'count': '${book.castleStagesDone}'}),
              key: const ValueKey('castle-progress'), style: framedBodyStyle(context, weight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          FramedMeter(book.castleStagesDone / stages, color: AdventureTokens.gold, semanticsLabel: 'Castle stages'),
          const SizedBox(height: AppSpacing.md),
          if (book.castleComplete)
            Text(lines.line('castle.complete'), style: framedBodyStyle(context))
          else if (book.castleBuilding)
            _rising(context, game, meId, book, now, lines)
          else
            _next(context, ref, game, meId, book, lines, voice),
        ],
        const SizedBox(height: AppSpacing.md),
        _ladder(context, book, lines),
      ];
      return longRoadSheetFrame(
        context,
        title: lines.line('castle.title'),
        picture: PackSprite(assetKey: GameAssetKeys.castleStage(book.castleStagesDone), scale: 1),
        children: children,
      );
    });
  }

  /// The stage rising now, with its meter.
  Widget _rising(BuildContext context, GameState game, String meId, LongRoadBook book, DateTime now, TownGrowthLines lines) {
    final record = game.townOf(meId).castle.stages.last;
    final name = lines.line(castleStageNameKey(record.key));
    final total = record.completesAt.difference(record.startedAt).inSeconds;
    final left = record.completesAt.difference(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(fillLine(lines.line('castle.building'), {'stage': name, 'time': 'in ${HallNames.duration(left)}'}),
            style: framedBodyStyle(context)),
        const SizedBox(height: AppSpacing.xs),
        FramedMeter(total <= 0 ? 1 : 1 - left.inSeconds / total, key: const ValueKey('castle-stage-meter'),
            semanticsLabel: 'The $name'),
      ],
    );
  }

  /// The next stage: what is still to gather, and Start.
  Widget _next(BuildContext context, WidgetRef ref, GameState game, String meId, LongRoadBook book,
      TownGrowthLines lines, HallVoice voice) {
    final spec = Balance.castleStages[book.castleNextStage - 1];
    final name = lines.line(castleStageNameKey(spec.key));
    final missing = _missing(game, meId, spec, lines);
    final rejection = previewRejection(game, meId, ref.read(gameClockProvider), (commands) => commands.startCastleStage());
    return FramedSection(
      title: fillLine(lines.line('castle.next'), {'stage': name}),
      icon: Icons.fort,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoodsCostLine(cost: spec.cost, goods: spec.goods, lines: lines),
          Text('Build time: ${spec.buildDays} days', style: framedBodyStyle(context)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            missing.isEmpty ? lines.line('castle.ready') : fillLine(lines.line('castle.missing'), {'items': missing.join(', ')}),
            key: const ValueKey('castle-missing'),
            style: missing.isEmpty ? framedBodyStyle(context) : framedMutedStyle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          gateLine(context, voice, missing.isEmpty ? rejection : null),
          sheetButton('Start the $name', rejection == null ? () => _start(context, ref, spec, lines) : null,
              key: const ValueKey('castle-start')),
        ],
      ),
    );
  }

  /// What [spec] still wants beyond what the town holds, in words.
  List<String> _missing(GameState game, String meId, CastleStageSpec spec, TownGrowthLines lines) {
    final gems = game.person(meId).gems;
    final town = game.townOf(meId);
    return [
      if (spec.cost.gems > gems) HallNames.gems(spec.cost.gems - gems),
      for (final MapEntry(key: kind, value: amount) in spec.cost.materials.amounts.entries)
        if (amount > town.materials[kind]) '${amount - town.materials[kind]} ${HallNames.material(kind)}',
      for (final MapEntry(key: kind, value: amount) in spec.goods.amounts.entries)
        if (amount > town.goods.stored[kind]) '${amount - town.goods.stored[kind]} ${lines.line(goodsNameKey(kind))}',
    ];
  }

  /// Every stage, built or to come, with its cost and build days.
  Widget _ladder(BuildContext context, LongRoadBook book, TownGrowthLines lines) => FramedSection(
        title: 'Stages',
        icon: Icons.stairs,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, spec) in Balance.castleStages.indexed)
              _stageRow(context, index + 1, spec, book, lines),
          ],
        ),
      );

  Widget _stageRow(BuildContext context, int stage, CastleStageSpec spec, LongRoadBook book, TownGrowthLines lines) {
    final built = stage <= book.castleStagesDone;
    final rising = book.castleBuilding && stage == book.castleNextStage;
    return Padding(
      key: ValueKey('castle-stage-$stage'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            built ? Icons.check_circle : (rising ? Icons.construction : Icons.radio_button_unchecked),
            size: 18,
            color: built ? AdventureTokens.gainInk : AdventureTokens.inkMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$stage. ${lines.line(castleStageNameKey(spec.key))}',
                    style: framedBodyStyle(context, weight: FontWeight.w700)),
                if (!built) ...[
                  GoodsCostLine(cost: spec.cost, goods: spec.goods, lines: lines),
                  Text('${spec.buildDays} days', style: framedMutedStyle(context)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref, CastleStageSpec spec, TownGrowthLines lines) async {
    final result = await runHallCommand(context, ref, (service) => service.startCastleStage());
    if (result == null || !result.accepted || !context.mounted) return;
    toastLine(context, fillLine(lines.line('castle.started'), {
      'stage': lines.line(castleStageNameKey(spec.key)),
      'time': '${spec.buildDays} days',
    }));
  }
}
