/// The "Decorate town" tray: the town decorations and statues you own and
/// have not yet placed, with a hint for the next tap.
library;

import 'package:flutter/material.dart';

import '../../domain/decor/catalog.dart';
import '../../domain/decor/decor_values.dart';
import '../decor/inventory_tray.dart';

class TownDecoratePanel extends StatelessWidget {
  const TownDecoratePanel({
    super.key,
    required this.personId,
    required this.picked,
    required this.onPick,
  });

  final String personId;

  /// The item waiting for a spot, if one is picked.
  final DecorItem? picked;
  final void Function(DecorItem item) onPick;

  @override
  Widget build(BuildContext context) {
    final pickedItem = picked;
    final hint = pickedItem == null
        ? 'Pick something, then tap free grass. Statues go on the square.'
        : pickedItem.kind == DecorKind.statue
            ? 'Tap a statue spot on the square to place ${pickedItem.name}.'
            : 'Tap free grass to place ${pickedItem.name}.';
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(hint, key: const ValueKey('town-decorate-hint')),
            ),
            InventoryTray(space: DecorSpace.town, personId: personId, onPick: onPick),
          ],
        ),
      ),
    );
  }
}
