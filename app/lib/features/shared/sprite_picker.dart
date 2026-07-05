/// Shared helper for the "custom sprite" affordance on quests and pets.
///
/// Opens a file picker for a PNG, runs it through the blob-pipeline sprite
/// validator/ingestor, and returns the stored sha256. On rejection it surfaces
/// a snackbar and returns null; the domain never sees an invalid sprite.
library;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/blobs/media_ingest.dart';

/// Picks a PNG sprite, ingests it, and returns its sha256 (or null if the user
/// cancelled or the file was rejected). [messenger] is captured before any await.
Future<String?> pickAndIngestSprite(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
) async {
  final actions = ref.read(householdActionsProvider);
  if (actions == null) return null;
  const typeGroup = XTypeGroup(label: 'PNG image', extensions: ['png']);
  final file = await openFile(acceptedTypeGroups: const [typeGroup]);
  if (file == null) return null;
  try {
    final bytes = await file.readAsBytes();
    return await actions.ingestSpriteBytes(bytes);
  } on SpriteRejected catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Sprite rejected: ${e.message}')));
    return null;
  } on Object catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not read that image')),
    );
    return null;
  }
}
