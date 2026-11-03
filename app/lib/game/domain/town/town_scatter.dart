/// Scenery scattered around and through the town: a ring of trees and
/// bushes framing the 28×20 map, plus a light sprinkle of props on free grass
/// inside it. Seeded, so the same seed always grows the same town on every
/// device. Pure Dart, zero Flutter imports.
library;

import 'dart:math';

import 'town_layout.dart';

/// One scenery prop: a cell (negative or past the grid edge for the border
/// ring) and the asset key it's drawn with.
typedef TownProp = ({int column, int row, String assetKey});

class TownScatter {
  const TownScatter({required this.props, required this.borderWidth});

  /// Prop keys present in the bundled Tiny Town pack (it has no rock).
  static const String treeKey = 'town.tree.default.idle';
  static const String bushKey = 'town.bush.default.idle';

  /// Share of the border ring drawn as trees; the rest are bushes.
  static const double borderTreeShare = 0.75;

  /// Share of free in-town grass that gets a prop.
  static const double inTownDensity = 0.06;

  /// Share of in-town props drawn as bushes; the rest are trees.
  static const double inTownBushShare = 0.6;

  /// Border props first (row by row, top to bottom), then in-town ones.
  final List<TownProp> props;

  /// How many cells deep the border ring is on every side.
  final int borderWidth;
}

/// Scatters scenery for [layout] with [seed]: every cell of a [borderWidth]
/// ring outside the grid gets a tree or a bush, and about
/// [TownScatter.inTownDensity] of the free grass inside gets one too. Free
/// grass is grass not covered by a plot, a house, the gate, a statue spot or
/// one of the layout's own trees, so props never land on a path or a
/// building.
TownScatter scatterTown(TownLayout layout, {required int seed, int borderWidth = 6}) {
  final random = Random(seed);
  final props = <TownProp>[];

  for (var row = -borderWidth; row < layout.rows + borderWidth; row++) {
    for (var column = -borderWidth; column < layout.columns + borderWidth; column++) {
      final insideGrid = column >= 0 && column < layout.columns && row >= 0 && row < layout.rows;
      if (insideGrid) continue;
      final key = random.nextDouble() < TownScatter.borderTreeShare ? TownScatter.treeKey : TownScatter.bushKey;
      props.add((column: column, row: row, assetKey: key));
    }
  }

  final occupied = _occupiedCells(layout);
  for (var row = 0; row < layout.rows; row++) {
    for (var column = 0; column < layout.columns; column++) {
      final cell = TownCell(column, row);
      if (layout.groundAt(cell) != TownGround.grass || occupied.contains(cell)) continue;
      if (random.nextDouble() >= TownScatter.inTownDensity) continue;
      final key = random.nextDouble() < TownScatter.inTownBushShare ? TownScatter.bushKey : TownScatter.treeKey;
      props.add((column: column, row: row, assetKey: key));
    }
  }

  return TownScatter(props: List.unmodifiable(props), borderWidth: borderWidth);
}

/// Every cell something already stands on.
Set<TownCell> _occupiedCells(TownLayout layout) => {
      for (final origin in [...layout.plotOrigins, ...layout.houseOrigins])
        for (var column = 0; column < TownLayout.footprint; column++)
          for (var row = 0; row < TownLayout.footprint; row++) TownCell(origin.column + column, origin.row + row),
      layout.gate,
      ...layout.statueSpots,
      ...layout.treeCells,
    };
