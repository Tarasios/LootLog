/// The town's Menu: a framed game dialog of wood buttons for everything that
/// is not a daily action — settings, switching to Standard, text mode,
/// decorating the town and the trophy hall. Each button closes the menu,
/// then does its thing; the shell supplies what each one does.
library;

import 'package:flutter/material.dart';

import '../kit/kit.dart';

/// What the Menu's buttons do.
class TownMenuActions {
  const TownMenuActions({
    required this.openSettings,
    required this.switchToStandard,
    required this.toggleTextMode,
    required this.toggleDecorating,
    required this.openTrophies,
    this.decorating = false,
  });

  final VoidCallback openSettings;
  final VoidCallback switchToStandard;
  final VoidCallback toggleTextMode;
  final VoidCallback toggleDecorating;
  final VoidCallback openTrophies;

  /// Whether the town is being decorated (the button then finishes it).
  final bool decorating;
}

/// Opens the Menu over the town.
Future<void> showTownMenu(BuildContext context, TownMenuActions actions) =>
    showGameDialog<void>(
      context,
      builder: (dialogContext) => TownMenuDialog(
        actions: actions,
        close: () => Navigator.of(dialogContext).pop(),
      ),
    );

class TownMenuDialog extends StatelessWidget {
  const TownMenuDialog({super.key, required this.actions, required this.close});

  final TownMenuActions actions;

  /// Closes the menu (before a button's action runs).
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    VoidCallback then(VoidCallback action) => () {
      close();
      action();
    };
    final entries = <(String, IconData, VoidCallback)>[
      ('Settings', Icons.settings, actions.openSettings),
      ('Switch to Standard', Icons.swap_horiz, actions.switchToStandard),
      ('Text mode', Icons.notes, actions.toggleTextMode),
      (
        actions.decorating ? 'Done decorating' : 'Decorate town',
        Icons.park,
        actions.toggleDecorating,
      ),
      ('Trophies', Icons.emoji_events, actions.openTrophies),
    ];
    return GameDialog(
      title: 'Menu',
      maxWidth: 380,
      onClose: close,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (label, icon, action)) in entries.indexed) ...[
            if (index > 0) const SizedBox(height: AdventureTokens.gap),
            WoodButton(label: label, icon: icon, expand: true, onPressed: then(action)),
          ],
        ],
      ),
    );
  }
}
