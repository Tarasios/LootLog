/// Game events for the town loop tests and goldens: today's visitor, a
/// weekend festival with its gift, and a quiet stretch nobody logged.
library;

import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/reason_codes.dart';
import 'package:lootlog/game/domain/town/festival.dart';

import '../hall_harness.dart';

/// Saturday 2026-10-03 (the harness's today) and its week.
const GameDay kToday = GameDay(2026, 10, 3);
const GameDay kWeek = GameDay(2026, 9, 28);

DailyEventOffered offered(
  String id, {
  DailyEventKind kind = DailyEventKind.trader,
  MaterialBundle? gives,
  Loot? receives,
  GameDay day = kToday,
}) => DailyEventOffered(
  eventId: id,
  deviceId: 'dev-1',
  actorId: robin,
  occurredAt: before(const Duration(minutes: 50)),
  createdAt: before(const Duration(minutes: 50)),
  offerId: 'daily.event:$robin:${day.toKey()}',
  day: day,
  kind: kind,
  gives: gives ?? (kind == DailyEventKind.trader ? MaterialBundle({MaterialKind.lumber: 10}) : const MaterialBundle.empty()),
  receives: receives ?? Loot(materials: MaterialBundle({MaterialKind.stone: 6})),
  flavourKey: '${kind.name}.1',
);

/// This weekend's festival at [tier]: the `FestivalHeld` and, as the rules
/// grant it, one reward per tier reached (each paying what its tier adds),
/// plus the joint bonus when [joint].
List<GameEvent> festivalEvents({FestivalTier tier = FestivalTier.fair, bool joint = false}) => [
  FestivalHeld(
    eventId: 'f0001',
    deviceId: 'dev-1',
    actorId: robin,
    occurredAt: before(const Duration(minutes: 40)),
    createdAt: before(const Duration(minutes: 40)),
    week: kWeek,
    tier: tier,
    weekdaysLogged: 3,
  ),
  for (final step in FestivalTier.values.take(tier.index + 1))
    granted(
      'f001${step.index}',
      when: before(const Duration(minutes: 40)),
      rewardId: festivalRewardId(robin, kWeek, step),
      gems: festivalTierReward(step).gems,
      materials: festivalTierReward(step).materials,
      kind: 'festival',
      reasonCode: GameReasonCodes.festival,
    ),
  if (joint)
    granted(
      'f0020',
      when: before(const Duration(minutes: 40)),
      rewardId: jointFestivalRewardId(robin, kWeek),
      gems: Balance.jointFestivalGems,
      reasonCode: GameReasonCodes.festivalJoint,
    ),
];

/// Nobody logged today or yesterday: a Lumberyard built yesterday morning.
List<GameEvent> quietEvents() => [
  granted('q0001', when: before(const Duration(days: 3)), rewardId: 'seed', gems: 10),
  claimed('q0002', 'seed', when: before(const Duration(days: 3))),
  built('q0003', 0, BuildingType.lumberyard, when: before(const Duration(days: 1, hours: 2))),
];
