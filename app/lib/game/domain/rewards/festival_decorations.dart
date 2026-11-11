/// The grand festival's decoration: a week with every weekday logged brings
/// one decoration from the catalogue's festival pool (items tagged
/// `festival`) to the town. Like streak milestones it needs the catalogue,
/// so the reward runner calls it after the engine, from the festivals the
/// projection holds. Granted once per person per week (a deterministic
/// acquisition id), rolled with the RNG seeded by that id so every device
/// picks the same item, and a decoration the household already has becomes
/// gems instead, as in a chest. Never taken back.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../clock.dart';
import '../decor/catalog.dart';
import '../decor/decor_values.dart';
import '../game_event.dart';
import '../game_rng.dart';
import '../game_state.dart';
import '../game_values.dart';
import '../reason_codes.dart';
import 'reward_engine.dart';

/// The id of [personId]'s grand-festival decoration for [week]: the
/// `ItemAcquired` acquisition id, or the `RewardGranted` reward id when it
/// came as gems for a duplicate.
String festivalDecorAcquisitionId(String personId, GameDay week) =>
    'festival.decor:$personId:${week.toKey()}';

class FestivalDecorations {
  const FestivalDecorations();

  List<GameEvent> evaluate(
    GameState state,
    Party party,
    DecorCatalog catalog,
    Clock clock,
    GameEventStamp stamp,
  ) {
    final pool = [...catalog.festivalPool]
      ..sort((first, second) => first.id.compareTo(second.id));
    if (pool.isEmpty) return const [];
    final now = clock.now();
    final grants = <GameEvent>[];
    for (final adult in party.adventurers) {
      final who = adult.memberId;
      final person = state.person(who);
      final grandWeeks = [
        for (final entry in person.festivals.entries)
          if (entry.value == FestivalTier.grandFestival) entry.key,
      ]..sort();
      for (final week in grandWeeks) {
        final grantId = festivalDecorAcquisitionId(who, week);
        if (state.decor.seenAcquisitionIds.contains(grantId) ||
            person.seenRewardIds.contains(grantId)) {
          continue;
        }
        final item = GameRng.forEvent(grantId).pick(pool);
        final alreadyOwned = item.placeableInTown
            ? state.decor.townOwned.containsKey(item.id)
            : state.decor.ownedCount(who, item.id) > 0;
        grants.add(
          alreadyOwned
              ? RewardGranted(
                  eventId: stamp.newEventId(),
                  deviceId: stamp.deviceId,
                  actorId: who,
                  occurredAt: now,
                  createdAt: now,
                  rewardId: grantId,
                  kind: 'gems',
                  gems: Balance.duplicateDecorGems,
                  materials: const MaterialBundle.empty(),
                  tokens: 0,
                  reasonCode: GameReasonCodes.festival,
                  sourceLedgerEventIds: const [],
                )
              : ItemAcquired(
                  eventId: stamp.newEventId(),
                  deviceId: stamp.deviceId,
                  actorId: who,
                  occurredAt: now,
                  createdAt: now,
                  acquisitionId: grantId,
                  itemId: item.id,
                  // An existing source, so older builds still decode it.
                  source: DecorSource.milestone,
                  toTown: item.placeableInTown,
                ),
        );
      }
    }
    return grants;
  }
}
