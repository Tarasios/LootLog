/// The market trade: on a day the town's adult logged a purchase or checked
/// in, a town with a Market Row stall in service gets one extra trader
/// offer beside the day's town event. Taking it is a choice; waving it off
/// costs nothing.
///
/// Like the daily town event (`daily_event.dart`) the reward engine rolls it
/// once, seeded by the id of the ledger event that opened the day, and
/// stores it in a `DailyEventOffered` with the id [marketOfferId], so every
/// device shows the same trade and the projection keeps one copy.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../game_rng.dart';
import '../game_state.dart';
import '../game_values.dart';
import 'daily_event.dart';

/// The id of [personId]'s market trade on [day]: one per person per day.
String marketOfferId(String personId, GameDay day) =>
    '$kMarketOfferIdPrefix$personId:${day.toKey()}';

/// Whether [offerId] names a market trade rather than the day's town event.
bool isMarketOfferId(String offerId) => offerId.startsWith(kMarketOfferIdPrefix);

/// The best stall tier in service in [hall] at [at] (0 when none).
int stallTierAt(HallState hall, DateTime at) =>
    hall.districts.completedCivicTier(CivicBuildingType.stall, at);

/// [personId]'s market trade for [day], rolled from [hall] as it stands at
/// [now] with the RNG seeded by [seedEventId] (the ledger event that opened
/// the day), or null with no stall in service or stores that cannot pay the
/// trader's price.
DailyOffer? rollMarketOffer({
  required String personId,
  required GameDay day,
  required String seedEventId,
  required HallState hall,
  required DateTime now,
}) {
  final stallTier = stallTierAt(hall, now);
  if (stallTier < 1) return null;
  final (:plentiful, :scarce) = tradePairOf(hall.materials);
  final gives = MaterialBundle({plentiful: Balance.marketGiveByStallTier[stallTier]});
  if (!hall.materials.covers(gives)) return null;
  final rng = GameRng.forEvent('$seedEventId:market');
  return DailyOffer(
    offerId: marketOfferId(personId, day),
    day: day,
    kind: DailyEventKind.trader,
    gives: gives,
    receives: Loot(materials: MaterialBundle({scarce: Balance.marketReceiveByStallTier[stallTier]})),
    flavourKey: rng.pick(dailyEventFlavourKeys(DailyEventKind.trader)),
  );
}
