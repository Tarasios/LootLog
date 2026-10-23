/// The guild hall's commands: pure functions from (game state, clock, actor,
/// stamp, arguments) to either a [GameRejection] or the game events to append.
///
/// Commands validate against the current [GameState] so the UI can only ask
/// for what is possible, and they do every time- or chance-dependent sum once,
/// here, storing the result in the event (production, loot, chest contents,
/// the boss fight). Randomness comes only from [GameRng], seeded by the id of
/// the event being written, so the same command gives the same outcome on
/// every device and the projection never re-rolls.
///
/// They never write ledger events and never read amounts of money. The few
/// ledger-derived inputs (how many days a month was logged) arrive as plain
/// counts computed by the caller from the reducer's world.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../../domain/time.dart';
import '../../config/balance.dart';
import '../../config/narration.dart';
import '../clock.dart';
import '../content.dart';
import '../game_event.dart';
import '../game_event_stamp.dart';
import '../game_rng.dart';
import '../game_state.dart';
import '../game_values.dart';
import '../hall_rules.dart';
import '../reason_codes.dart';

/// Why a command was refused. The UI maps each to friendly copy.
enum GameRejection {
  /// The actor's gem wallet is short.
  notEnoughGems,

  /// The shared material pool is short.
  notEnoughMaterials,

  /// No such plot can exist (negative, or beyond the hall's last plot).
  invalidPlot,

  /// The plot is already unlocked.
  plotAlreadyUnlocked,

  /// The plot has not been unlocked yet.
  plotLocked,

  /// A different building stands on the plot.
  plotOccupied,

  /// The hall already has this building on another plot (one of each).
  buildingAlreadyInHall,

  /// The building is still being built or upgraded.
  underConstruction,

  /// The building or gear is at its highest tier.
  maxTierReached,

  /// The Central Hall must be upgraded first.
  needsCentralHall,

  /// The plot is empty.
  noBuilding,

  /// The building produces nothing to collect.
  notAProducer,

  /// The building has produced nothing since its last collection.
  nothingToCollect,

  /// The Storehouse has no room for any of what the building produced.
  storehouseFull,

  /// No such chest waits unopened for the actor.
  unknownChest,

  /// No such reward waits unclaimed for the actor.
  unknownReward,

  /// No such gear slot.
  unknownGearSlot,

  /// The slot does not take that gear type.
  unknownGearType,

  /// The Forge must be built or upgraded first.
  needsForge,

  /// Blank, or longer than the limits in [Balance].
  invalidCustomization,

  /// The hero already looks like that.
  noChange,

  /// The region opens with a higher Central Hall.
  regionLocked,

  /// The hero is already away.
  expeditionActive,

  /// The hero is not away.
  noActiveExpedition,

  /// The hero is still on the road.
  expeditionNotFinished,

  /// The month has not ended yet.
  ritualMonthNotClosed,

  /// The month is too long ago to start its ritual.
  ritualMonthExpired,

  /// That step is already done.
  ritualStepDone,

  /// An earlier step comes first.
  ritualStepOutOfOrder,

  /// The boss waits until all four steps are done.
  ritualIncomplete,

  /// The month's boss has been fought.
  bossAlreadyFought,

  /// Already in that party.
  alreadyInParty,

  /// Not in any party.
  notInParty,
}

/// What a command decided: the events to append, or why not.
class GameCommandResult {
  const GameCommandResult.accepted(this.events) : rejection = null;

  const GameCommandResult.rejected(GameRejection this.rejection)
      : events = const [];

  /// The events to append, in order (empty when rejected).
  final List<GameEvent> events;

  /// Why the command was refused, or null when accepted.
  final GameRejection? rejection;

  bool get accepted => rejection == null;

  @override
  String toString() => accepted
      ? 'GameCommandResult.accepted(${events.map((e) => e.type).toList()})'
      : 'GameCommandResult.rejected(${rejection!.name})';
}

/// Every guild-hall command, for one actor at one instant.
///
/// The actor is the person acting (a member id). Their hero's id is their
/// member id. Gems are paid from the actor's wallet; materials from the
/// shared pool.
class GameCommands {
  GameCommands({
    required this.state,
    required this.clock,
    required this.actorId,
    required this.stamp,
  });

  final GameState state;
  final Clock clock;
  final String actorId;
  final GameEventStamp stamp;

  late final DateTime _now = clock.now();
  HallState get _hall => state.hall;
  PersonState get _me => state.person(actorId);

  // ---- Hall ---------------------------------------------------------------

  /// Unlocks hall plot [plotIndex] for its gem price.
  GameCommandResult unlockPlot(int plotIndex) {
    if (_hall.plots.containsKey(plotIndex)) {
      return _reject(GameRejection.plotAlreadyUnlocked);
    }
    final cost = Balance.plotUnlockCost(plotIndex);
    if (cost == null) return _reject(GameRejection.invalidPlot);
    if (_me.gems < cost) return _reject(GameRejection.notEnoughGems);
    final env = _envelope();
    return _accept([
      PlotUnlocked(
        eventId: env.id,
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: _now,
        createdAt: _now,
        plotIndex: plotIndex,
        gemCost: cost,
      ),
    ]);
  }

  /// Builds [type] on an empty plot (tier 1) or upgrades the [type] already
  /// standing there by one tier. An upgrade of a producer first banks what it
  /// has made (capped by the Storehouse), since the upgrade restarts its
  /// production window.
  GameCommandResult startBuilding(int plotIndex, BuildingType type) {
    final plot = _hall.plots[plotIndex];
    if (plot == null) return _reject(GameRejection.plotLocked);
    final existing = plot.building;
    final int tier;
    if (existing == null) {
      if (_hall.plotOf(type) != null) {
        return _reject(GameRejection.buildingAlreadyInHall);
      }
      tier = 1;
    } else {
      if (existing.type != type) return _reject(GameRejection.plotOccupied);
      if (!existing.isCompleteAt(_now)) {
        return _reject(GameRejection.underConstruction);
      }
      tier = existing.tier + 1;
      if (tier > Balance.maxBuildingTier) {
        return _reject(GameRejection.maxTierReached);
      }
    }
    if (tier > maxTierAllowed(_hall, type, _now)) {
      return _reject(GameRejection.needsCentralHall);
    }

    final bank = existing != null && Balance.buildings[type]!.isProducer
        ? collectableNow(_hall, plotIndex, _now)
        : null;
    final cost = Balance.buildingCost(type, tier);
    final pool = bank == null ? _hall.materials : _hall.materials + bank;
    if (_me.gems < cost.gems) return _reject(GameRejection.notEnoughGems);
    if (!pool.covers(cost.materials)) {
      return _reject(GameRejection.notEnoughMaterials);
    }

    final events = <GameEvent>[];
    if (bank != null) {
      events.add(_collected(plot.buildingId, bank));
    }
    final env = _envelope();
    events.add(BuildingStarted(
      eventId: env.id,
      deviceId: stamp.deviceId,
      actorId: actorId,
      occurredAt: _now,
      createdAt: _now,
      plotIndex: plotIndex,
      buildingType: type,
      tier: tier,
      cost: cost,
      completesAt: _now.add(Balance.buildTimeByTier[tier - 1]),
    ));
    return _accept(events);
  }

  /// Collects what the producer on [plotIndex] made since its last
  /// collection, capped by the room left in the Storehouse (production past
  /// that is lost, as in any full yard). Never depends on logging (rule 10).
  GameCommandResult collectMaterials(int plotIndex) {
    final plot = _hall.plots[plotIndex];
    if (plot == null) return _reject(GameRejection.plotLocked);
    final b = plot.building;
    if (b == null) return _reject(GameRejection.noBuilding);
    if (!Balance.buildings[b.type]!.isProducer) {
      return _reject(GameRejection.notAProducer);
    }
    final made = uncollectedProduction(_hall, plotIndex, _now);
    if (made.isEmpty) return _reject(GameRejection.nothingToCollect);
    final fits = fitInStorehouse(_hall, made, _now);
    if (fits.isEmpty) return _reject(GameRejection.storehouseFull);
    return _accept([_collected(plot.buildingId, fits)]);
  }

  // ---- Chests and rewards ---------------------------------------------------

  /// Opens one of the actor's waiting chests, rolling its contents with the
  /// RNG seeded by the new event's id. A freeze token rolled while the actor
  /// already holds [Balance.maxFreezeTokens] becomes
  /// [Balance.tokenOverflowGems] instead.
  GameCommandResult openChest(String chestId) {
    final type = _me.unopenedChests[chestId];
    if (type == null) return _reject(GameRejection.unknownChest);
    final env = _envelope();
    final rng = GameRng.forEvent(env.id);
    final spec = Balance.chests[type]!;
    var gems = rng.range(spec.minGems, spec.maxGems);
    var tokens = rng.chance(spec.tokenChancePermille) ? 1 : 0;
    if (tokens > 0 && _heldTokens(_me) >= Balance.maxFreezeTokens) {
      tokens = 0;
      gems += Balance.tokenOverflowGems;
    }
    return _accept([
      ChestOpened(
        eventId: env.id,
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: _now,
        createdAt: _now,
        chestId: chestId,
        contents: Loot(gems: gems, tokens: tokens),
      ),
    ]);
  }

  /// Claims one of the actor's waiting rewards (gems to the wallet,
  /// materials to the pool, tokens to the pouch).
  GameCommandResult claimReward(String rewardId) {
    if (!_me.unclaimedRewards.containsKey(rewardId)) {
      return _reject(GameRejection.unknownReward);
    }
    final env = _envelope();
    return _accept([
      RewardClaimed(
        eventId: env.id,
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: _now,
        createdAt: _now,
        rewardId: rewardId,
      ),
    ]);
  }

  // ---- Heroes ---------------------------------------------------------------

  /// Upgrades [heroId]'s [slot] by one tier, to [gearType]. Anyone may pay
  /// for anyone's gear (the actor pays the gems). Gear never outranks the
  /// Forge.
  GameCommandResult upgradeGear({
    required String heroId,
    required String slot,
    required String gearType,
  }) {
    final spec = Balance.gearSlots[slot];
    if (spec == null) return _reject(GameRejection.unknownGearSlot);
    if (!spec.gearTypes.contains(gearType)) {
      return _reject(GameRejection.unknownGearType);
    }
    final current = state.person(heroId).hero.gear[slot];
    final tier = (current?.tier ?? 0) + 1;
    if (tier > Balance.maxGearTier) return _reject(GameRejection.maxTierReached);
    if (tier > _hall.completedTier(BuildingType.forge, _now)) {
      return _reject(GameRejection.needsForge);
    }
    final cost = Balance.gearCost(slot, tier);
    if (_me.gems < cost.gems) return _reject(GameRejection.notEnoughGems);
    if (!_hall.materials.covers(cost.materials)) {
      return _reject(GameRejection.notEnoughMaterials);
    }
    final env = _envelope();
    return _accept([
      GearUpgraded(
        eventId: env.id,
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: _now,
        createdAt: _now,
        heroId: heroId,
        slot: slot,
        gearType: gearType,
        tier: tier,
        cost: cost,
      ),
    ]);
  }

  /// Sets a cosmetic field on the actor's own hero. Free.
  GameCommandResult customizeHero({
    required String field,
    required String value,
  }) {
    final f = field.trim();
    if (f.isEmpty ||
        f.length > Balance.maxCosmeticFieldLength ||
        value.length > Balance.maxCosmeticValueLength) {
      return _reject(GameRejection.invalidCustomization);
    }
    if (_me.hero.cosmetics[f] == value) return _reject(GameRejection.noChange);
    final env = _envelope();
    return _accept([
      HeroCustomized(
        eventId: env.id,
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: _now,
        createdAt: _now,
        heroId: actorId,
        field: f,
        value: value,
      ),
    ]);
  }

  // ---- Expeditions ------------------------------------------------------------

  /// Sends the actor's hero to [region]. One expedition per hero at a time.
  GameCommandResult startExpedition(ExpeditionRegion region) {
    if (_me.activeExpedition != null) {
      return _reject(GameRejection.expeditionActive);
    }
    final spec = Balance.regions[region]!;
    if (_hall.completedTier(BuildingType.centralHall, _now) < spec.minHallTier) {
      return _reject(GameRejection.regionLocked);
    }
    final env = _envelope();
    return _accept([
      ExpeditionStarted(
        eventId: env.id,
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: _now,
        createdAt: _now,
        heroId: actorId,
        region: region,
        durationMinutes: spec.durationMinutes,
      ),
    ]);
  }

  /// Brings the actor's hero home once the trip's time is up: loot is rolled
  /// now with the RNG seeded by the new event's id, boosted by the hero's
  /// gear, trimmed to what the Storehouse can take, and stored with a report.
  GameCommandResult resolveExpedition() {
    final trip = _me.activeExpedition;
    if (trip == null) return _reject(GameRejection.noActiveExpedition);
    if (_now.isBefore(trip.endsAt)) {
      return _reject(GameRejection.expeditionNotFinished);
    }
    final env = _envelope();
    final rng = GameRng.forEvent(env.id);
    final spec = Balance.regions[trip.region]!;
    final bonus = _me.hero.power * Balance.lootBonusPermillePerGearTier;
    final found = <MaterialKind, int>{};
    for (final line in spec.loot) {
      if (!rng.chance(line.chancePermille)) continue;
      final n = rng.range(line.min, line.max) * (1000 + bonus) ~/ 1000;
      found[line.kind] = (found[line.kind] ?? 0) + n;
    }
    final haul = MaterialBundle(found);
    final kept = fitInStorehouse(_hall, haul, _now);

    String fill(String template, MaterialKind kind, int n) => template
        .replaceAll('{n}', '$n')
        .replaceAll('{material}', kind.name);
    final region = Narration.regionNames[trip.region]!;
    final lines = <String>[
      _capitalize(rng.pick(Narration.expeditionOpeners).replaceAll('{region}', region)),
      for (final e in kept.amounts.entries) fill(Narration.foundLine, e.key, e.value),
      for (final e in haul.amounts.entries)
        if (e.value > kept[e.key])
          fill(Narration.leftBehindLine, e.key, e.value - kept[e.key]),
      if (haul.isEmpty) Narration.emptyHanded,
    ];
    return _accept([
      ExpeditionResolved(
        eventId: env.id,
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: _now,
        createdAt: _now,
        heroId: actorId,
        region: trip.region,
        loot: kept,
        reportLines: lines,
      ),
    ]);
  }

  // ---- The spoils ritual --------------------------------------------------------

  /// Marks one step of [month]'s spoils ritual done. Steps go in order
  /// (reconcile, review, plan, contribute), once each, for a month that has
  /// ended and is at most [Balance.ritualOpenMonths] back. The UI calls this
  /// when the person finishes that step's screen.
  GameCommandResult completeRitualStep(Month month, RitualStep step) {
    final current = Month.fromInstant(_now);
    if (!month.isBefore(current)) {
      return _reject(GameRejection.ritualMonthNotClosed);
    }
    var oldest = current;
    for (var i = 0; i < Balance.ritualOpenMonths; i++) {
      oldest = oldest.prev();
    }
    if (month.isBefore(oldest)) return _reject(GameRejection.ritualMonthExpired);
    final done = _me.ritual[month]?.steps ?? const <RitualStep>{};
    if (done.contains(step)) return _reject(GameRejection.ritualStepDone);
    for (final earlier in RitualStep.values.take(step.index)) {
      if (!done.contains(earlier)) {
        return _reject(GameRejection.ritualStepOutOfOrder);
      }
    }
    final env = _envelope();
    return _accept([
      RitualStepCompleted(
        eventId: env.id,
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: _now,
        createdAt: _now,
        month: month,
        step: step,
      ),
    ]);
  }

  /// Fights [month]'s seasonal boss once all four ritual steps are done.
  ///
  /// The fight is simulated now, seeded by the new event's id: each round
  /// the hero deals base damage, plus their gear power, plus a bonus for how
  /// completely the month was logged ([loggedDays], counted by the caller
  /// from the ledger), plus a random spread. A win adds
  /// [Balance.bossWinRewards]. Win or lose, the spoils chest is granted: the
  /// ritual earned it, and losing is never a punishment.
  GameCommandResult fightBoss(Month month, {int loggedDays = 0}) {
    final progress = _me.ritual[month];
    if (progress == null || !progress.steps.containsAll(RitualStep.values)) {
      return _reject(GameRejection.ritualIncomplete);
    }
    if (progress.boss != null) return _reject(GameRejection.bossAlreadyFought);

    final env = _envelope();
    final rng = GameRng.forEvent(env.id);
    final boss = Balance.bosses[seasonOf(month)]!;
    final hp = boss.baseHp + monthInSeason(month) * Balance.bossHpPerMonthInSeason;
    final days = _daysIn(month);
    final logged = loggedDays.clamp(0, days);
    final attack = Balance.heroBaseAttack +
        _me.hero.power * Balance.heroAttackPerGearTier +
        Balance.bossLoggingBonusMax * logged ~/ days;
    var remaining = hp;
    var turns = 0;
    while (turns < Balance.bossMaxTurns && remaining > 0) {
      turns++;
      remaining -= attack + rng.range(0, Balance.bossAttackVariance);
    }
    final won = remaining <= 0;

    final events = <GameEvent>[
      BossFightResolved(
        eventId: env.id,
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: _now,
        createdAt: _now,
        month: month,
        bossKey: boss.key,
        won: won,
        turns: turns,
        rewards: won ? Balance.bossWinRewards : Loot.none,
      ),
    ];
    final chestId = spoilsChestId(actorId, month);
    if (!_me.seenChestIds.contains(chestId)) {
      final chest = _envelope();
      events.add(ChestGranted(
        eventId: chest.id,
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: _now,
        createdAt: _now,
        chestId: chestId,
        chestType: ChestType.spoils,
        reasonCode: GameReasonCodes.ritualSpoils,
      ));
    }
    return _accept(events);
  }

  // ---- Party --------------------------------------------------------------------

  /// Joins the household's adventuring party.
  GameCommandResult joinParty([String partyId = kHouseholdPartyId]) {
    if (_me.partyId == partyId) return _reject(GameRejection.alreadyInParty);
    final env = _envelope();
    return _accept([
      PartyJoined(
        eventId: env.id,
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: _now,
        createdAt: _now,
        partyId: partyId,
      ),
    ]);
  }

  /// Leaves the party the actor is in.
  GameCommandResult leaveParty() {
    final partyId = _me.partyId;
    if (partyId == null) return _reject(GameRejection.notInParty);
    final env = _envelope();
    return _accept([
      PartyLeft(
        eventId: env.id,
        deviceId: stamp.deviceId,
        actorId: actorId,
        occurredAt: _now,
        createdAt: _now,
        partyId: partyId,
      ),
    ]);
  }

  // ---- Helpers --------------------------------------------------------------------

  MaterialsCollected _collected(String buildingId, MaterialBundle amounts) {
    final env = _envelope();
    return MaterialsCollected(
      eventId: env.id,
      deviceId: stamp.deviceId,
      actorId: actorId,
      occurredAt: _now,
      createdAt: _now,
      buildingId: buildingId,
      amounts: amounts,
    );
  }

  ({String id}) _envelope() => (id: stamp.newEventId());

  GameCommandResult _accept(List<GameEvent> events) =>
      GameCommandResult.accepted(List.unmodifiable(events));

  GameCommandResult _reject(GameRejection reason) =>
      GameCommandResult.rejected(reason);
}

/// The spoils chest's id for [personId]'s ritual of [month].
String spoilsChestId(String personId, Month month) =>
    '${GameReasonCodes.ritualSpoils}:$personId:${month.toKey()}';

/// Freeze tokens [p] holds: claimed plus granted-but-waiting.
int _heldTokens(PersonState p) =>
    p.freezeTokens +
    p.unclaimedRewards.values.fold(0, (sum, r) => sum + r.loot.tokens);

int _daysIn(Month m) => DateTime.utc(m.year, m.month + 1, 0).day;

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
