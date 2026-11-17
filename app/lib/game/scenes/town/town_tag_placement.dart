/// Where each town tag hangs, in world pixels: over the middle of the top
/// edge of its plot, house, the gate or a statue spot. Goal tags take the
/// square's statue spots corner to opposite corner, so the first two (wide
/// signs, only three cells apart on a row) never overlap. Pure Dart, zero
/// Flutter imports.
library;

import '../../domain/town/town_layout.dart';
import '../../domain/town/town_tags.dart';
import '../../domain/town/town_view.dart';
import '../camera_controls.dart';

/// The order goal tags take the square's four statue spots in: opposite
/// corners first.
const List<int> _statueSpotOrder = [0, 3, 1, 2];

/// A [tag] and the world point its sign's pointer touches.
class PlacedTownTag {
  const PlacedTownTag({
    required this.tag,
    required this.worldX,
    required this.worldY,
  });

  final TownTag tag;
  final double worldX;
  final double worldY;
}

/// Places [tags] on [view]'s map. A tag whose plot or house is not in the
/// town (or a goal beyond the statue spots) is left out.
List<PlacedTownTag> placeTownTags(List<TownTag> tags, TownView view) {
  const footprintWidth = TownLayout.footprint * kTileSize;
  final layoutSpots = view.layout.statueSpots;
  final statueSpots = [
    for (final index in _statueSpotOrder)
      if (index < layoutSpots.length) layoutSpots[index],
  ];
  var nextStatue = 0;
  final placed = <PlacedTownTag>[];

  void add(TownTag tag, TownCell cell, double width) => placed.add(
    PlacedTownTag(
      tag: tag,
      worldX: cell.column * kTileSize + width / 2,
      worldY: cell.row * kTileSize,
    ),
  );

  for (final tag in tags) {
    switch (tag.anchor) {
      case PlotAnchor(:final plotIndex):
        final plot = view.plots
            .where((plot) => plot.plotIndex == plotIndex)
            .firstOrNull;
        if (plot != null) add(tag, plot.origin, footprintWidth);
      case HouseAnchor(:final personId):
        final resident = view.residents
            .where((resident) => resident.personId == personId)
            .firstOrNull;
        if (resident != null) add(tag, resident.houseOrigin, footprintWidth);
      case GateAnchor():
        add(tag, view.layout.gate, kTileSize);
      case StatueAnchor():
        if (nextStatue < statueSpots.length) {
          add(tag, statueSpots[nextStatue++], kTileSize);
        }
    }
  }
  return placed;
}
