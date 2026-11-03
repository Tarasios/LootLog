/// A sunken strip of the items you can place in a room or the town: each a
/// small parchment card with its sprite, name and spare count. Drag one onto
/// the scene, or tap it and then tap a spot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/pack_sprite.dart';
import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/decor/decor_values.dart';
import '../../domain/game_state.dart';
import '../kit/kit.dart';

/// The width of one item's card in the strip.
const double _kItemWidth = 96;

/// The strip's inner height: a card with its sprite, name and count.
const double _kStripHeight = 104;

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
    final decor = (ref.watch(gameStateProvider).value ?? GameState.initial()).decor;
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
      return const InsetWell(
        key: ValueKey('inventory-tray'),
        child: Text('Nothing to place right now. The shop and chests bring new things.'),
      );
    }
    return InsetWell(
      key: const ValueKey('inventory-tray'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: SizedBox(
        height: _kStripHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(width: AdventureTokens.gap),
          itemBuilder: (context, index) {
            final (item, available) = entries[index];
            return Draggable<DecorItem>(
              data: item,
              feedback: PackSprite(assetKey: item.assetKey, scale: 3),
              child: KitPressable(
                key: ValueKey('tray-${item.id}'),
                onPressed: () => onPick(item),
                builder: (context, pressed) =>
                    _TrayItemCard(item: item, available: available, pressed: pressed),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One item in the strip: sprite, name, and "×2" when there are spares.
class _TrayItemCard extends StatelessWidget {
  const _TrayItemCard({required this.item, required this.available, required this.pressed});

  final DecorItem item;
  final int available;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AdventureTokens.label(context);
    return SizedBox(
      width: _kItemWidth,
      child: Transform.translate(
        offset: Offset(0, pressed ? 2 : 0),
        child: ParchmentCard(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PackSprite(assetKey: item.assetKey, scale: 3),
              const SizedBox(height: 2),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
              Text(
                available > 1 ? '×$available' : '',
                style: labelStyle.copyWith(color: AdventureTokens.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
