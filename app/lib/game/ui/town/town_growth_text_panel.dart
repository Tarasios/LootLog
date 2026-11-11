/// The town's growth in the text home: the tier and prosperity, what the
/// next tier needs, the town book, every district (visit the farmland's
/// fields, buy one for sale, or see what opens it) and, for a tier reached
/// lately, its celebration line. The same features as the pixel town's
/// strip, picker, field sheets and book, as plain sections and buttons.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/theme.dart';
import '../../domain/town/districts.dart';
import '../../domain/town/town_book.dart';
import '../../domain/town/town_growth_lines.dart';
import '../hall_common.dart';
import '../hall_home_sections.dart' show HallHomeData;
import 'district_picker_dialog.dart';
import 'farm_plot_sheet.dart';
import 'town_book_screen.dart';
import 'town_growth_providers.dart';
import 'town_loop_providers.dart' show kTierCelebrationWindow;
import 'town_loop_view.dart' show fillLine;

class TownGrowthPanel extends ConsumerWidget {
  const TownGrowthPanel(this.data, {super.key});

  final HallHomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(townGrowthLinesProvider).value ?? TownGrowthLines.defaults;
    final meId = data.view.meId ?? '';
    final book = townBook(data.game, meId, data.now);
    final reachedAt = data.me.tiersReached[book.tier];
    final fresh = reachedAt != null && data.now.difference(reachedAt) <= kTierCelebrationWindow;
    final next = book.nextTier;
    final needed = book.nextTierProsperity;
    final ownsFarmland = book.districts.any((listing) => listing.spec.id == kFarmlandDistrictId && listing.owned);
    return HallSection(
      title: '${lines.line(tierNameKey(book.tier))} · ${lines.line('book.title')}',
      icon: Icons.auto_stories,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fresh) Text(lines.line(tierReachedKey(book.tier)), style: hallBodyStyle(context, weight: FontWeight.w700)),
          Text(
            next == null || needed == null
                ? fillLine(lines.line('book.top'), {'prosperity': '${book.prosperity}'})
                : fillLine(lines.line('book.prosperity'), {
                    'prosperity': '${book.prosperity}',
                    'tier': lines.line(tierNameKey(next)),
                    'needed': '$needed',
                  }),
            style: hallBodyStyle(context),
          ),
          if (needed != null) NextTierSection(book: book, lines: lines),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => unawaited(TownBookScreen.open(context)),
              icon: const Icon(Icons.menu_book),
              label: Text('Open the ${lines.line('book.title').toLowerCase()}'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final listing in book.districts) _districtRow(context, lines, listing),
          if (ownsFarmland)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var plot = 0; plot < districtById(kFarmlandDistrictId)!.plotCount; plot++)
                  OutlinedButton(
                    key: ValueKey('text-field-$plot'),
                    onPressed: () => unawaited(showFarmPlotSheet(context, plotIndex: plot)),
                    child: Text(_fieldLabel(lines, plot)),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _fieldLabel(TownGrowthLines lines, int plot) {
    final building = data.town.districts.buildingAt(PlotAddress(kFarmlandDistrictId, plot));
    final type = building?.farmType;
    if (building == null || type == null) return 'Field ${plot + 1}: empty';
    return 'Field ${plot + 1}: ${lines.line(farmBuildingNameKey(type))} T${building.tier}';
  }

  Widget _districtRow(BuildContext context, TownGrowthLines lines, DistrictListing listing) {
    final spec = listing.spec;
    final tierName = lines.line(tierNameKey(spec.requiredTier));
    final status = listing.owned
        ? lines.line('district.owned')
        : !spec.purchasable
            ? lines.line('district.comingLater')
            : listing.forSale
                ? fillLine(lines.line('district.forSale'), {'price': _price(spec)})
                : fillLine(lines.line('district.opensAt'), {'tier': tierName});
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: lines.line(districtNameKey(spec.id)), style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' — $status'),
              ]),
              style: hallBodyStyle(context),
            ),
          ),
          if (listing.forSale)
            FilledButton(
              key: ValueKey('text-district-buy-${spec.id}'),
              onPressed: () => unawaited(showDistrictPicker(context, onVisit: (_) {}, onBought: (_) {})),
              child: const Text('Buy'),
            ),
        ],
      ),
    );
  }

  static String _price(DistrictSpec spec) {
    final materials = [
      for (final entry in spec.materialPrice.entries) '${entry.value} ${entry.key.name}',
    ];
    return ['${spec.gemPrice} gems', ...materials].join(', ');
  }
}
