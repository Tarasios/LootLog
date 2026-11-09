/// Cuts a [SpriteRegion] into its sheet cells for drawing. A sheet with
/// spacing has transparent gaps between cells, so a multi-cell sprite copied
/// as one rectangle would show a seam; drawing it cell by cell, skipping the
/// gaps, packs the cells edge to edge instead.
library;

import 'dart:ui';

import 'sprite_region.dart';

/// One sheet cell of a region and where it lands.
typedef RegionCell = ({Rect source, Rect destination});

/// The cells of [region], row by row, each with its rectangle on the sheet
/// and its share of [destination]: the cells divide [destination] evenly and
/// abut, whatever the sheet's spacing.
List<RegionCell> regionCellRects(SpriteRegion region, Rect destination) {
  final cellWidth = destination.width / region.columns;
  final cellHeight = destination.height / region.rows;
  final cellSize = region.cellSize.toDouble();
  final pitch = region.cellSize + region.spacing;
  return [
    for (var rowOffset = 0; rowOffset < region.rows; rowOffset++)
      for (var columnOffset = 0; columnOffset < region.columns; columnOffset++)
        (
          source: Rect.fromLTWH(
            (region.left + columnOffset * pitch).toDouble(),
            (region.top + rowOffset * pitch).toDouble(),
            cellSize,
            cellSize,
          ),
          destination: Rect.fromLTWH(
            destination.left + columnOffset * cellWidth,
            destination.top + rowOffset * cellHeight,
            cellWidth,
            cellHeight,
          ),
        ),
  ];
}

/// Draws [region] of [sheet] into [destination] cell by cell (see
/// [regionCellRects]) with [paint].
void drawRegionCells(Canvas canvas, Image sheet, SpriteRegion region, Rect destination, Paint paint) {
  for (final cell in regionCellRects(region, destination)) {
    canvas.drawImageRect(sheet, cell.source, cell.destination, paint);
  }
}
