/// Owned outfits and titles; tapping one wears it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/game_state.dart';
import '../hall_common.dart';
import 'decor_item_tile.dart';

Future<void> showWardrobeSheet(BuildContext context, String personId) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _Wardrobe(personId: personId),
    );

class _Wardrobe extends ConsumerWidget {
  const _Wardrobe({required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(decorCatalogProvider).value ?? DecorCatalog.empty;
    final decor =
        (ref.watch(gameStateProvider).value ?? GameState.initial()).decor;
    final owned = [
      for (final itemId
          in decor.ownedByPerson[personId]?.keys ?? const <String>[])
        if (catalog.itemFor(itemId) case final DecorItem item
            when item.equippable)
          item,
    ];
    final worn = {decor.outfitOf(personId), decor.titleOf(personId)};
    return ListView(
      shrinkWrap: true,
      children: [
        for (final item in owned)
          InkWell(
            onTap: () async {
              final navigator = Navigator.of(context);
              await runHallCommand(
                context,
                ref,
                (service) => service.equipItem(item.id),
              );
              navigator.pop();
            },
            child: DecorItemTile(
              item: item,
              subtitle: item.kind == DecorKind.title ? 'Title' : 'Outfit',
              trailing: worn.contains(item.id) ? const Icon(Icons.check) : null,
            ),
          ),
        if (owned.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Outfits from the shop show up here.'),
          ),
      ],
    );
  }
}
