/// The decoration catalogue: every item the shop, chests and milestones can
/// hand out, loaded from `assets/game/catalog.json` so adding an item is a
/// data change only. Goal trophies and statues are synthesized from the
/// quest id. Pure Dart, zero Flutter imports.
library;

import '../../assets/asset_key.dart';

enum DecorKind { furniture, outfit, title, townDecor, trophy, statue }

enum DecorRarity { common, uncommon, rare }

const String _trophyPrefix = 'trophy:';
const String _statuePrefix = 'statue:';

String trophyItemId(String questId) => '$_trophyPrefix$questId';
String statueItemId(String questId) => '$_statuePrefix$questId';

/// The quest a trophy or statue item celebrates, or null for other items.
String? questIdOfTrophy(String itemId) {
  if (itemId.startsWith(_trophyPrefix)) return itemId.substring(_trophyPrefix.length);
  if (itemId.startsWith(_statuePrefix)) return itemId.substring(_statuePrefix.length);
  return null;
}

class DecorItem {
  const DecorItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.rarity,
    required this.assetKey,
    this.priceGems,
    this.footprintColumns = 1,
    this.footprintRows = 1,
    this.exclusive = false,
  });

  final String id;
  final String name;
  final DecorKind kind;
  final DecorRarity rarity;
  final AssetKey assetKey;

  /// The shop price; null for items the shop never sells.
  final int? priceGems;
  final int footprintColumns;
  final int footprintRows;

  /// Only a milestone hands it out (never the shop or a chest).
  final bool exclusive;

  bool get placeableInRoom => kind == DecorKind.furniture || kind == DecorKind.trophy;
  bool get placeableInTown => kind == DecorKind.townDecor || kind == DecorKind.statue;
  bool get equippable => kind == DecorKind.outfit || kind == DecorKind.title;
}

class DecorCatalog {
  const DecorCatalog(this.items, {this.starterItemIds = const []});

  static const DecorCatalog empty = DecorCatalog([]);

  final List<DecorItem> items;
  final List<String> starterItemIds;

  DecorItem? itemFor(String itemId) {
    final questId = questIdOfTrophy(itemId);
    if (questId != null) {
      final isStatue = itemId.startsWith(_statuePrefix);
      return DecorItem(
        id: itemId,
        name: isStatue ? 'Goal statue' : 'Goal trophy',
        kind: isStatue ? DecorKind.statue : DecorKind.trophy,
        rarity: DecorRarity.rare,
        assetKey: isStatue
            ? const AssetKey('town_decor', 'statue')
            : const AssetKey('furniture', 'trophy_stand'),
        exclusive: true,
      );
    }
    for (final item in items) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  List<DecorItem> get shopPool => [
        for (final item in items)
          if (item.priceGems != null && item.rarity != DecorRarity.rare && !item.exclusive) item,
      ];

  List<DecorItem> chestPool(DecorRarity rarity) => [
        for (final item in items)
          if (item.rarity == rarity && !item.exclusive) item,
      ];

  List<DecorItem> get starterSet => [
        for (final itemId in starterItemIds)
          if (itemFor(itemId) case final DecorItem item) item,
      ];

  /// Parses the catalogue file. Entries with an unknown kind or rarity, or
  /// an invalid asset key, are skipped so one typo never empties the shop.
  static DecorCatalog fromJson(Map<String, dynamic> json) {
    final parsed = <DecorItem>[];
    for (final entry in (json['items'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final kind = _byName(DecorKind.values, entry['kind']);
      final rarity = _byName(DecorRarity.values, entry['rarity']);
      final assetKey = AssetKey.tryParse(entry['asset'] as String? ?? '');
      if (kind == null || rarity == null || assetKey == null) continue;
      final footprint = (entry['footprint'] as List?)?.cast<int>() ?? const [1, 1];
      parsed.add(DecorItem(
        id: entry['id'] as String,
        name: entry['name'] as String,
        kind: kind,
        rarity: rarity,
        assetKey: assetKey,
        priceGems: entry['price'] as int?,
        footprintColumns: footprint[0],
        footprintRows: footprint.length > 1 ? footprint[1] : 1,
        exclusive: entry['exclusive'] as bool? ?? false,
      ));
    }
    return DecorCatalog(
      List.unmodifiable(parsed),
      starterItemIds: List.unmodifiable((json['starterSet'] as List? ?? const []).cast<String>()),
    );
  }

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
