/// Cheers between neighbouring towns: an Adventure adult tells a neighbour
/// "well done" (`CheerSent`), at most once a day for each sender and
/// neighbour, and the neighbour sees "<name> cheered your town" in their
/// inbox. Purely cosmetic: a cheer moves no gem and no material, and it is
/// never asked for or counted against anyone (design rule 7).
///
/// [planCheer] is the command's side; the projection keeps the earliest copy
/// of each [cheerId], so two devices cheering on the same day show one
/// cheer. [cheersFor] and [cheered] are the read side.
///
/// Pure Dart, zero Flutter imports.
library;

import '../commands/game_commands.dart' show GameRejection;
import '../game_state.dart';
import '../game_values.dart';

/// One cheer a town received.
class Cheer {
  const Cheer({required this.fromId, required this.toId, required this.day, required this.at});

  final String fromId;
  final String toId;

  /// The household day it was sent on.
  final GameDay day;

  /// When the earliest copy was sent.
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is Cheer &&
      other.fromId == fromId &&
      other.toId == toId &&
      other.day == day &&
      other.at == at;

  @override
  int get hashCode => Object.hash(fromId, toId, day, at);
}

/// The key of [fromId]'s cheer to [toId] on [day]: one per pair per day.
String cheerId(String fromId, String toId, GameDay day) => 'cheer:$fromId:$toId:${day.toKey()}';

/// Whether [fromId] may cheer [toId] on [day], or why not: never oneself,
/// both must be Adventure adults (in the household party; a Standard adult
/// is a supply caravan with no town), and once a day for each pair.
GameRejection? planCheer(
  GameState state, {
  required String fromId,
  required String toId,
  required GameDay day,
}) {
  if (fromId == toId) return GameRejection.cheerToSelf;
  final sender = state.people[fromId];
  final recipient = state.people[toId];
  if (sender == null ||
      recipient == null ||
      sender.partyId != kHouseholdPartyId ||
      recipient.partyId != kHouseholdPartyId) {
    return GameRejection.notANeighbour;
  }
  if (cheered(state, fromId: fromId, toId: toId, day: day)) {
    return GameRejection.alreadyCheeredToday;
  }
  return null;
}

/// Whether [fromId] already cheered [toId] on [day].
bool cheered(GameState state, {required String fromId, required String toId, required GameDay day}) =>
    state.cheers.containsKey(cheerId(fromId, toId, day));

/// The cheers [personId]'s town received, newest first (ties by sender), from
/// [since] on when given.
List<Cheer> cheersFor(GameState state, String personId, {GameDay? since}) => [
      for (final cheer in state.cheers.values)
        if (cheer.toId == personId && (since == null || cheer.day >= since)) cheer,
    ]..sort((first, second) {
        final byDay = second.day.compareTo(first.day);
        return byDay != 0 ? byDay : first.fromId.compareTo(second.fromId);
      });
