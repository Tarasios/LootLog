/// The pictures of reached goals, for the trophies in rooms and the statues
/// in the town square. Read-only: the ledger names each goal's picture, the
/// blob store holds the bytes, and a goal whose picture is missing or
/// unreadable simply keeps the plain stand (asset ladder, never a crash).
library;

import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../scenes/scene_pictures.dart' show ScenePictures;

/// questId → picture sha256 for every reached, still-standing goal that has
/// a custom picture.
final goalPictureShasProvider = Provider<Map<String, String>>((ref) {
  final household = ref.watch(householdStateProvider).value;
  if (household == null) return const {};
  return {
    for (final quest in household.quests.values)
      if (quest.completed && !quest.abandoned && quest.customSpriteSha256 != null)
        quest.questId: quest.customSpriteSha256!,
  };
});

/// The decoded pictures by sha256, loaded once per distinct set of pictures.
/// They are disposed when the set changes (or the provider goes away);
/// scenes draw from their own clones ([ScenePictures]), so disposing these
/// never pulls an image out from under a frame. Read it with
/// `unwrapPrevious()` so a reload never hands out the disposed set.
final goalPictureImagesProvider = FutureProvider<Map<String, ui.Image>>((ref) async {
  // Rebuilt only when the set of pictures changes, not on every ledger tick.
  final shaKey = ref.watch(
    goalPictureShasProvider.select((shas) => (shas.values.toSet().toList()..sort()).join(',')),
  );
  final images = <String, ui.Image>{};
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    for (final image in images.values) {
      image.dispose();
    }
  });
  for (final sha in shaKey.isEmpty ? const <String>[] : shaKey.split(',')) {
    try {
      final codec = await ui.instantiateImageCodec(await ref.read(blobStoreProvider).read(sha));
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      if (disposed) {
        image.dispose();
        continue;
      }
      images[sha] = image;
    } on Object {
      // A missing or unreadable picture leaves that trophy on its plain stand.
      continue;
    }
  }
  return images;
});
