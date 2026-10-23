/// Keeps party membership in step with each adult's play mode: Adventure
/// adults are in the household party, Standard adults (the supply caravan)
/// are not.
///
/// The play mode is a synced ledger `CosmeticSet`; membership is the game
/// log's `PartyJoined` / `PartyLeft`. This derives the second from the first
/// and only ever appends game events. It is idempotent — an adult already in
/// the right place gets nothing — so the reward runner calls it on every run
/// (after a local write such as a mode switch, and after every sync merge).
/// Two devices racing may both append the same join; the projection treats
/// a repeated join as a no-op and a repeated leave as a harmless warning.
///
/// Pure Dart, zero Flutter imports.
library;

import 'clock.dart';
import 'commands/game_commands.dart';
import 'game_event.dart';
import 'game_state.dart';
import 'game_values.dart';
import 'rewards/reward_engine.dart';

/// The `PartyJoined` / `PartyLeft` events that bring [state] in line with
/// [party]'s play modes. Adults outside [party] are left alone.
List<GameEvent> partyMembershipEvents(
  GameState state,
  Party party,
  Clock clock,
  GameEventStamp stamp,
) {
  final out = <GameEvent>[];
  for (final adult in party.adults) {
    final commands = GameCommands(
      state: state,
      clock: clock,
      actorId: adult.memberId,
      stamp: stamp,
    );
    final current = state.person(adult.memberId).partyId;
    final GameCommandResult? result;
    if (adult.inAdventure && current != kHouseholdPartyId) {
      result = commands.joinParty();
    } else if (!adult.inAdventure && current != null) {
      result = commands.leaveParty();
    } else {
      result = null;
    }
    if (result != null && result.accepted) out.addAll(result.events);
  }
  return out;
}
