/// The room in the text tier (asset ladder tier 3): the things placed in it
/// as a list, each with move, rotate and put away for the owner. Nothing
/// here needs the pixel scene.
library;

import 'package:flutter/material.dart';

import '../../scenes/room/room_game.dart';

class RoomTextBody extends StatelessWidget {
  const RoomTextBody({
    super.key,
    required this.view,
    required this.editing,
    required this.onMove,
    required this.onRotate,
    required this.onPutAway,
  });

  final RoomView view;

  /// The owner is rearranging: each row offers its actions.
  final bool editing;
  final void Function(RoomItemView item) onMove;
  final void Function(RoomItemView item) onRotate;
  final void Function(RoomItemView item) onPutAway;

  static String _where(RoomItemView item) {
    final placement = item.placement;
    final turned = placement.rotation == 0 ? '' : ' · turned';
    return 'Column ${placement.column + 1}, row ${placement.row + 1}$turned';
  }

  @override
  Widget build(BuildContext context) => ListView(
        key: const ValueKey('room-text'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            view.items.isEmpty
                ? 'The room is bare for now.'
                : '${view.items.length} thing${view.items.length == 1 ? '' : 's'} in the room.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final item in view.items)
            ListTile(
              key: ValueKey('room-item-${item.placement.placementId}'),
              title: Text(item.item.name),
              subtitle: Text(_where(item)),
              trailing: editing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(tooltip: 'Move', icon: const Icon(Icons.open_with), onPressed: () => onMove(item)),
                        IconButton(tooltip: 'Rotate', icon: const Icon(Icons.rotate_right), onPressed: () => onRotate(item)),
                        IconButton(
                          tooltip: 'Put away',
                          icon: const Icon(Icons.inventory_2),
                          onPressed: () => onPutAway(item),
                        ),
                      ],
                    )
                  : null,
            ),
        ],
      );
}
