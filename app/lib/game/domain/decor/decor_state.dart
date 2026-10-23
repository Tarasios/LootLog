// app/lib/game/domain/decor/decor_state.dart
/// Who owns which decorations, what is placed where, and what each person
/// wears. Part of the game projection; immutable. Pure Dart.
library;

import 'decor_values.dart';

class Placement {
  const Placement({
    required this.placementId,
    required this.itemId,
    required this.space,
    required this.ownerId,
    required this.column,
    required this.row,
    this.rotation = 0,
  });

  final String placementId;
  final String itemId;
  final DecorSpace space;

  /// The room's person for a room placement; empty for the town.
  final String ownerId;
  final int column;
  final int row;
  final int rotation;

  @override
  bool operator ==(Object other) =>
      other is Placement &&
      other.placementId == placementId &&
      other.itemId == itemId &&
      other.space == space &&
      other.ownerId == ownerId &&
      other.column == column &&
      other.row == row &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(placementId, itemId, space, ownerId, column, row, rotation);
}

class DecorState {
  const DecorState({
    this.ownedByPerson = const {},
    this.townOwned = const {},
    this.placements = const {},
    this.outfitByPerson = const {},
    this.titleByPerson = const {},
    this.seenAcquisitionIds = const {},
  });

  static const DecorState empty = DecorState();

  /// personId → itemId → copies owned (placed copies included).
  final Map<String, Map<String, int>> ownedByPerson;

  /// itemId → copies in the shared town pool (placed copies included).
  final Map<String, int> townOwned;
  final Map<String, Placement> placements;
  final Map<String, String> outfitByPerson;
  final Map<String, String> titleByPerson;
  final Set<String> seenAcquisitionIds;

  int ownedCount(String personId, String itemId) => ownedByPerson[personId]?[itemId] ?? 0;

  int _placedCount(DecorSpace space, String ownerId, String itemId) => placements.values
      .where((placement) => placement.space == space && placement.ownerId == ownerId && placement.itemId == itemId)
      .length;

  int availableCount(String personId, String itemId) =>
      ownedCount(personId, itemId) - _placedCount(DecorSpace.room, personId, itemId);

  int townAvailableCount(String itemId) => (townOwned[itemId] ?? 0) - _placedCount(DecorSpace.town, '', itemId);

  List<Placement> placementsInRoom(String personId) => [
        for (final placement in placements.values)
          if (placement.space == DecorSpace.room && placement.ownerId == personId) placement,
      ];

  List<Placement> get townPlacements => [
        for (final placement in placements.values)
          if (placement.space == DecorSpace.town) placement,
      ];

  String? outfitOf(String personId) => outfitByPerson[personId];
  String? titleOf(String personId) => titleByPerson[personId];

  DecorState acquire({required String personId, required String itemId, required bool toTown, String? acquisitionId}) {
    final seen = acquisitionId == null ? seenAcquisitionIds : {...seenAcquisitionIds, acquisitionId};
    if (toTown) {
      return _copy(
        townOwned: {...townOwned, itemId: (townOwned[itemId] ?? 0) + 1},
        seenAcquisitionIds: seen,
      );
    }
    final personItems = {...?ownedByPerson[personId]};
    personItems[itemId] = (personItems[itemId] ?? 0) + 1;
    return _copy(ownedByPerson: {...ownedByPerson, personId: personItems}, seenAcquisitionIds: seen);
  }

  DecorState place(Placement placement) => _copy(placements: {...placements, placement.placementId: placement});

  DecorState store(String placementId) => _copy(placements: {...placements}..remove(placementId));

  DecorState equipOutfit(String personId, String itemId) => _copy(outfitByPerson: {...outfitByPerson, personId: itemId});

  DecorState equipTitle(String personId, String itemId) => _copy(titleByPerson: {...titleByPerson, personId: itemId});

  DecorState _copy({
    Map<String, Map<String, int>>? ownedByPerson,
    Map<String, int>? townOwned,
    Map<String, Placement>? placements,
    Map<String, String>? outfitByPerson,
    Map<String, String>? titleByPerson,
    Set<String>? seenAcquisitionIds,
  }) =>
      DecorState(
        ownedByPerson: Map.unmodifiable(ownedByPerson ?? this.ownedByPerson),
        townOwned: Map.unmodifiable(townOwned ?? this.townOwned),
        placements: Map.unmodifiable(placements ?? this.placements),
        outfitByPerson: Map.unmodifiable(outfitByPerson ?? this.outfitByPerson),
        titleByPerson: Map.unmodifiable(titleByPerson ?? this.titleByPerson),
        seenAcquisitionIds: Set.unmodifiable(seenAcquisitionIds ?? this.seenAcquisitionIds),
      );

  @override
  bool operator ==(Object other) =>
      other is DecorState &&
      _deepEquals(other.ownedByPerson, ownedByPerson) &&
      _deepEquals(other.townOwned, townOwned) &&
      _deepEquals(other.placements, placements) &&
      _deepEquals(other.outfitByPerson, outfitByPerson) &&
      _deepEquals(other.titleByPerson, titleByPerson) &&
      other.seenAcquisitionIds.length == seenAcquisitionIds.length &&
      other.seenAcquisitionIds.containsAll(seenAcquisitionIds);

  @override
  int get hashCode => Object.hash(ownedByPerson.length, townOwned.length, placements.length);
}

bool _deepEquals(Map<Object?, Object?> first, Map<Object?, Object?> second) {
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    final other = second[entry.key];
    final value = entry.value;
    if (value is Map && other is Map) {
      if (!_deepEquals(value, other)) return false;
    } else if (other != value) {
      return false;
    }
  }
  return true;
}
