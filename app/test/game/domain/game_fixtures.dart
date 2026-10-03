/// Shared builders for the guild-hall game-domain tests. Every event gets a
/// deterministic id and a timestamp a fixed number of minutes after a base
/// instant, so tests read as a timeline.
library;

import 'package:lootlog/domain/time.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_values.dart';

/// Noon in Vancouver on 2026-10-01 (19:00 UTC, PDT).
final DateTime kBase = DateTime.utc(2026, 10, 1, 19);

DateTime at(int minutes) => kBase.add(Duration(minutes: minutes));

DateTime onDay(int dayOffset) => kBase.add(Duration(days: dayOffset));

const String robin = 'u1';
const String sam = 'u2';

RewardGranted granted(
  String id, {
  required DateTime when,
  String actor = robin,
  String? rewardId,
  int gems = 0,
  MaterialBundle materials = const MaterialBundle.empty(),
  int tokens = 0,
  String reasonCode = 'test.reward',
  String kind = 'gems',
}) =>
    RewardGranted(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      rewardId: rewardId ?? 'reward-$id',
      kind: kind,
      gems: gems,
      materials: materials,
      tokens: tokens,
      reasonCode: reasonCode,
      sourceLedgerEventIds: const ['ledger-1'],
    );

RewardClaimed claimed(String id, String rewardId,
        {required DateTime when, String actor = robin}) =>
    RewardClaimed(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      rewardId: rewardId,
    );

PlotUnlocked unlocked(String id, int plot,
        {required DateTime when, int gemCost = 0, String actor = robin}) =>
    PlotUnlocked(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      plotIndex: plot,
      gemCost: gemCost,
    );

BuildingStarted built(
  String id,
  int plot,
  BuildingType type, {
  required DateTime when,
  int tier = 1,
  Loot cost = Loot.none,
  DateTime? completesAt,
  String actor = robin,
}) =>
    BuildingStarted(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      plotIndex: plot,
      buildingType: type,
      tier: tier,
      cost: cost,
      completesAt: completesAt ?? when,
    );

MaterialsCollected collected(String id, String buildingId, MaterialBundle amounts,
        {required DateTime when, String actor = robin}) =>
    MaterialsCollected(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      buildingId: buildingId,
      amounts: amounts,
    );

ChestGranted chestGranted(String id, String chestId, ChestType type,
        {required DateTime when, String actor = robin}) =>
    ChestGranted(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      chestId: chestId,
      chestType: type,
      reasonCode: 'weekly.checkin',
    );

ChestOpened chestOpened(String id, String chestId, Loot contents,
        {required DateTime when, String actor = robin}) =>
    ChestOpened(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      chestId: chestId,
      contents: contents,
    );

StreakFreezeUsed freezeUsed(String id, GameDay date,
        {required DateTime when, String actor = robin}) =>
    StreakFreezeUsed(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      date: date,
    );

ExpeditionStarted expeditionStarted(String id, ExpeditionRegion region,
        {required DateTime when, String hero = robin, int minutes = 60}) =>
    ExpeditionStarted(
      eventId: id,
      deviceId: 'dev-1',
      actorId: hero,
      occurredAt: when,
      createdAt: when,
      heroId: hero,
      region: region,
      durationMinutes: minutes,
    );

ExpeditionResolved expeditionResolved(
  String id,
  ExpeditionRegion region,
  MaterialBundle loot, {
  required DateTime when,
  String hero = robin,
}) =>
    ExpeditionResolved(
      eventId: id,
      deviceId: 'dev-1',
      actorId: hero,
      occurredAt: when,
      createdAt: when,
      heroId: hero,
      region: region,
      loot: loot,
      reportLines: const ['The road was quiet.'],
    );

GearUpgraded gearUpgraded(String id,
        {required DateTime when,
        String hero = robin,
        String actor = robin,
        String slot = 'weapon',
        String gearType = 'sword',
        int tier = 1,
        Loot cost = Loot.none}) =>
    GearUpgraded(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      heroId: hero,
      slot: slot,
      gearType: gearType,
      tier: tier,
      cost: cost,
    );

HeroCustomized customized(String id, String field, String value,
        {required DateTime when, String hero = robin}) =>
    HeroCustomized(
      eventId: id,
      deviceId: 'dev-1',
      actorId: hero,
      occurredAt: when,
      createdAt: when,
      heroId: hero,
      field: field,
      value: value,
    );

RitualStepCompleted ritualStep(String id, Month month, RitualStep step,
        {required DateTime when, String actor = robin}) =>
    RitualStepCompleted(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      month: month,
      step: step,
    );

BossFightResolved bossFight(String id, Month month,
        {required DateTime when,
        String actor = robin,
        bool won = true,
        Loot rewards = Loot.none}) =>
    BossFightResolved(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      month: month,
      bossKey: 'boss.autumn.wyrm',
      won: won,
      turns: 7,
      rewards: rewards,
    );

PartyJoined partyJoined(String id, String partyId,
        {required DateTime when, String actor = robin}) =>
    PartyJoined(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      partyId: partyId,
    );

PartyLeft partyLeft(String id, String partyId,
        {required DateTime when, String actor = robin}) =>
    PartyLeft(
      eventId: id,
      deviceId: 'dev-1',
      actorId: actor,
      occurredAt: when,
      createdAt: when,
      partyId: partyId,
    );
