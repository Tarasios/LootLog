/// What tapping a house, the gate or the Shop button opens. Later tasks pass
/// the real screens; until then each shows a short, friendly sheet.
library;

import 'package:flutter/material.dart';

class TownPlaceOpeners {
  const TownPlaceOpeners({this.openRoom, this.openDungeon, this.openShop});

  final void Function(BuildContext context, String personId)? openRoom;
  final void Function(BuildContext context)? openDungeon;
  final void Function(BuildContext context)? openShop;
}

Future<void> showPlaceComingSheet(
  BuildContext context, {
  required String title,
  required String body,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (sheetContext) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(body),
      ],
    ),
  ),
);
