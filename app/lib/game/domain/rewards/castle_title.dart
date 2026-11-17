/// The Castle's title: an Adventure adult whose Castle stands finished
/// (`town/castle.dart`) gets the catalogue's castle title, once, and keeps
/// it for good. Like the streak milestones it needs the decoration
/// catalogue, so the data layer runs it after the reward engine. Pure Dart.
library;

import '../clock.dart';
import '../decor/catalog.dart';
import '../decor/decor_values.dart';
import '../game_event.dart';
import '../game_state.dart';
import 'reward_engine.dart';

/// The catalogue id of the finished Castle's title.
const String kCastleTitleItemId = 'castle_title';

/// The acquisition id of [personId]'s castle title: one per person.
String castleTitleAcquisitionId(String personId) => 'castle.title:$personId';

class CastleTitle {
  const CastleTitle();

  List<GameEvent> evaluate(
    GameState state,
    Party party,
    DecorCatalog catalog,
    Clock clock,
    GameEventStamp stamp,
  ) {
    final now = clock.now();
    final item = catalog.itemFor(kCastleTitleItemId);
    if (item == null) return const [];
    return [
      for (final adult in party.adventurers)
        if (state.townOf(adult.memberId).castle.isCompleteAt(now) &&
            !state.decor.seenAcquisitionIds.contains(castleTitleAcquisitionId(adult.memberId)))
          ItemAcquired(
            eventId: stamp.newEventId(),
            deviceId: stamp.deviceId,
            actorId: adult.memberId,
            occurredAt: now,
            createdAt: now,
            acquisitionId: castleTitleAcquisitionId(adult.memberId),
            itemId: kCastleTitleItemId,
            source: DecorSource.milestone,
            toTown: item.placeableInTown,
          ),
    ];
  }
}
