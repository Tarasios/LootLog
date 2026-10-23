/// Preloads the custom sprite blobs (member, quest and pet art) the current
/// state references into memory, for the pixelated sprite resolver.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// Reads every custom sprite blob the current state references (member, quest
/// & pet sprites) into an in-memory `sha256 -> bytes` map for
/// `AssetSpriteResolver`. Missing blobs are simply skipped — the sprite falls
/// back to a placeholder.
final customSpriteBlobsProvider =
    FutureProvider<Map<String, Uint8List>>((ref) async {
  final state = ref.watch(householdStateProvider).value;
  if (state == null) return const {};
  final blobs = ref.watch(blobStoreProvider);
  final shas = <String>{
    for (final member in state.members.values)
      if (member.customSpriteSha256 != null) member.customSpriteSha256!,
    for (final quest in state.quests.values)
      if (quest.customSpriteSha256 != null) quest.customSpriteSha256!,
    for (final pet in state.pets.values)
      if (pet.customSpriteSha256 != null) pet.customSpriteSha256!,
  };
  final out = <String, Uint8List>{};
  for (final sha in shas) {
    if (await blobs.exists(sha)) {
      out[sha] = await blobs.read(sha);
    }
  }
  return out;
});
