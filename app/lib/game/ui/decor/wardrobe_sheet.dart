/// The wardrobe: owned outfits and titles in a game dialog; tapping one
/// wears it and closes the wardrobe. (Kept at this path from when it was a
/// bottom sheet.)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/game_state.dart';
import '../hall_common.dart';
import '../kit/kit.dart';
import 'decor_item_tile.dart';

/// Opens [personId]'s wardrobe.
Future<void> showWardrobeDialog(BuildContext context, String personId) =>
    showGameDialog<void>(
      context,
      builder: (dialogContext) => GameDialog(
        title: 'Wardrobe',
        onClose: () => Navigator.of(dialogContext).pop(),
        body: _WardrobeList(personId: personId),
      ),
    );

class _WardrobeList extends ConsumerWidget {
  const _WardrobeList({required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(decorCatalogProvider).value ?? DecorCatalog.empty;
    final decor = (ref.watch(gameStateProvider).value ?? GameState.initial()).decor;
    final owned = [
      for (final itemId in decor.ownedByPerson[personId]?.keys ?? const <String>[])
        if (catalog.itemFor(itemId) case final DecorItem item when item.equippable) item,
    ];
    final worn = {decor.outfitOf(personId), decor.titleOf(personId)};
    if (owned.isEmpty) {
      return const Text('Outfits from the shop show up here.');
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in owned)
          DecorItemTile(
            key: ValueKey('wardrobe-${item.id}'),
            item: item,
            subtitle: item.kind == DecorKind.title ? 'Title' : 'Outfit',
            trailing: worn.contains(item.id)
                ? const FloatingTag('Worn', icon: Icons.check)
                : null,
            onTap: () async {
              final navigator = Navigator.of(context);
              await runHallCommand(context, ref, (service) => service.equipItem(item.id));
              navigator.pop();
            },
          ),
      ],
    );
  }
}
