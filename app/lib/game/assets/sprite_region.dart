/// One rectangle of a sprite sheet, measured in whole cells of a bundled art
/// pack (`assets/game/packs/<pack>/`). Pure Dart, zero Flutter imports.
library;

import 'asset_key.dart';

class SpriteRegion {
  const SpriteRegion({
    required this.sheetPath,
    required this.column,
    required this.row,
    this.columns = 1,
    this.rows = 1,
    this.cellSize = 16,
    this.spacing = 0,
  });

  /// The sheet's path relative to `assets/game/`.
  final String sheetPath;
  final int column;
  final int row;
  final int columns;
  final int rows;
  final int cellSize;

  /// Pixels between neighbouring cells on the sheet.
  final int spacing;

  int get left => column * (cellSize + spacing);
  int get top => row * (cellSize + spacing);
  int get width => columns * cellSize + (columns - 1) * spacing;
  int get height => rows * cellSize + (rows - 1) * spacing;

  @override
  bool operator ==(Object other) =>
      other is SpriteRegion &&
      other.sheetPath == sheetPath &&
      other.column == column &&
      other.row == row &&
      other.columns == columns &&
      other.rows == rows &&
      other.cellSize == cellSize &&
      other.spacing == spacing;

  @override
  int get hashCode => Object.hash(sheetPath, column, row, columns, rows, cellSize, spacing);
}

/// Parses one pack's `regions.json`. Entries whose key is not a valid
/// [AssetKey] or whose cell list is not `[column, row]` or
/// `[column, row, columns, rows]` are skipped, so one typo never hides a pack.
Map<String, SpriteRegion> parsePackRegions(String packFolder, Map<String, dynamic> manifest) {
  final sheetPath = 'packs/$packFolder/${manifest['sheet']}';
  final cellSize = manifest['cellSize'] as int? ?? 16;
  final spacing = manifest['spacing'] as int? ?? 0;
  final entries = (manifest['regions'] as Map? ?? const {}).cast<String, Object?>();
  final regions = <String, SpriteRegion>{};
  for (final entry in entries.entries) {
    final assetKey = AssetKey.tryParse(entry.key);
    final cell = entry.value;
    if (assetKey == null || cell is! List || (cell.length != 2 && cell.length != 4)) continue;
    final numbers = cell.whereType<int>().toList();
    if (numbers.length != cell.length) continue;
    regions[assetKey.value] = SpriteRegion(
      sheetPath: sheetPath,
      column: numbers[0],
      row: numbers[1],
      columns: numbers.length == 4 ? numbers[2] : 1,
      rows: numbers.length == 4 ? numbers[3] : 1,
      cellSize: cellSize,
      spacing: spacing,
    );
  }
  return Map.unmodifiable(regions);
}
