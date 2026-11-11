/// Game events for the town loop tests and goldens: today's visitor, a
/// weekend festival with its gift, and a quiet stretch nobody logged.
library;

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

List<GameEvent> festivalEvents({FestivalTier tier = FestivalTier.fair}) => [
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
  granted(
    'f0002',
    when: before(const Duration(minutes: 40)),
    rewardId: festivalRewardId(robin, kWeek),
    gems: 6,
    kind: 'festival',
    reasonCode: GameReasonCodes.festival,
  ),
];

/// Nobody logged today or yesterday: a Lumberyard built yesterday morning.
List<GameEvent> quietEvents() => [
  granted('q0001', when: before(const Duration(days: 3)), rewardId: 'seed', gems: 10),
  claimed('q0002', 'seed', when: before(const Duration(days: 3))),
  built('q0003', 0, BuildingType.lumberyard, when: before(const Duration(days: 1, hours: 2))),
];
