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

  /// The dense forest that frames the town: its body, and the edge tiles
  /// where it meets the town on each side (named by the side of the forest
  /// they are, so the forest south of the town shows its north edge).
  static const String forestKey = 'town.forest.centre.idle';
  static const String forestNorthEdgeKey = 'town.forest.north.idle';
  static const String forestSouthEdgeKey = 'town.forest.south.idle';
  static const String forestWestEdgeKey = 'town.forest.west.idle';
  static const String forestEastEdgeKey = 'town.forest.east.idle';

  /// What grows on free grass inside the town, most common first: each
  /// entry's share of the in-town props.
  static const List<(String, double)> inTownProps = [
    ('town.ground.tuft.idle', 0.34),
    ('town.ground.flowers.idle', 0.2),
    (bushKey, 0.18),
    (treeKey, 0.14),
    ('town.tree.autumn.idle', 0.08),
    ('town.mushroom.default.idle', 0.06),
  ];

  /// Share of free in-town grass that gets a prop.
  static const double inTownDensity = 0.12;

  /// Border props first (row by row, top to bottom), then in-town ones.
  final List<TownProp> props;

  /// How many cells deep the border ring is on every side.
  final int borderWidth;
}

/// Scatters scenery for [layout] with [seed]: every cell of a [borderWidth]
/// ring outside the grid gets forest (an edge tile where it meets the town),
/// and about
/// [TownScatter.inTownDensity] of the free grass inside gets one too. Free
/// grass is grass not covered by a plot, a house, the gate, a statue spot or
/// one of the layout's own trees, so props never land on a path or a
/// building.
TownScatter scatterTown(
  TownLayout layout, {
  required int seed,
  int borderWidth = 6,
}) {
  final random = Random(seed);
  final props = <TownProp>[];

  for (var row = -borderWidth; row < layout.rows + borderWidth; row++) {
    for (
      var column = -borderWidth;
      column < layout.columns + borderWidth;
      column++
    ) {
      final insideGrid =
          column >= 0 &&
          column < layout.columns &&
          row >= 0 &&
          row < layout.rows;
      if (insideGrid) continue;
      final key = _forestKey(layout, column, row);
      props.add((column: column, row: row, assetKey: key));
    }
  }

  final occupied = _occupiedCells(layout);
  for (var row = 0; row < layout.rows; row++) {
    for (var column = 0; column < layout.columns; column++) {
      final cell = TownCell(column, row);
      final freeGrass =
          layout.groundAt(cell) == TownGround.grass && !occupied.contains(cell);
      if (!freeGrass) continue;
      if (random.nextDouble() >= TownScatter.inTownDensity) continue;
      final key = _inTownKey(random.nextDouble());
      props.add((column: column, row: row, assetKey: key));
    }
  }

  return TownScatter(props: List.unmodifiable(props), borderWidth: borderWidth);
}

/// The forest tile for a border cell: an edge tile on the ring's innermost
/// cells (not its corners, which the pack has no tile for), body elsewhere.
String _forestKey(TownLayout layout, int column, int row) {
  final besideColumns = column >= 0 && column < layout.columns;
  final besideRows = row >= 0 && row < layout.rows;
  if (besideColumns && row == -1) return TownScatter.forestSouthEdgeKey;
  if (besideColumns && row == layout.rows) return TownScatter.forestNorthEdgeKey;
  if (besideRows && column == -1) return TownScatter.forestEastEdgeKey;
  if (besideRows && column == layout.columns) {
    return TownScatter.forestWestEdgeKey;
  }
  return TownScatter.forestKey;
}

/// The in-town prop a [roll] in [0, 1) picks from [TownScatter.inTownProps].
String _inTownKey(double roll) {
  var threshold = 0.0;
  for (final (key, share) in TownScatter.inTownProps) {
    threshold += share;
    if (roll < threshold) return key;
  }
  return TownScatter.inTownProps.first.$1;
}

/// Every cell something already stands on (or overhangs).
Set<TownCell> _occupiedCells(TownLayout layout) => {
  for (final origin in [...layout.plotOrigins, ...layout.houseOrigins])
    for (var column = 0; column < TownLayout.footprint; column++)
      // A tall building overhangs the row above its plot.
      for (var row = -1; row < TownLayout.footprint; row++)
        TownCell(origin.column + column, origin.row + row),
  if (layout.hasGate) layout.gate,
  ...layout.statueSpots,
  ...layout.treeCells,
  for (final landmark in layout.landmarks)
    for (var column = 0; column < landmark.columns; column++)
      for (var row = 0; row < landmark.rows; row++)
        TownCell(landmark.origin.column + column, landmark.origin.row + row),
};

/// A scatter seed every device of a household agrees on: the 32-bit FNV-1a
/// hash of the smallest of [memberIds] (the roster order differs per device,
/// the smallest id never does), or 0 before there is anyone. A fixed hash,
/// never `String.hashCode`, so it is the same on every platform and run.
int townScatterSeed(Iterable<String> memberIds) {
  if (memberIds.isEmpty) return 0;
  final smallest = memberIds.reduce(
    (first, second) => first.compareTo(second) <= 0 ? first : second,
  );
  const offsetBasis = 0x811c9dc5;
  const prime = 0x01000193;
  var hash = offsetBasis;
  for (final codeUnit in smallest.codeUnits) {
    hash = ((hash ^ codeUnit) * prime) & 0xffffffff;
  }
  return hash;
}
