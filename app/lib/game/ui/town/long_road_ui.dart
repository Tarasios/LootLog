/// Small pieces the long road's sheets share: goods in words ("4 planks,
/// 2 cut stone"), a cost line that names goods as well as gems and
/// materials, a gate line in the voice's own words, and a sheet that is a
/// framed game dialog in the pixel tier and a bottom sheet in the text
/// tier.
library;

import 'package:flutter/material.dart';

import '../../../ui/theme.dart';
import '../../domain/commands/game_commands.dart';
import '../../domain/game_values.dart';
import '../../domain/town/town_growth_lines.dart';
import '../hall_common.dart';
import '../hall_framed.dart';
import '../hall_names.dart';
import '../hall_voice.dart';
import '../kit/kit.dart';

/// "4 Planks, 2 Cut stone", or "nothing".
String goodsText(GoodsBundle goods, TownGrowthLines lines) => goods.isEmpty
    ? 'nothing'
    : [for (final entry in goods.amounts.entries) '${entry.value} ${lines.line(goodsNameKey(entry.key))}'].join(', ');

/// "Cost: 15 gems + 20 lumber + 4 Planks".
class GoodsCostLine extends StatelessWidget {
  const GoodsCostLine({super.key, required this.cost, required this.goods, required this.lines});

  final Loot cost;
  final GoodsBundle goods;
  final TownGrowthLines lines;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (cost.gems > 0 || !cost.materials.isEmpty || goods.isEmpty) HallNames.cost(cost),
      if (!goods.isEmpty) goodsText(goods, lines),
    ];
    return Text('Cost: ${parts.join(' + ')}', style: hallBodyStyle(context));
  }
}

/// Why a button is off, in the voice's words (nothing when it is on).
Widget gateLine(BuildContext context, HallVoice voice, GameRejection? rejection) => rejection == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(voice.rejection(rejection), style: framedGateStyle(context)),
      );

/// A left-aligned framed button.
Widget sheetButton(String label, VoidCallback? onPressed, {Key? key}) =>
    Align(alignment: Alignment.centerLeft, child: FramedButton(key: key, label: label, onPressed: onPressed));

/// Opens [sheet]: a framed game dialog in the pixel tier, a scrolling
/// bottom sheet in the text tier.
Future<void> showLongRoadSheet(BuildContext context, Widget sheet) {
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

/// A sheet's frame: the [title] over [children] as text-tier padding, or a
/// framed game dialog with [picture] above them and a Close button.
Widget longRoadSheetFrame(
  BuildContext context, {
  required String title,
  required Widget picture,
  required List<Widget> children,
}) {
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
    scene: Center(child: picture),
    onClose: () => Navigator.of(context).pop(),
    body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    actions: [
      WoodButton(label: 'Close', tone: WoodButtonTone.secondary, onPressed: () => Navigator.of(context).pop()),
    ],
  );
}

/// A short note at the foot of the screen.
void toastLine(BuildContext context, String message) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
