/// Picks a spot on the room's grid without the pixel scene, for the text
/// tier: one small button per cell, the cells other things cover shown with
/// their first letter and disabled. The command still checks the fit, so a
/// spot too small for a big item is refused with a plain reason.
library;

import 'package:flutter/material.dart';

/// Shows the picker; the chosen (column, row), or null when dismissed.
/// [takenBy] names what covers a cell, or null when it is free.
Future<(int, int)?> showCellPicker(
  BuildContext context, {
  required String title,
  required int columns,
  required int rows,
  required String? Function(int column, int row) takenBy,
}) =>
    showDialog<(int, int)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: columns * 30,
          child: GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            children: [
              for (var row = 0; row < rows; row++)
                for (var column = 0; column < columns; column++)
                  _Cell(
                    column: column,
                    row: row,
                    takenBy: takenBy(column, row),
                    onPick: () => Navigator.of(dialogContext).pop((column, row)),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
        ],
      ),
    );

class _Cell extends StatelessWidget {
  const _Cell({required this.column, required this.row, required this.takenBy, required this.onPick});

  final int column;
  final int row;
  final String? takenBy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final taken = takenBy;
    final where = 'column ${column + 1}, row ${row + 1}';
    return Semantics(
      label: taken == null ? 'Free spot, $where' : '$taken, $where',
      button: taken == null,
      child: Material(
        color: taken == null ? scheme.surfaceContainerHighest : scheme.secondaryContainer,
        child: InkWell(
          key: ValueKey('cell-$column-$row'),
          onTap: taken == null ? onPick : null,
          child: Center(
            child: Text(taken == null ? '' : taken.characters.first, style: Theme.of(context).textTheme.labelSmall),
          ),
        ),
      ),
    );
  }
}
