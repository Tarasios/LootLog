/// The workshop: what the town's workshops are making and what is ready
/// (a progress meter for each job, and Collect), and a new job: pick a
/// recipe and a batch count, see what it takes, what it makes and how long,
/// then Start. Every gate is the real command dry-run. Shown inside a
/// workshop's plot sheet and as the workshop sheet on its own (from the
/// town book and the text tier).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/theme.dart';
import '../../assets/asset_catalog.dart';
import '../../assets/pack_sprite.dart';
import '../../config/balance.dart';
import '../../data/game_providers.dart';
import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/town/goods.dart';
import '../../domain/town/town_growth_lines.dart';
import '../hall_common.dart';
import '../hall_framed.dart';
import '../hall_ledger_view.dart';
import '../hall_names.dart';
import '../hall_voice.dart';
import 'long_road_ui.dart';
import 'town_growth_providers.dart';
import 'town_loop_view.dart' show fillLine;

/// Opens the workshop sheet (every workshop's jobs and a new job).
Future<void> showWorkshopSheet(BuildContext context) => showLongRoadSheet(context, const WorkshopSheet());

class WorkshopSheet extends ConsumerWidget {
  const WorkshopSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(townGrowthLinesProvider).value ?? TownGrowthLines.defaults;
    return longRoadSheetFrame(
      context,
      title: lines.line('refine.title'),
      picture: PackSprite(assetKey: GameAssetKeys.civicBuilding(CivicBuildingType.workshop, 3), scale: 2),
      children: const [WorkshopPanel()],
    );
  }
}

class WorkshopPanel extends ConsumerStatefulWidget {
  const WorkshopPanel({super.key});

  @override
  ConsumerState<WorkshopPanel> createState() => _WorkshopPanelState();
}

class _WorkshopPanelState extends ConsumerState<WorkshopPanel> {
  String _recipeId = Balance.refiningRecipes.keys.first;
  int _batches = 1;

  @override
  Widget build(BuildContext context) {
    final game = hallGameState(ref);
    final meId = ref.watch(hallLedgerViewProvider).meId;
    final clock = ref.watch(gameClockProvider);
    final lines = ref.watch(townGrowthLinesProvider).value ?? TownGrowthLines.defaults;
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    return HallTicker(builder: (context) {
      final now = clock.now();
      final town = game.townOf(meId ?? '');
      final workshops = workshopsAt(town, now);
      if (workshops.isEmpty) {
        return Text(lines.line('refine.noWorkshop'), style: framedBodyStyle(context));
      }
      final jobs = [
        for (final workshop in workshops) ?town.goods.jobs[workshop.address],
      ];
      final idle = [
        for (final workshop in workshops)
          if (!town.goods.jobs.containsKey(workshop.address)) workshop,
      ];
      final anyDone = jobs.any((job) => job.isDoneAt(now));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final job in jobs) _jobRow(job, now, lines),
          if (anyDone)
            commandButton(
              'Collect',
              previewRejection(game, meId, clock, (commands) => commands.collectGoods()) == null ? _collect : null,
              key: const ValueKey('workshop-collect'),
            ),
          if (jobs.isNotEmpty) const SizedBox(height: AppSpacing.md),
          if (idle.isEmpty)
            Text(lines.line('refine.allBusy'), style: framedMutedStyle(context))
          else
            _newJob(context, lines, voice, maxBatches: workshopMaxBatches(idle.first.tier), preview: (recipeId, batches) =>
                previewRejection(game, meId, clock, (commands) => commands.startRefining(recipeId, batches))),
        ],
      );
    });
  }

  /// One job: at work with its meter, or ready to collect.
  Widget _jobRow(RefiningJob job, DateTime now, TownGrowthLines lines) {
    final goods = goodsText(job.output, lines);
    if (job.isDoneAt(now)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(fillLine(lines.line('refine.ready'), {'goods': goods}),
            style: framedBodyStyle(context, weight: FontWeight.w700)),
      );
    }
    final total = job.completesAt.difference(job.startedAt).inSeconds;
    final left = job.completesAt.difference(now);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(fillLine(lines.line('refine.working'), {'goods': goods, 'time': 'in ${HallNames.duration(left)}'}),
              style: framedBodyStyle(context)),
          const SizedBox(height: AppSpacing.xs),
          FramedMeter(total <= 0 ? 1 : 1 - left.inSeconds / total, semanticsLabel: 'Workshop job'),
        ],
      ),
    );
  }

  /// A new job: the recipe, the batch count, what it takes and makes.
  Widget _newJob(
    BuildContext context,
    TownGrowthLines lines,
    HallVoice voice, {
    required int maxBatches,
    required GameRejection? Function(String recipeId, int batches) preview,
  }) {
    final batches = _batches.clamp(1, maxBatches);
    final recipe = refiningRecipe(_recipeId)!;
    final output = GoodsBundle({recipe.output: recipe.outputPerBatch * batches});
    final rejection = preview(_recipeId, batches);
    return FramedSection(
      title: lines.line('refine.choose'),
      icon: Icons.handyman,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final MapEntry(key: id, value: option) in Balance.refiningRecipes.entries)
                FramedChoice(
                  key: ValueKey('recipe-$id'),
                  label: lines.line(goodsNameKey(option.output)),
                  selected: id == _recipeId,
                  onSelected: () => setState(() => _recipeId = id),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text('Batches', style: framedBodyStyle(context)),
              const Spacer(),
              IconButton(
                key: const ValueKey('batches-less'),
                tooltip: 'Fewer batches',
                onPressed: batches > 1 ? () => setState(() => _batches = batches - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              Text('$batches', key: const ValueKey('batches-count'), style: framedBodyStyle(context, weight: FontWeight.w800)),
              IconButton(
                key: const ValueKey('batches-more'),
                tooltip: 'More batches',
                onPressed: batches < maxBatches ? () => setState(() => _batches = batches + 1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Text(fillLine(lines.line('refine.takes'), {'materials': HallNames.bundle(recipe.input.scaled(batches))}),
              style: framedBodyStyle(context)),
          Text(
            fillLine(lines.line('refine.makes'), {
              'goods': goodsText(output, lines),
              'time': HallNames.duration(Duration(minutes: recipe.minutesPerBatch * batches)),
            }),
            style: framedBodyStyle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          gateLine(context, voice, rejection),
          commandButton('Start', rejection == null ? () => _start(batches, output, lines) : null,
              key: const ValueKey('workshop-start')),
        ],
      ),
    );
  }

  Future<void> _start(int batches, GoodsBundle output, TownGrowthLines lines) async {
    final recipe = refiningRecipe(_recipeId)!;
    final result = await runHallCommand(context, ref, (service) => service.startRefining(_recipeId, batches));
    if (result == null || !result.accepted || !mounted) return;
    toastLine(context, fillLine(lines.line('refine.started'), {
      'goods': goodsText(output, lines),
      'time': HallNames.duration(Duration(minutes: recipe.minutesPerBatch * batches)),
    }));
  }

  Future<void> _collect() async {
    final lines = ref.read(townGrowthLinesProvider).value ?? TownGrowthLines.defaults;
    final game = ref.read(gameStateProvider).value ?? GameState.initial();
    final meId = ref.read(hallLedgerViewProvider).meId ?? '';
    final now = ref.read(gameClockProvider).now();
    final ready = planCollectGoods(game, meId, now).done.fold(
          const GoodsBundle.empty(),
          (GoodsBundle sum, done) => sum + done.job.output,
        );
    final result = await runHallCommand(context, ref, (service) => service.collectGoods());
    if (result == null || !result.accepted || !mounted) return;
    toastLine(context, fillLine(lines.line('refine.collected'), {'goods': goodsText(ready, lines)}));
  }
}
