/// A person's room. Its owner can rearrange it: pick or drag an item from
/// the tray onto a free spot, tap a placed item to rotate or put it away,
/// and change outfit in the wardrobe. Visitors only look. In the text tier
/// the room is a list of what is placed, with move, rotate and put away, and
/// a grid picker for spots (no pixel scene).
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/asset_registry.dart';
import '../../assets/game_asset_scope.dart';
import '../../assets/pack_sprite.dart';
import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/decor/decor_values.dart';
import '../../domain/decor/room_grid.dart';
import '../../domain/game_state.dart';
import '../../scenes/room/room_game.dart';
import '../../scenes/room/room_scene_view.dart';
import '../../skin_prefs.dart';
import '../hall_common.dart';
import '../hall_ledger_view.dart';
import '../kit/kit.dart';
import 'cell_picker.dart';
import 'goal_pictures.dart';
import 'inventory_tray.dart';
import 'room_board.dart';
import 'room_text_body.dart';
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

  Future<void> _rotate(RoomItemView itemView) => _place(
    itemView.item,
    itemView.placement.column,
    itemView.placement.row,
    placementId: itemView.placement.placementId,
    rotation: (itemView.placement.rotation + 1) % 4,
  );

  Future<void> _putAway(RoomItemView itemView) => runHallCommand(
    context,
    ref,
    (service) => service.storePlacement(itemView.placement.placementId),
  );

  /// Asks for a spot on the grid (text tier). [moving] is left out of the
  /// cells shown as taken, so it can shift over its own old spot.
  Future<(int, int)?> _pickSpot(RoomView view, String title, {RoomItemView? moving}) {
    String? takenBy(int column, int row) {
      for (final other in view.items) {
        if (identical(other, moving)) continue;
        if (other.cells.contains((column, row))) return other.item.name;
      }
      return null;
    }

    return showCellPicker(
      context,
      title: title,
      columns: RoomGrid.columns,
      rows: RoomGrid.rows,
      takenBy: takenBy,
    );
  }

  Future<void> _move(RoomView view, RoomItemView itemView) async {
    final spot = await _pickSpot(view, 'Move ${itemView.item.name} to…', moving: itemView);
    if (spot == null || !mounted) return;
    await _place(
      itemView.item,
      spot.$1,
      spot.$2,
      placementId: itemView.placement.placementId,
      rotation: itemView.placement.rotation,
    );
  }

  Future<void> _placePicked(RoomView view, DecorItem item) async {
    final spot = await _pickSpot(view, 'Place ${item.name} at…');
    if (spot == null || !mounted) return;
    await _place(item, spot.$1, spot.$2);
  }

  Future<void> _showPlacedItemActions(RoomItemView itemView) => showGameDialog<void>(
        context,
        builder: (dialogContext) {
          void closeThen(Future<void> Function(RoomItemView) action) {
            Navigator.of(dialogContext).pop();
            unawaited(action(itemView));
          }

          return GameDialog(
            title: itemView.item.name,
            onClose: () => Navigator.of(dialogContext).pop(),
            scene: Center(child: PackSprite(assetKey: itemView.item.assetKey, scale: 4)),
            body: const Text('Turn it a quarter, or put it back in your inventory.'),
            actions: [
              WoodButton(
                label: 'Put away',
                tone: WoodButtonTone.secondary,
                onPressed: () => closeThen(_putAway),
              ),
              WoodButton(label: 'Rotate', onPressed: () => closeThen(_rotate)),
            ],
          );
        },
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
      goalPictures: ref.watch(goalPictureShasProvider),
    );
    final textTier = ref.watch(adventureTierProvider) == AdventureTier.text;
    final goalPictures = textTier
        ? const <String, ui.Image>{}
        : ref.watch(goalPictureImagesProvider).unwrapPrevious().value ?? const {};

    final narrow = MediaQuery.sizeOf(context).width < AdventureTokens.narrowScreen;
    final editingHint = _picked == null || textTier ? null : 'Tap a free spot to place ${_picked!.name}.';
    return AdventureSpriteScope(
      child: Scaffold(
        backgroundColor: AdventureTokens.parchmentDark,
        body: Column(
          children: [
            GameScreenHeader(
              title: view.titleName == null ? "$ownerName's room" : '$ownerName, ${view.titleName}',
              trailing: [
                if (view.editable) ...[
                  Tooltip(
                    message: 'Wardrobe',
                    child: HudButton(
                      label: 'Wardrobe',
                      icon: Icons.checkroom,
                      onPressed: () => showWardrobeDialog(context, widget.personId),
                    ),
                  ),
                  HudButton(
                    key: const ValueKey('room-edit-toggle'),
                    label: _editing ? 'Done' : 'Edit room',
                    icon: _editing ? Icons.check : Icons.edit,
                    onPressed: () => setState(() {
                      _editing = !_editing;
                      _picked = null;
                    }),
                  ),
                ],
              ],
            ),
            Expanded(
              child: Padding(
                // A phone gives the board its full width: the room needs
                // 384 px to draw at twice its size.
                padding: EdgeInsets.symmetric(
                  horizontal: narrow ? 0 : AdventureTokens.gap,
                  vertical: AdventureTokens.gap,
                ),
                child: textTier
                    ? RoomBoard(
                        fallback: RoomTextBody(
                          view: view,
                          editing: _editing,
                          onMove: (item) => unawaited(_move(view, item)),
                          onRotate: (item) => unawaited(_rotate(item)),
                          onPutAway: (item) => unawaited(_putAway(item)),
                        ),
                      )
                    : registryLoad.isLoading && !registryLoad.hasValue
                    // The scene reads its art once, so wait for the registry.
                    ? const RoomBoard()
                    : RoomBoard(
                        scene: RoomSceneView(
                          key: const ValueKey('room-scene'),
                          view: view,
                          registry: registryLoad.value ?? AssetRegistry.bundled,
                          pictures: goalPictures,
                          onDrop: (item, column, row) {
                            if (_editing) unawaited(_place(item, column, row));
                          },
                          onCellTap: (column, row) => _onCellTap(view, column, row),
                        ),
                      ),
              ),
            ),
            if (_editing)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AdventureTokens.gap,
                    0,
                    AdventureTokens.gap,
                    AdventureTokens.gap,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (editingHint != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AdventureTokens.gap),
                          child: Text(
                            editingHint,
                            key: const ValueKey('room-place-hint'),
                            textAlign: TextAlign.center,
                            style: AdventureTokens.label(context),
                          ),
                        ),
                      InventoryTray(
                        space: DecorSpace.room,
                        personId: widget.personId,
                        onPick: (item) => textTier
                            ? unawaited(_placePicked(view, item))
                            : setState(() => _picked = item),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
