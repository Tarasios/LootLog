/// The long road in the text home: homes, guards, goods and the Castle in
/// a few lines, a button per plot of each civic quarter the town owns
/// (opening its sheet), the workshop, and the Castle (or its promise before
/// the city). The same features as the pixel town's quarters, workshop
/// sheet and Castle sheet, as plain sections and buttons.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/theme.dart';
import '../../config/balance.dart';
import '../../domain/town/districts.dart';
import '../../domain/town/long_road_book.dart';
import '../../domain/town/town_growth_lines.dart';
import '../hall_common.dart';
import '../hall_home_sections.dart' show HallHomeData;
import 'castle_sheet.dart';
import 'civic_plot_sheet.dart';
import 'long_road_ui.dart';
import 'town_growth_providers.dart';
import 'town_loop_view.dart' show fillLine;
import 'workshop_panel.dart';

/// The civic quarters, in catalogue order.
const List<String> _quarters = [kGuardPostDistrictId, kResidentialDistrictId, kParkDistrictId, kMarketRowDistrictId];

class LongRoadTextPanel extends ConsumerWidget {
  const LongRoadTextPanel(this.data, {super.key});

  final HallHomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(townGrowthLinesProvider).value ?? TownGrowthLines.defaults;
    final book = longRoadBook(data.game, data.view.meId ?? '', data.now);
    final owned = [for (final id in _quarters) if (data.town.districts.owns(id)) id];
    final watched = book.guardedFields - Balance.unguardedFarmPlots;
    return HallSection(
      title: lines.line('castle.title'),
      icon: Icons.fort,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(fillLine(lines.line('book.homes'), {'count': '${book.housing}'}), style: hallBodyStyle(context)),
          Text(fillLine(lines.line('guards.capacity'), {'guards': '${book.guards}', 'plots': '$watched'}),
              style: hallBodyStyle(context)),
          if (book.restingFarms > 0)
            Text(fillLine(lines.line('book.restingFarms'), {'count': '${book.restingFarms}'}),
                style: hallBodyStyle(context)),
          Text(
            book.goods.isEmpty
                ? lines.line('goods.none')
                : fillLine(lines.line('goods.stored'), {'goods': goodsText(book.goods, lines)}),
            style: hallBodyStyle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final districtId in owned) ...[
            Text(lines.line(districtNameKey(districtId)), style: hallBodyStyle(context, weight: FontWeight.w700)),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var plot = 0; plot < districtById(districtId)!.plotCount; plot++)
                  OutlinedButton(
                    key: ValueKey('text-civic-$districtId-$plot'),
                    onPressed: () => unawaited(showCivicPlotSheet(context, districtId: districtId, plotIndex: plot)),
                    child: Text(_plotLabel(lines, districtId, plot)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (book.workshops > 0)
                FilledButton.tonal(
                  key: const ValueKey('text-workshop'),
                  onPressed: () => unawaited(showWorkshopSheet(context)),
                  child: Text(lines.line('refine.title')),
                ),
              if (book.castleOpen)
                FilledButton.tonal(
                  key: const ValueKey('text-castle'),
                  onPressed: () => unawaited(showCastleSheet(context)),
                  child: Text(fillLine(lines.line('castle.progress'), {'count': '${book.castleStagesDone}'})),
                ),
            ],
          ),
          if (!book.castleOpen) Text(lines.line('castle.teaser'), style: hallMutedStyle(context)),
        ],
      ),
    );
  }

  String _plotLabel(TownGrowthLines lines, String districtId, int plot) {
    final building = data.town.districts.buildingAt(PlotAddress(districtId, plot));
    final type = building?.civicType;
    if (building == null || type == null) return 'Plot ${plot + 1}: empty';
    return 'Plot ${plot + 1}: ${lines.line(civicBuildingNameKey(type))} T${building.tier}';
  }
}
