/// Picks a spot on the room's grid without the pixel scene, for the text
/// tier: a game dialog with one small square per cell, the cells other things
/// cover shown in wood with their first letter and disabled. The command
/// still checks the fit, so a spot too small for a big item is refused with a
/// plain reason.
library;

import 'package:flutter/material.dart';

import '../kit/kit.dart';

/// Each cell's side, at most; the grid shrinks on a narrow screen.
const double _kMaxCellSide = 32;

/// Shows the picker; the chosen (column, row), or null when dismissed.
/// [takenBy] names what covers a cell, or null when it is free.
Future<(int, int)?> showCellPicker(
  BuildContext context, {
  required String title,
  required int columns,
  required int rows,
  required String? Function(int column, int row) takenBy,
}) =>
    showGameDialog<(int, int)>(
      context,
      builder: (dialogContext) => GameDialog(
        title: title,
        maxWidth: 480,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: columns * (_kMaxCellSide + 2)),
            child: GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
        ),
        actions: [
          WoodButton(
            label: 'Cancel',
            tone: WoodButtonTone.secondary,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
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
    final taken = takenBy;
    final where = 'column ${column + 1}, row ${row + 1}';
    return Semantics(
      label: taken == null ? 'Free spot, $where' : '$taken, $where',
      button: taken == null,
      child: Material(
        color: taken == null ? AdventureTokens.parchment : AdventureTokens.chest,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AdventureTokens.woodDark),
        ),
        child: InkWell(
          key: ValueKey('cell-$column-$row'),
          onTap: taken == null ? onPick : null,
          splashFactory: NoSplash.splashFactory,
          hoverColor: AdventureTokens.parchmentDark,
          child: Center(
            child: Text(
              taken == null ? '' : taken.characters.first,
              style: AdventureTokens.label(context),
            ),
          ),
        ),
      ),
    );
  }
}
