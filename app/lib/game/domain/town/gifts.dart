/// Gifts between neighbouring towns: an Adventure adult sends materials from
/// their own town to a neighbour's. Nothing is generated; materials only
/// move, and every unit is conserved.
///
/// [planGift] is the command's side: it validates the gift and works out
/// what the neighbour's Storehouse has room for, which is what the
/// `GiftSent` event stores. [moveGift] is the projection's side: it moves
/// at most what the event names, trimmed again to what the sender still
/// holds and the neighbour still has room for (two devices may race), so
/// whatever does not fit stays with the sender.
///
/// Pure Dart, zero Flutter imports.
library;

import '../commands/game_commands.dart';
import '../game_state.dart';
import '../game_values.dart';
import '../hall_rules.dart';

/// What [fromId] can send [toId] of [bundle] at [now]: the part that fits
/// the neighbour's Storehouse, or why the gift is refused. Refused for a
/// gift to oneself, to someone who is not an Adventure neighbour (unknown,
/// a Standard adult, or before the towns are split), an empty or negative
/// bundle, more than the sender holds, or a neighbour with no room at all.
({GameRejection? rejection, MaterialBundle moves}) planGift(
  GameState state, {
  required String fromId,
  required String toId,
  required MaterialBundle bundle,
  required DateTime now,
}) {
  ({GameRejection? rejection, MaterialBundle moves}) refuse(
          GameRejection why) =>
      (rejection: why, moves: const MaterialBundle.empty());

  if (toId == fromId) return refuse(GameRejection.giftToSelf);
  final recipient = state.people[toId];
  if (!state.townsSplit ||
      recipient == null ||
      recipient.partyId != kHouseholdPartyId) {
    return refuse(GameRejection.notANeighbour);
  }
  if (bundle.isEmpty || bundle.amounts.values.any((amount) => amount <= 0)) {
    return refuse(GameRejection.emptyGift);
  }
  if (!state.townOf(fromId).materials.covers(bundle)) {
    return refuse(GameRejection.notEnoughMaterials);
  }
  final fits = fitInStorehouse(state.townOf(toId), bundle, now);
  if (fits.isEmpty) return refuse(GameRejection.neighbourStorehouseFull);
  return (rejection: null, moves: fits);
}

/// Moves up to [bundle] from [sender] to [recipient] as of [at]: never more
/// than the sender holds, never past the recipient's Storehouse. [moved] is
/// what actually changed hands; the rest stays with the sender.
({HallState sender, HallState recipient, MaterialBundle moved}) moveGift({
  required HallState sender,
  required HallState recipient,
  required MaterialBundle bundle,
  required DateTime at,
}) {
  final held = MaterialBundle({
    for (final entry in bundle.amounts.entries)
      entry.key: _clamp(entry.value, sender.materials[entry.key]),
  });
  final moved = fitInStorehouse(recipient, held, at);
  return (
    sender: sender.copyWith(
      materials: MaterialBundle({
        for (final kind in MaterialKind.values)
          kind: sender.materials[kind] - moved[kind],
      }),
    ),
    recipient: recipient.copyWith(materials: recipient.materials + moved),
    moved: moved,
  );
}

int _clamp(int wanted, int held) =>
    wanted < 0 ? 0 : (wanted > held ? held : wanted);
