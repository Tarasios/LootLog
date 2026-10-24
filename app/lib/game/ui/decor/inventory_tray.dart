/// A horizontal strip of the items you can place in a room or the town.
/// Drag one onto the scene, or tap it and then tap a spot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/pack_sprite.dart';
import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/decor/decor_values.dart';
import '../../domain/game_state.dart';

class InventoryTray extends ConsumerWidget {
  const InventoryTray({
    super.key,
    required this.space,
    required this.personId,
    required this.onPick,
  });

  final DecorSpace space;
  final String personId;
  final void Function(DecorItem item) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(decorCatalogProvider).value ?? DecorCatalog.empty;
    final decor =
        (ref.watch(gameStateProvider).value ?? GameState.initial()).decor;
    final isTown = space == DecorSpace.town;
    final itemIds = isTown
        ? decor.townOwned.keys
        : (decor.ownedByPerson[personId]?.keys ?? const <String>[]);
    final entries = <(DecorItem, int)>[];
    for (final itemId in itemIds) {
      final item = catalog.itemFor(itemId);
      if (item == null) continue;
      final placeable = isTown ? item.placeableInTown : item.placeableInRoom;
      final available = isTown
          ? decor.townAvailableCount(itemId)
          : decor.availableCount(personId, itemId);
      if (placeable && available > 0) entries.add((item, available));
    }
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Nothing to place right now. The shop and chests bring new things.',
        ),
      );
    }
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (item, available) in entries)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Draggable<DecorItem>(
                data: item,
                feedback: PackSprite(assetKey: item.assetKey, scale: 3),
                child: InkWell(
                  key: ValueKey('tray-${item.id}'),
                  onTap: () => onPick(item),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PackSprite(assetKey: item.assetKey, scale: 3),
                      Text(item.name, style: labelStyle),
                      if (available > 1) Text('×$available', style: labelStyle),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
