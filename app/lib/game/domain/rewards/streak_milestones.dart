/// Streak milestones: 7, 30 and 100 consecutive active days each unlock a
/// title and an exclusive decoration for an Adventure adult. Granted once
/// per person per milestone (deterministic acquisition ids), never taken
/// back when the streak later ends. Pure Dart.
library;

import '../../config/balance.dart';
import '../clock.dart';
import '../decor/catalog.dart';
import '../decor/decor_values.dart';
import '../game_event.dart';
import '../game_state.dart';
import 'reward_engine.dart';

String streakMilestoneAcquisitionId(String personId, int days, String itemId) =>
    'streak.milestone:$personId:$days:$itemId';

class StreakMilestones {
  const StreakMilestones();

  List<GameEvent> evaluate(
    GameState state,
    Party party,
    DecorCatalog catalog,
    Clock clock,
    GameEventStamp stamp,
  ) {
    final now = clock.now();
    final grants = <GameEvent>[];
    for (final adult in party.adventurers) {
      final streakDays = state.person(adult.memberId).streak.count;
      for (final milestoneDays in Balance.streakMilestoneDays) {
        if (streakDays < milestoneDays) continue;
        for (final itemId
            in Balance.streakMilestoneItemIds[milestoneDays] ??
                const <String>[]) {
          final acquisitionId = streakMilestoneAcquisitionId(
            adult.memberId,
            milestoneDays,
            itemId,
          );
          if (state.decor.seenAcquisitionIds.contains(acquisitionId)) continue;
          final item = catalog.itemFor(itemId);
          if (item == null) continue;
          grants.add(
            ItemAcquired(
              eventId: stamp.newEventId(),
              deviceId: stamp.deviceId,
              actorId: adult.memberId,
              occurredAt: now,
              createdAt: now,
              acquisitionId: acquisitionId,
              itemId: itemId,
              source: DecorSource.milestone,
              toTown: item.placeableInTown,
            ),
          );
        }
      }
    }
    return grants;
  }
}
