/// The sheet for one plot of a civic quarter (the Guard Post, Residential
/// Quarter, Park or Market Row): on an empty plot, the quarter's buildings
/// with what each adds, its cost (goods too, from tier 3) and Build; on a
/// building, its build timer, what it adds at its tier, the workshop's jobs
/// for a workshop, and its next upgrade. Every gate is the real command
/// dry-run, so the sheet and the rules never disagree.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/theme.dart';
import '../../assets/asset_catalog.dart';
import '../../assets/pack_sprite.dart';
import '../../config/balance.dart';
import '../../data/game_providers.dart';
import '../../domain/content.dart';
import '../../domain/game_values.dart';
import '../../domain/town/districts.dart';
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
import 'workshop_panel.dart';

/// Opens plot [plotIndex] of civic quarter [districtId].
Future<void> showCivicPlotSheet(BuildContext context, {required String districtId, required int plotIndex}) =>
    showLongRoadSheet(context, CivicPlotSheet(districtId: districtId, plotIndex: plotIndex));

class CivicPlotSheet extends ConsumerWidget {
  const CivicPlotSheet({super.key, required this.districtId, required this.plotIndex});

  final String districtId;
  final int plotIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = hallGameState(ref);
    final meId = ref.watch(hallLedgerViewProvider).meId;
    final clock = ref.watch(gameClockProvider);
    final lines = ref.watch(townGrowthLinesProvider).value ?? TownGrowthLines.defaults;
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    return HallTicker(builder: (context) {
      final now = clock.now();
      final town = game.townOf(meId ?? '');
      final building = town.districts.buildingAt(PlotAddress(districtId, plotIndex));
      final type = building?.civicType;
      GameRejection? preview(CivicBuildingType option) => previewRejection(
          game, meId, clock, (commands) => commands.startCivicBuilding(districtId, plotIndex, option));
      final parts = _CivicParts(context: context, ref: ref, districtId: districtId, plotIndex: plotIndex, lines: lines, voice: voice);
      final districtName = lines.line(districtNameKey(districtId));
      final String title;
      final List<Widget> children;
      if (!town.districts.owns(districtId)) {
        title = '$districtName · plot ${plotIndex + 1}';
        children = [Text(fillLine(lines.line('civic.plot.locked'), {'district': districtName}), style: framedBodyStyle(context))];
      } else if (building == null || type == null) {
        title = '$districtName · plot ${plotIndex + 1}';
        children = [
          Text(lines.line('civic.plot.empty'), style: framedBodyStyle(context)),
          for (final option in civicTypesOf(districtId)) parts.option(option, preview(option)),
        ];
      } else {
        // The ribbon fits a short title: the tier leads the body.
        title = lines.line(civicBuildingNameKey(type));
        children = [
          Text('Tier ${building.tier}', key: const ValueKey('civic-tier'),
              style: framedBodyStyle(context, weight: FontWeight.w800)),
          ...parts.progress(building.startedAt, building.completesAt, now),
          Text(parts.adds(type, building.tierAt(now) < 1 ? building.tier : building.tierAt(now)),
              style: framedBodyStyle(context)),
          const SizedBox(height: AppSpacing.sm),
          if (type == CivicBuildingType.workshop) ...[
            const WorkshopPanel(),
            const SizedBox(height: AppSpacing.sm),
          ],
          parts.upgrade(type, building.tier + 1, preview(type)),
        ];
      }
      final picture = type == null
          ? GameAssetKeys.civicPlotEmpty(districtId)
          : GameAssetKeys.civicBuilding(type, building!.tier);
      return longRoadSheetFrame(
        context,
        title: title,
        picture: PackSprite(assetKey: picture, scale: 3),
        children: children,
      );
    });
  }
}

/// The civic buildings allowed in [districtId], in catalogue order.
List<CivicBuildingType> civicTypesOf(String districtId) => [
      for (final key in districtById(districtId)?.buildingKeys ?? const <String>[])
        ?civicBuildingByKey(key),
    ];

/// The pieces of one civic plot's sheet, and the commands behind them.
class _CivicParts {
  const _CivicParts({
    required this.context,
    required this.ref,
    required this.districtId,
    required this.plotIndex,
    required this.lines,
    required this.voice,
  });

  final BuildContext context;
  final WidgetRef ref;
  final String districtId;
  final int plotIndex;
  final TownGrowthLines lines;
  final HallVoice voice;

  /// What [type] adds at [tier], in a sentence.
  String adds(CivicBuildingType type, int tier) {
    final spec = Balance.civicBuildings[type]!;
    String count(List<int> list) => '${CivicBuildingSpec.at(list, tier)}';
    if (spec.guardsByTier.isNotEmpty) {
      return fillLine(lines.line('civic.adds.guards'),
          {'count': count(spec.guardsByTier), 'per': '${Balance.guardsPerFarmPlot}'});
    }
    if (spec.housingByTier.isNotEmpty) return fillLine(lines.line('civic.adds.housing'), {'count': count(spec.housingByTier)});
    if (spec.prosperityByTier.isNotEmpty) {
      return fillLine(lines.line('civic.adds.prosperity'), {'count': count(spec.prosperityByTier)});
    }
    if (type == CivicBuildingType.workshop) {
      return fillLine(lines.line('civic.adds.refine'), {'count': '${workshopMaxBatches(tier)}'});
    }
    return lines.line('civic.adds.trade');
  }

  /// One building that can go up on the empty plot.
  Widget option(CivicBuildingType type, GameRejection? rejection) {
    final name = lines.line(civicBuildingNameKey(type));
    final (:cost, :goods) = Balance.civicBuildingCost(type, 1);
    return FramedSection(
      title: name,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PackSprite(assetKey: GameAssetKeys.civicBuilding(type, 1), label: name, scale: 2),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(lines.line(civicBuildingBlurbKey(type)), style: framedMutedStyle(context)),
                Text(adds(type, 1), style: framedBodyStyle(context)),
                GoodsCostLine(cost: cost, goods: goods, lines: lines),
                Text('Build time: ${HallNames.buildTime(1)}', style: framedBodyStyle(context)),
                const SizedBox(height: AppSpacing.xs),
                gateLine(context, voice, rejection),
                commandButton('Build $name', rejection == null ? () => _build(type) : null,
                    key: ValueKey('civic-build-${type.name}')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The build timer while a tier is under way.
  List<Widget> progress(DateTime startedAt, DateTime completesAt, DateTime now) {
    if (!now.isBefore(completesAt)) return const [];
    final total = completesAt.difference(startedAt);
    final left = completesAt.difference(now);
    return [
      Text('Ready in ${HallNames.duration(left)}', style: framedBodyStyle(context, weight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.xs),
      FramedMeter(total.inSeconds == 0 ? 1 : 1 - left.inSeconds / total.inSeconds),
      const SizedBox(height: AppSpacing.md),
    ];
  }

  /// The next tier's cost and button, or the top.
  Widget upgrade(CivicBuildingType type, int next, GameRejection? rejection) {
    if (next > Balance.maxBuildingTier) {
      return Text(fillLine(lines.line('civic.atTop'), {'tier': '${Balance.maxBuildingTier}'}),
          style: framedMutedStyle(context));
    }
    final (:cost, :goods) = Balance.civicBuildingCost(type, next);
    return FramedSection(
      title: 'Upgrade to tier $next',
      icon: Icons.upgrade,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(adds(type, next), style: framedBodyStyle(context)),
          GoodsCostLine(cost: cost, goods: goods, lines: lines),
          Text('Build time: ${HallNames.buildTime(next)}', style: framedBodyStyle(context)),
          const SizedBox(height: AppSpacing.xs),
          gateLine(context, voice, rejection),
          commandButton('Upgrade to tier $next', rejection == null ? () => _build(type) : null,
              key: const ValueKey('civic-upgrade')),
        ],
      ),
    );
  }

  Future<void> _build(CivicBuildingType type) async {
    final result =
        await runHallCommand(context, ref, (service) => service.startCivicBuilding(districtId, plotIndex, type));
    if (result == null || !result.accepted || !context.mounted) return;
    toastLine(context, fillLine(lines.line('civic.built'), {'building': lines.line(civicBuildingNameKey(type))}));
  }
}
