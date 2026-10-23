/// A person's room. Its owner can rearrange it: pick or drag an item from
/// the tray onto a free spot, tap a placed item to rotate or put it away,
/// and change outfit in the wardrobe. Visitors only look.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/asset_registry.dart';
import '../../assets/game_asset_scope.dart';
import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/decor/decor_values.dart';
import '../../domain/game_state.dart';
import '../../scenes/room/room_game.dart';
import '../../scenes/room/room_scene_view.dart';
import '../hall_common.dart';
import '../hall_ledger_view.dart';
import 'inventory_tray.dart';
import 'wardrobe_sheet.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.personId});

  final String personId;

  static Future<void> open(BuildContext context, String personId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RoomScreen(personId: personId)),
      );

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  bool _editing = false;
  DecorItem? _picked;

  Future<void> _place(
    DecorItem item,
    int column,
    int row, {
    String? placementId,
    int rotation = 0,
  }) async {
    await runHallCommand(
      context,
      ref,
      (service) => service.placeItem(
        itemId: item.id,
        space: DecorSpace.room,
        column: column,
        row: row,
        rotation: rotation,
        placementId: placementId,
      ),
    );
    if (mounted) setState(() => _picked = null);
  }

  Future<void> _showPlacedItemActions(RoomItemView itemView) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.rotate_right),
              title: const Text('Rotate'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(
                  _place(
                    itemView.item,
                    itemView.placement.column,
                    itemView.placement.row,
                    placementId: itemView.placement.placementId,
                    rotation: (itemView.placement.rotation + 1) % 4,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Put away'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(
                  runHallCommand(
                    context,
                    ref,
                    (service) =>
                        service.storePlacement(itemView.placement.placementId),
                  ),
                );
              },
            ),
          ],
        ),
      );

  void _onCellTap(RoomView view, int column, int row) {
    if (!_editing) return;
    final picked = _picked;
    if (picked != null) {
      unawaited(_place(picked, column, row));
      return;
    }
    final existing = view.itemAt(column, row);
    if (existing != null) unawaited(_showPlacedItemActions(existing));
  }

  @override
  Widget build(BuildContext context) {
    final ledgerView = ref.watch(hallLedgerViewProvider);
    final viewerId = ledgerView.meId ?? '';
    final ownerName =
        ledgerView.adults
            .where((adult) => adult.memberId == widget.personId)
            .map((adult) => adult.name)
            .firstOrNull ??
        'Home';
    final game = ref.watch(gameStateProvider).value ?? GameState.initial();
    final catalog = ref.watch(decorCatalogProvider).value ?? DecorCatalog.empty;
    final registryLoad = ref.watch(gameAssetRegistryProvider);
    final view = RoomView.from(
      game,
      catalog,
      personId: widget.personId,
      ownerName: ownerName,
      viewerId: viewerId,
    );

    return AdventureSpriteScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            view.titleName == null
                ? "$ownerName's room"
                : '$ownerName, ${view.titleName}',
          ),
          actions: [
            if (view.editable)
              IconButton(
                tooltip: 'Wardrobe',
                icon: const Icon(Icons.checkroom),
                onPressed: () => showWardrobeSheet(context, widget.personId),
              ),
            if (view.editable)
              TextButton(
                onPressed: () => setState(() {
                  _editing = !_editing;
                  _picked = null;
                }),
                child: Text(_editing ? 'Done' : 'Edit room'),
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: registryLoad.isLoading && !registryLoad.hasValue
                  // The scene reads its art once, so wait for the registry.
                  ? const ColoredBox(color: Color(0xFF30346D))
                  : RoomSceneView(
                      key: const ValueKey('room-scene'),
                      view: view,
                      registry: registryLoad.value ?? AssetRegistry.bundled,
                      onDrop: (item, column, row) {
                        if (_editing) unawaited(_place(item, column, row));
                      },
                      onCellTap: (column, row) => _onCellTap(view, column, row),
                    ),
            ),
            if (_editing) ...[
              if (_picked != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Tap a free spot to place ${_picked!.name}.'),
                ),
              InventoryTray(
                space: DecorSpace.room,
                personId: widget.personId,
                onPick: (item) => setState(() => _picked = item),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
