/// Today's shop: a seeded pick from the catalogue's shop pool. The seed is
/// the household-timezone date, so both phones show the same six items.
/// Pure Dart.
library;

import '../../config/balance.dart';
import '../game_rng.dart';
import '../game_values.dart';
import 'catalog.dart';

class ShopRotation {
  const ShopRotation._();

  static List<DecorItem> forDay(DecorCatalog catalog, GameDay day) {
    final pool = [...catalog.shopPool]..sort((first, second) => first.id.compareTo(second.id));
    if (pool.isEmpty) return const [];
    final rng = GameRng(stableHash32('shop:${day.toKey()}'));
    final picked = <DecorItem>[];
    final cheap = [for (final item in pool) if (item.priceGems! <= Balance.shopCheapMaxPriceGems) item];
    if (cheap.isNotEmpty) picked.add(rng.pick(cheap));
    final remaining = [for (final item in pool) if (!picked.contains(item)) item];
    while (picked.length < Balance.shopSlotCount && remaining.isNotEmpty) {
      picked.add(remaining.removeAt(rng.nextInt(remaining.length)));
    }
    return List.unmodifiable(picked);
  }
}
