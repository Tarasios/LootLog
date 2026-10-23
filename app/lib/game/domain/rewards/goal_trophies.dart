/// Goal trophies: reaching a savings goal leaves a keepsake. A personal
/// goal's trophy goes to its owner's room inventory; a shared goal becomes
/// a statue for the town square. Goals that took at least
/// [Balance.customTrophyMinRituals] month-end rituals show their own
/// picture; quicker ones get the plain trophy. Only goals completed inside
/// the month-end lookback window are rewarded, once each. Pure Dart.
///
/// Consistency, never a dollar amount, decides the picture (rule 8), nothing
/// is ever taken back (rule 3), and only Adventure adults earn (rule 7).
library;

import '../../../domain/event.dart';
import '../../../domain/state.dart';
import '../../../domain/value_types.dart';
import '../../config/balance.dart';
import '../clock.dart';
import '../decor/catalog.dart';
import '../decor/decor_values.dart';
import '../game_event.dart';
import '../game_state.dart';
import 'reward_engine.dart';

class GoalTrophies {
  const GoalTrophies();

  /// The keepsakes earned by goals completed since [atWindowStart] that the
  /// [state] has not granted yet.
  List<GameEvent> evaluate({
    required List<Event> ledger,
    required HouseholdState now,
    required HouseholdState atWindowStart,
    required GameState state,
    required Party party,
    required Clock clock,
    required GameEventStamp stamp,
  }) {
    final adventurerIds = [for (final adult in party.adventurers) adult.memberId]..sort();
    if (adventurerIds.isEmpty) return const [];
    final instant = clock.now();
    final questIds = now.quests.keys.toList()..sort();
    final grants = <GameEvent>[];
    for (final questId in questIds) {
      final quest = now.quests[questId]!;
      if (!quest.completed || quest.abandoned) continue;
      if (atWindowStart.quests[questId]?.completed ?? false) continue;
      final acquisitionId = 'trophy:$questId';
      if (state.decor.seenAcquisitionIds.contains(acquisitionId)) continue;
      final custom = _ritualMonthsFunding(ledger, questId) >= Balance.customTrophyMinRituals;
      final ownership = quest.ownership;
      if (ownership is PersonalParty) {
        if (!adventurerIds.contains(ownership.userId)) continue;
        grants.add(_grant(stamp, instant, ownership.userId, acquisitionId,
            custom ? trophyItemId(questId) : 'trophy_cup',
            toTown: false));
      } else {
        grants.add(_grant(stamp, instant, adventurerIds.first, acquisitionId,
            custom ? statueItemId(questId) : 'town_statue_plain',
            toTown: true));
      }
    }
    return grants;
  }

  /// Distinct months whose month-end allocations sent money to [questId].
  static int _ritualMonthsFunding(List<Event> ledger, String questId) => {
        for (final event in ledger)
          if (event is LeftoverAllocated &&
              event.allocations.any((allocation) {
                final destination = allocation.destination;
                return destination is QuestDestination && destination.questId == questId;
              }))
            event.month,
      }.length;

  static ItemAcquired _grant(
    GameEventStamp stamp,
    DateTime instant,
    String actorId,
    String acquisitionId,
    String itemId, {
    required bool toTown,
  }) =>
      ItemAcquired(
        eventId: stamp.newEventId(),
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: instant,
        createdAt: instant,
        acquisitionId: acquisitionId,
        itemId: itemId,
        source: DecorSource.trophy,
        toTown: toTown,
      );
}
