/// What tapping a house, the gate or the Shop button opens. Later tasks pass
/// the real screens; until then each shows a short, friendly sheet.
library;

import 'package:flutter/material.dart';

import '../hall_common.dart';
import '../kit/kit.dart';

class TownPlaceOpeners {
  const TownPlaceOpeners({this.openRoom, this.openDungeon, this.openShop});

  final void Function(BuildContext context, String personId)? openRoom;
  final void Function(BuildContext context)? openDungeon;
  final void Function(BuildContext context)? openShop;
}

/// A short, friendly pop-up: a framed game dialog in the pixel tier, the
/// original bottom sheet in the text tier.
Future<void> showPlaceComingSheet(
  BuildContext context, {
  required String title,
  required String body,
}) {
  if (!hallDeviceTextTier(context)) {
    return showGameDialog<void>(
      context,
      builder: (dialogContext) => GameDialog(
        title: title,
        onClose: () => Navigator.of(dialogContext).pop(),
        body: Text(body, textAlign: TextAlign.center),
        actions: [
          WoodButton(
            label: 'Got it',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
  return showModalBottomSheet<void>(
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
}
