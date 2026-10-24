/// The town's decorations in the text tier (asset ladder tier 3): what
/// stands in the town, each with "Put away", and the tray of things to
/// place. With no scene to tap, a placed thing takes the free spot nearest
/// the middle of town (a statue the next free spot on the square); in the
/// pixel tier it can be moved later with "Decorate town".
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/decor/decor_values.dart';
import '../../domain/decor/room_grid.dart';
import '../../domain/game_state.dart';
import '../../domain/town/town_layout.dart';
import '../decor/inventory_tray.dart';
import '../hall_common.dart';
import '../hall_ledger_view.dart';

class TownDecorTextScreen extends ConsumerWidget {
  const TownDecorTextScreen({super.key});

  static Future<void> open(BuildContext context) =>
      pushHallScreen(context, const TownDecorTextScreen());

  Future<void> _place(BuildContext context, WidgetRef ref, DecorItem item) async {
    final decor = (ref.read(gameStateProvider).value ?? GameState.initial()).decor;
    final taken = {for (final placement in decor.townPlacements) (placement.column, placement.row)};
    final spot = TownDecorSpots.firstFreeSpot(TownLayout.standard, item, taken);
    if (spot == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Every spot is taken. Put something away to make room.')),
      );
      return;
    }
    await runHallCommand(
      context,
      ref,
      (service) => service.placeItem(itemId: item.id, space: DecorSpace.town, column: spot.column, row: spot.row),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(decorCatalogProvider).value ?? DecorCatalog.empty;
    final decor = (ref.watch(gameStateProvider).value ?? GameState.initial()).decor;
    final meId = ref.watch(hallLedgerViewProvider).meId ?? '';
    final placed = [
      for (final placement in decor.townPlacements)
        if (catalog.itemFor(placement.itemId) case final DecorItem item) (placement, item),
    ]..sort((first, second) => first.$1.placementId.compareTo(second.$1.placementId));
    return Scaffold(
      appBar: AppBar(title: const Text('Town decorations')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            placed.isEmpty ? 'Nothing stands in the town yet.' : 'Standing in the town',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final (placement, item) in placed)
            ListTile(
              key: ValueKey('town-decor-${placement.placementId}'),
              title: Text(item.name),
              subtitle: Text(item.kind == DecorKind.statue ? 'On the square' : 'On the grass'),
              trailing: IconButton(
                tooltip: 'Put away',
                icon: const Icon(Icons.inventory_2),
                onPressed: () => unawaited(
                  runHallCommand(context, ref, (service) => service.storePlacement(placement.placementId)),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('To place', style: Theme.of(context).textTheme.titleMedium),
          InventoryTray(
            space: DecorSpace.town,
            personId: meId,
            onPick: (item) => unawaited(_place(context, ref, item)),
          ),
        ],
      ),
    );
  }
}
