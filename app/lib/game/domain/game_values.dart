/// Value types shared by the guild-hall game events and the game projection:
/// materials, loot bundles, the glossary's closed sets (buildings, regions,
/// chests, ritual steps) and the household-local calendar day.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../domain/time.dart';

/// Thrown while decoding when a payload names a value this build does not know
/// (a region, building, material... added by a newer release). The decoder
/// catches it and keeps the whole event as an `UnknownGameEvent`, so a newer
/// device's events are stored and relayed verbatim instead of crashing sync.
class UnrecognizedGameValue extends FormatException {
  const UnrecognizedGameValue(String what, String value)
      : super('Unrecognized $what: $value');
}

/// Looks up [name] in an enum's [values], throwing [UnrecognizedGameValue] for
/// a name this build does not know.
T gameEnumByName<T extends Enum>(List<T> values, String name, String what) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw UnrecognizedGameValue(what, name);
}

/// The materials of the shared party pool (see the glossary).
enum MaterialKind { lumber, stone, ore, herbs, hide, crystal, essence, trophy }

/// An immutable amount of each material. Zero entries are dropped so two
/// bundles holding the same amounts are equal however they were built.
class MaterialBundle {
  const MaterialBundle.empty() : _amounts = const {};

  MaterialBundle(Map<MaterialKind, int> amounts)
      : _amounts = Map.unmodifiable({
          for (final k in MaterialKind.values)
            if ((amounts[k] ?? 0) != 0) k: amounts[k]!,
        });

  final Map<MaterialKind, int> _amounts;

  /// The amount of [kind] (0 when absent).
  int operator [](MaterialKind kind) => _amounts[kind] ?? 0;

  /// The non-zero entries, in [MaterialKind] declaration order.
  Map<MaterialKind, int> get amounts => _amounts;

  bool get isEmpty => _amounts.isEmpty;

  Map<String, int> toJson() => {
        for (final e in _amounts.entries) e.key.name: e.value,
      };

  static MaterialBundle fromJson(Map<String, dynamic> json) => MaterialBundle({
        for (final e in json.entries)
          gameEnumByName(MaterialKind.values, e.key, 'material'): e.value as int,
      });

  @override
  bool operator ==(Object other) =>
      other is MaterialBundle &&
      other._amounts.length == _amounts.length &&
      _amounts.entries.every((e) => other[e.key] == e.value);

  @override
  int get hashCode => Object.hashAll(
      [for (final e in _amounts.entries) Object.hash(e.key, e.value)]);

  @override
  String toString() => 'MaterialBundle(${toJson()})';
}

/// A bundle of game currencies: gems (personal wallet), materials (shared
/// pool) and streak-freeze tokens. Used for costs, chest contents and boss
/// rewards.
class Loot {
  const Loot({
    this.gems = 0,
    this.materials = const MaterialBundle.empty(),
    this.tokens = 0,
  });

  static const Loot none = Loot();

  final int gems;
  final MaterialBundle materials;
  final int tokens;

  Map<String, dynamic> toJson() => {
        'gems': gems,
        'materials': materials.toJson(),
        'tokens': tokens,
      };

  static Loot fromJson(Map<String, dynamic> json) => Loot(
        gems: json['gems'] as int? ?? 0,
        materials: MaterialBundle.fromJson(
            (json['materials'] as Map? ?? const {}).cast()),
        tokens: json['tokens'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is Loot &&
      other.gems == gems &&
      other.materials == materials &&
      other.tokens == tokens;

  @override
  int get hashCode => Object.hash(gems, materials, tokens);

  @override
  String toString() => 'Loot(${toJson()})';
}

/// Every building that can stand on a hall plot.
enum BuildingType {
  centralHall,
  scribesDesk,
  storehouse,
  forge,
  vault,
  lumberyard,
  quarry,
  mine,
  herbGarden,
  huntersLodge,
  arcaneWell,
}

/// The regions a hero can be sent on an expedition to.
enum ExpeditionRegion {
  marketCatacombs,
  tavernCellars,
  oldRoads,
  hearthstoneKeep,
  bazaarOfWhims,
  subscriptionSwamp,
  theWilds,
}

/// Chest kinds (see the glossary for what earns each).
enum ChestType { wood, iron, gold, party, spoils }

/// The month-end spoils ritual steps that precede the seasonal boss fight.
enum RitualStep { reconcile, review, plan, contribute }

/// A calendar day in the household timezone, keyed `yyyy-MM-dd`. The same
/// type the ledger uses for its daily habit events.
typedef GameDay = CalendarDay;
