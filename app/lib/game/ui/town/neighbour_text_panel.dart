/// The neighbouring towns in the text home: each Adventure neighbour's town
/// in a line (its tier and prosperity), with Visit (a read-only list of what
/// stands there), Send a gift and Cheer; a Standard adult's supply caravan
/// as one unnamed line with no buttons. Nothing at all when alone. The same
/// features as the pixel town's signpost, visit, gift dialog and cheer.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/theme.dart';
import '../../domain/town/districts.dart';
import '../../domain/town/neighbour_lines.dart';
import '../../domain/town/neighbours.dart';
import '../../domain/town/prosperity.dart';
import '../../domain/town/town_growth_lines.dart';
import '../hall_common.dart';
import '../hall_home_sections.dart' show HallHomeData;
import '../hall_names.dart';
import 'gift_dialog.dart';
import 'neighbour_actions.dart';
import 'neighbour_providers.dart';
import 'town_growth_providers.dart';

class NeighbourTextPanel extends ConsumerWidget {
  const NeighbourTextPanel(this.data, {super.key});

  final HallHomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neighbours = myNeighbours(data.game, data.view);
    if (neighbours.isEmpty) return const SizedBox.shrink();
    final lines = ref.watch(neighbourLinesProvider).value ?? NeighbourLines.defaults;
    final growth = ref.watch(townGrowthLinesProvider).value ?? TownGrowthLines.defaults;
    final meId = data.view.meId ?? '';
    return HallSection(
      title: lines.line('text.title'),
      icon: Icons.signpost,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final neighbour in neighbours.where((n) => n.canVisit)) ...[
            Text(
              lines.line('text.town', {
                'name': neighbour.name,
                'tier': growth.line(tierNameKey(data.game.person(neighbour.memberId).townTier)),
                'prosperity': '${prosperityOf(data.game, neighbour.memberId, data.now)}',
              }),
              style: hallBodyStyle(context),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton(
                  key: ValueKey('text-neighbour-visit-${neighbour.memberId}'),
                  onPressed: () => unawaited(_showVisit(context, neighbour, lines, growth)),
                  child: const Text('Visit'),
                ),
                OutlinedButton(
                  key: ValueKey('text-neighbour-gift-${neighbour.memberId}'),
                  onPressed: () => unawaited(showGiftDialog(context, neighbour)),
                  child: const Text('Send a gift'),
                ),
                if (cheeredToday(data.game, meId, neighbour, data.now))
                  OutlinedButton(
                    key: ValueKey('text-neighbour-cheer-${neighbour.memberId}'),
                    onPressed: null,
                    child: Text(lines.line('cheer.done')),
                  )
                else
                  FilledButton(
                    key: ValueKey('text-neighbour-cheer-${neighbour.memberId}'),
                    onPressed: () => unawaited(cheerNeighbour(context, ref, neighbour, lines)),
                    child: const Text('Cheer'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (neighbours.any((n) => n.isCaravan))
            Text(lines.line('text.caravan'), style: hallMutedStyle(context)),
        ],
      ),
    );
  }

  /// A read-only look around [neighbour]'s town: what stands on each plot
  /// and the districts they own.
  Future<void> _showVisit(
    BuildContext context,
    TownNeighbour neighbour,
    NeighbourLines lines,
    TownGrowthLines growth,
  ) {
    final town = data.game.townOf(neighbour.memberId);
    final tier = growth.line(tierNameKey(data.game.person(neighbour.memberId).townTier));
    final plots = town.plots.values.toList()..sort((first, second) => first.index.compareTo(second.index));
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => HallScope(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(lines.line('visit.header', {'name': neighbour.name}),
                  style: hallBodyStyle(sheetContext, weight: FontWeight.w800)),
              Text(lines.line('visit.welcome', {'name': neighbour.name, 'tier': tier}),
                  style: hallBodyStyle(sheetContext)),
              const SizedBox(height: AppSpacing.sm),
              for (final plot in plots)
                Text(
                  switch (plot.building) {
                    final building? => '${HallNames.building(building.type)}: tier ${building.tier}',
                    null => 'Plot ${plot.index + 1}: ${lines.line('visit.empty', {'name': neighbour.name})}',
                  },
                  style: hallBodyStyle(sheetContext),
                ),
              for (final district in kDistricts)
                if (district.id != kOutpostDistrictId && town.districts.owns(district.id))
                  Text(growth.line(districtNameKey(district.id)), style: hallBodyStyle(sheetContext)),
            ],
          ),
        ),
      ),
    );
  }
}
