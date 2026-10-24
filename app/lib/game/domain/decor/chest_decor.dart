/// The decoration roll inside a chest: whether one drops, its rarity, which
/// item, and gems instead when it would be a duplicate. Rolled once by the
/// open-chest command with the event-seeded RNG and stored in the events.
/// Pure Dart.
library;

import '../../config/balance.dart';
import '../game_rng.dart';
import '../game_values.dart';
import 'catalog.dart';

class ChestDecorDrop {
  const ChestDecorDrop({this.item, this.duplicateGems = 0});

  static const ChestDecorDrop nothing = ChestDecorDrop();

  /// The new item, or null when nothing dropped or it was a duplicate.
  final DecorItem? item;

  /// Gems given instead of a duplicate.
  final int duplicateGems;
}

ChestDecorDrop rollChestDecor(
  GameRng rng,
  ChestType chestType,
  DecorCatalog catalog, {
  required bool Function(DecorItem item) alreadyOwned,
}) {
  if (!rng.chance(Balance.chestDecorChancePermille[chestType] ?? 0)) {
    return ChestDecorDrop.nothing;
  }
  final rarityRoll = rng.nextInt(1000);
  final rareCutoff = Balance.chestRareChancePermille[chestType] ?? 0;
  final uncommonCutoff =
      rareCutoff + (Balance.chestUncommonChancePermille[chestType] ?? 0);
  final rarity = rarityRoll < rareCutoff
      ? DecorRarity.rare
      : rarityRoll < uncommonCutoff
      ? DecorRarity.uncommon
      : DecorRarity.common;
  var pool = catalog.chestPool(rarity);
  if (pool.isEmpty) pool = catalog.chestPool(DecorRarity.common);
  if (pool.isEmpty) return ChestDecorDrop.nothing;
  final sorted = [...pool]
    ..sort((first, second) => first.id.compareTo(second.id));
  final item = rng.pick(sorted);
  if (alreadyOwned(item)) {
    return const ChestDecorDrop(duplicateGems: Balance.duplicateDecorGems);
  }
  return ChestDecorDrop(item: item);
}
