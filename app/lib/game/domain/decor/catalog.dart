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
  for (final prefix in const [_trophyPrefix, _statuePrefix]) {
    if (itemId.startsWith(prefix)) {
      final questId = itemId.substring(prefix.length);
      return questId.isEmpty ? null : questId;
    }
  }
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

  /// Parses the catalogue file. An entry is skipped, never thrown on, when it
  /// is not a map, lacks a string id or name, has an unknown kind or rarity,
  /// an invalid asset key, a price that is not a positive int, a footprint
  /// that is not one or two positive ints, or a non-bool `exclusive`, so one
  /// typo never empties the shop. A non-list `items` or `starterSet` reads as
  /// empty, and non-string starter ids are ignored.
  static DecorCatalog fromJson(Map<String, dynamic> json) {
    final parsed = <DecorItem>[];
    for (final entry in _entriesOf(json['items'])) {
      final item = _parseItem(entry);
      if (item != null) parsed.add(item);
    }
    final starterIds = json['starterSet'];
    return DecorCatalog(
      List.unmodifiable(parsed),
      starterItemIds: List.unmodifiable(
        starterIds is List ? starterIds.whereType<String>() : const <String>[],
      ),
    );
  }

  static List<Map<String, dynamic>> _entriesOf(Object? items) {
    if (items is! List) return const [];
    return [
      for (final entry in items)
        if (entry is Map<String, dynamic>) entry,
    ];
  }

  static DecorItem? _parseItem(Map<String, dynamic> entry) {
    final id = entry['id'];
    final name = entry['name'];
    if (id is! String || name is! String) return null;
    final kind = _byName(DecorKind.values, entry['kind']);
    final rarity = _byName(DecorRarity.values, entry['rarity']);
    final asset = entry['asset'];
    final assetKey = asset is String ? AssetKey.tryParse(asset) : null;
    final price = entry['price'];
    if (price != null && (price is! int || price <= 0)) return null;
    final exclusive = entry['exclusive'];
    if (exclusive != null && exclusive is! bool) return null;
    final footprint = _parseFootprint(entry['footprint']);
    if (kind == null || rarity == null || assetKey == null || footprint == null) return null;
    return DecorItem(
      id: id,
      name: name,
      kind: kind,
      rarity: rarity,
      assetKey: assetKey,
      priceGems: price as int?,
      footprintColumns: footprint.columns,
      footprintRows: footprint.rows,
      exclusive: exclusive as bool? ?? false,
    );
  }

  /// A footprint is absent (1x1) or one or two positive ints, `[columns]` or
  /// `[columns, rows]`. Anything else is malformed and yields null.
  static ({int columns, int rows})? _parseFootprint(Object? raw) {
    if (raw == null) return (columns: 1, rows: 1);
    if (raw is! List || raw.isEmpty || raw.length > 2) return null;
    if (raw.any((dimension) => dimension is! int || dimension <= 0)) return null;
    final columns = raw[0] as int;
    final rows = raw.length > 1 ? raw[1] as int : 1;
    return (columns: columns, rows: rows);
  }

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
