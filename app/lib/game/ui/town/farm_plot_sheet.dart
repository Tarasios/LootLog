/// The sheet for one farmland field: what can be planted on an empty field
/// (farm, orchard, granary, each with its cost and any gate in plain
/// words), and for a farm building its build timer, the food it grows and
/// a Harvest button, the granary's room, and its next upgrade. Every gate
/// is the real command dry-run, so the sheet and the rules never disagree.
/// A framed game dialog in the pixel tier, a bottom sheet in the text tier.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/theme.dart';
import '../../assets/asset_catalog.dart';
import '../../assets/pack_sprite.dart';
import '../../config/balance.dart';
import '../../data/game_providers.dart';
import '../../domain/commands/game_commands.dart';
import '../../domain/game_values.dart';
import '../../domain/town/districts.dart';
import '../../domain/town/food.dart';
import '../../domain/town/town_growth_lines.dart';
import '../hall_common.dart';
import '../hall_framed.dart';
import '../hall_ledger_view.dart';
import '../hall_names.dart';
import '../hall_voice.dart';
import '../kit/kit.dart';
import 'town_growth_providers.dart';
import 'town_loop_view.dart' show fillLine;

/// Opens farmland field [plotIndex]'s sheet.
Future<void> showFarmPlotSheet(BuildContext context, {required int plotIndex}) {
  final sheet = FarmPlotSheet(plotIndex: plotIndex);
  if (!hallDeviceTextTier(context)) {
    return showGameDialog<void>(context, builder: (_) => sheet);
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => HallScope(child: SingleChildScrollView(child: sheet)),
  );
}

class FarmPlotSheet extends ConsumerWidget {
  const FarmPlotSheet({super.key, required this.plotIndex});

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
      final address = PlotAddress(kFarmlandDistrictId, plotIndex);
      final building = town.districts.buildingAt(address);
      final type = building?.farmType;
      GameRejection? preview(GameCommandResult Function(GameCommands commands) command) =>
          previewRejection(game, meId, clock, command);
      final field = _Field(context: context, ref: ref, plotIndex: plotIndex, lines: lines, voice: voice);
      final String title;
      final List<Widget> children;
      if (!town.districts.owns(kFarmlandDistrictId)) {
        title = 'Field ${plotIndex + 1}';
        children = [Text(lines.line('farm.locked'), style: framedBodyStyle(context))];
      } else if (building == null || type == null) {
        title = 'Field ${plotIndex + 1}';
        children = [
          Text(lines.line('farm.empty'), style: framedBodyStyle(context)),
          for (final option in FarmBuildingType.values)
            field.option(option, preview((commands) => commands.startFarmBuilding(plotIndex, option))),
        ];
      } else {
        title = '${lines.line(farmBuildingNameKey(type))} — tier ${building.tier}';
        final activeDays = game.townActiveDaysOf(meId ?? '');
        children = [
          ...field.progress(building, now),
          if (Balance.farmBuildings[type]!.growsFood)
            field.harvest(
              type,
              tierInService: building.tierAt(now),
              ready: harvestableFood(town, address, now, activeDays: activeDays),
              rejection: preview((commands) => commands.harvestFood(plotIndex)),
            )
          else
            Text(fillLine(lines.line('farm.granaryHolds'), {'capacity': '${foodCapacityAt(town, now)}'}),
                style: framedBodyStyle(context)),
          field.upgrade(type, building.tier + 1, preview((commands) => commands.startFarmBuilding(plotIndex, type))),
        ];
      }
      final picture = type == null
          ? GameAssetKeys.farmPlotEmpty
          : GameAssetKeys.farmBuilding(type, building!.tier);
      if (hallTextTier(context)) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: framedBodyStyle(context, weight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.sm),
              ...children,
            ],
          ),
        );
      }
      return GameDialog(
        title: title,
        scene: Center(child: PackSprite(assetKey: picture, scale: 3)),
        onClose: () => Navigator.of(context).pop(),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        actions: [
          WoodButton(label: 'Close', tone: WoodButtonTone.secondary, onPressed: () => Navigator.of(context).pop()),
        ],
      );
    });
  }
}

/// The pieces of one field's sheet, and the commands behind its buttons.
class _Field {
  const _Field({
    required this.context,
    required this.ref,
    required this.plotIndex,
    required this.lines,
    required this.voice,
  });

  final BuildContext context;
  final WidgetRef ref;
  final int plotIndex;
  final TownGrowthLines lines;
  final HallVoice voice;

  Widget _gate(GameRejection? rejection) => rejection == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(voice.rejection(rejection), style: framedGateStyle(context)),
        );

  Widget _button(String label, VoidCallback? onPressed) =>
      Align(alignment: Alignment.centerLeft, child: FramedButton(label: label, onPressed: onPressed));

  /// One building that can be planted on an empty field.
  Widget option(FarmBuildingType type, GameRejection? rejection) {
    final name = lines.line(farmBuildingNameKey(type));
    return FramedSection(
      title: name,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PackSprite(assetKey: GameAssetKeys.farmBuilding(type, 1), label: name, scale: 2),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(lines.line('farm.blurb.${type.name}'), style: framedMutedStyle(context)),
                CostLine(Balance.farmBuildingCost(type, 1)),
                Text('Build time: ${HallNames.buildTime(1)}', style: framedBodyStyle(context)),
                const SizedBox(height: AppSpacing.xs),
                _gate(rejection),
                _button('Build $name', rejection == null ? () => _build(type) : null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The build timer while a tier is under way.
  List<Widget> progress(DistrictBuildingState building, DateTime now) {
    if (building.isCompleteAt(now)) return const [];
    final total = building.completesAt.difference(building.startedAt);
    final left = building.completesAt.difference(now);
    return [
      Text('Ready in ${HallNames.duration(left)}', style: framedBodyStyle(context, weight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.xs),
      FramedMeter(total.inSeconds == 0 ? 1 : 1 - left.inSeconds / total.inSeconds),
      const SizedBox(height: AppSpacing.md),
    ];
  }

  /// What a farm or orchard grows, and its Harvest button.
  Widget harvest(FarmBuildingType type, {required int tierInService, required int ready, required GameRejection? rejection}) {
    final rate = tierInService < 1 ? 0 : Balance.farmBuildings[type]!.foodPerHour[tierInService - 1];
    return FramedSection(
      title: 'Harvest',
      icon: Icons.grass,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(fillLine(lines.line('farm.grows'), {'food': '$rate'}), style: framedBodyStyle(context)),
          Text(
            ready > 0 ? fillLine(lines.line('farm.ready'), {'food': '$ready'}) : lines.line('farm.growing'),
            style: framedMutedStyle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          _gate(ready > 0 ? rejection : null),
          _button('Harvest', rejection == null ? () => _harvest(ready) : null),
        ],
      ),
    );
  }

  /// The next tier's cost and button, or the top.
  Widget upgrade(FarmBuildingType type, int next, GameRejection? rejection) {
    if (next > Balance.maxBuildingTier) {
      return Text(fillLine(lines.line('farm.atTop'), {'tier': '${Balance.maxBuildingTier}'}),
          style: framedMutedStyle(context));
    }
    return FramedSection(
      title: 'Upgrade to tier $next',
      icon: Icons.upgrade,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CostLine(Balance.farmBuildingCost(type, next)),
          Text('Build time: ${HallNames.buildTime(next)}', style: framedBodyStyle(context)),
          const SizedBox(height: AppSpacing.xs),
          _gate(rejection),
          _button('Upgrade to tier $next', rejection == null ? () => _build(type) : null),
        ],
      ),
    );
  }

  Future<void> _build(FarmBuildingType type) async {
    final result = await runHallCommand(context, ref, (service) => service.startFarmBuilding(plotIndex, type));
    if (result == null || !result.accepted || !context.mounted) return;
    _toast(fillLine(lines.line('farm.built'), {'building': lines.line(farmBuildingNameKey(type))}));
  }

  Future<void> _harvest(int ready) async {
    final result = await runHallCommand(context, ref, (service) => service.harvestFood(plotIndex));
    if (result == null || !result.accepted || !context.mounted) return;
    _toast(fillLine(lines.line('farm.harvested'), {'food': '$ready'}));
  }

  void _toast(String message) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
}
