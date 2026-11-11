/// The road to the neighbouring towns: who the outpost's signpost leads to,
/// who keeps a caravan camp beside it, and how much a gift can fill. Read
/// models for the neighbour view, derived on every build; never stored.
///
/// An Adventure adult whose town stands (the towns are split and they are in
/// the household party) can be visited, sent a gift and cheered. A Standard
/// adult is a supply caravan with no town: a camp by the road, never a
/// visit, never named as missing (design rule 7).
///
/// Pure Dart, zero Flutter imports.
library;

import '../game_state.dart';
import '../game_values.dart';
import '../hall_rules.dart';
import 'town_view.dart' show TownAdult;

/// One other adult of the household, as the road sees them.
class TownNeighbour {
  const TownNeighbour({
    required this.memberId,
    required this.name,
    required this.inAdventure,
    required this.canVisit,
  });

  final String memberId;
  final String name;
  final bool inAdventure;

  /// Their town stands: the signpost leads there, and gifts and cheers go.
  final bool canVisit;

  /// A Standard adult: the supply caravan camped by the road.
  bool get isCaravan => !inAdventure;

  @override
  bool operator ==(Object other) =>
      other is TownNeighbour &&
      other.memberId == memberId &&
      other.name == name &&
      other.inAdventure == inAdventure &&
      other.canVisit == canVisit;

  @override
  int get hashCode => Object.hash(memberId, name, inAdventure, canVisit);
}

/// Every adult in [adults] other than [viewerId], in roster order. Empty in a
/// single-adult household.
List<TownNeighbour> neighboursOf(GameState state, String viewerId, List<TownAdult> adults) => [
      for (final adult in adults)
        if (adult.memberId != viewerId)
          TownNeighbour(
            memberId: adult.memberId,
            name: adult.name,
            inAdventure: adult.inAdventure,
            canVisit: adult.inAdventure &&
                state.townsSplit &&
                state.person(adult.memberId).partyId == kHouseholdPartyId,
          ),
    ];

/// How much more of [kind] [toId]'s Storehouse can take at [now]: what a
/// gift of it can fill.
int giftRoom(GameState state, String toId, MaterialKind kind, DateTime now) =>
    fitInStorehouse(state.townOf(toId), MaterialBundle({kind: 1 << 30}), now)[kind];
