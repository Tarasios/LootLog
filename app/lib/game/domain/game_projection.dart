/// The game projection: [GameState] as a pure, deterministic fold over the
/// game event log in canonical `(occurredAt, eventId)` order.
///
/// The event log is the truth. The projection never rejects an event; when one
/// conflicts with the state (a debit beyond a balance, a race between two
/// devices), it applies what it safely can, never lets an amount go below
/// zero, never charges twice for the same thing, and records a [GameWarning].
///
/// Pure Dart, zero Flutter imports.
library;

import '../../domain/time.dart';
import 'game_event.dart';
import 'game_state.dart';
import 'game_values.dart';
import 'reason_codes.dart';

/// Canonical event order: `occurredAt`, then `eventId` as the tiebreak.
int compareGameEvents(GameEvent a, GameEvent b) {
  final byTime = a.occurredAt.compareTo(b.occurredAt);
  return byTime != 0 ? byTime : a.eventId.compareTo(b.eventId);
}

/// Rebuilds the state from scratch. Input order does not matter and duplicate
/// event ids are applied once.
GameState projectGameState(Iterable<GameEvent> events) {
  final sorted = [...events]..sort(compareGameEvents);
  final seen = <String>{};
  var state = GameState.initial();
  for (final e in sorted) {
    if (seen.add(e.eventId)) {
      state = applyGameEvent(state, e);
    }
  }
  return state;
}

/// Applies one event to [state]; see [GameState.apply] for the ordering
/// contract.
GameState applyGameEvent(GameState state, GameEvent event) {
  final cursor = state.cursor;
  if (cursor != null) {
    if (cursor.eventId == event.eventId) return state;
    if (compareGameEvents(event, cursor) < 0) {
      throw StateError(
          'Game event ${event.eventId} orders before the last applied event '
          '${cursor.eventId}; rebuild with projectGameState.');
    }
  }
  final tx = _Tx(state, event.eventId);
  _apply(tx, event);
  return tx.build(event);
}

void _apply(_Tx tx, GameEvent event) {
  final actor = event.actorId;
  switch (event) {
    case RewardGranted e:
      final p = tx.person(actor);
      if (p.seenRewardIds.contains(e.rewardId)) return;
      var streak = p.streak;
      if (GameReasonCodes.streakDays.contains(e.reasonCode)) {
        streak = _cover(streak, GameDay.fromInstant(e.occurredAt));
      }
      tx.put(p.copyWith(
        seenRewardIds: _with(p.seenRewardIds, e.rewardId),
        unclaimedRewards: _put(
          p.unclaimedRewards,
          e.rewardId,
          PendingReward(
            rewardId: e.rewardId,
            kind: e.kind,
            reasonCode: e.reasonCode,
            loot: Loot(gems: e.gems, materials: e.materials, tokens: e.tokens),
            grantedAt: e.occurredAt,
          ),
        ),
        streak: streak,
      ));

    case RewardClaimed e:
      final p = tx.person(actor);
      final reward = p.unclaimedRewards[e.rewardId];
      if (reward == null) {
        tx.warn(GameWarningCode.unknownReward, e.rewardId);
        return;
      }
      tx.put(p.copyWith(unclaimedRewards: _without(p.unclaimedRewards, e.rewardId)));
      tx.credit(actor, reward.loot);

    case MaterialsCollected e:
      final known = tx.hall.plots.values
          .any((p) => p.building != null && p.buildingId == e.buildingId);
      if (!known) tx.warn(GameWarningCode.unknownBuilding, e.buildingId);
      tx.adjustPool(e.amounts, 1);
      final last = tx.hall.lastCollectedAt[e.buildingId];
      if (last == null || e.occurredAt.isAfter(last)) {
        tx.hall = tx.hall.copyWith(
            lastCollectedAt:
                _put(tx.hall.lastCollectedAt, e.buildingId, e.occurredAt));
      }

    case PlotUnlocked e:
      if (tx.hall.plots.containsKey(e.plotIndex)) {
        tx.warn(GameWarningCode.duplicateUnlock, 'plot ${e.plotIndex}');
        return;
      }
      tx.hall = tx.hall.copyWith(
          plots: _put(tx.hall.plots, e.plotIndex, PlotState(e.plotIndex)));
      tx.adjustGems(actor, -e.gemCost);

    case BuildingStarted e:
      final plot = tx.hall.plots[e.plotIndex];
      if (plot == null) {
        tx.warn(GameWarningCode.plotLocked, 'plot ${e.plotIndex}');
      }
      final existing = plot?.building;
      if (existing != null && existing.type != e.buildingType) {
        tx.warn(GameWarningCode.plotOccupied,
            'plot ${e.plotIndex} holds ${existing.type.name}');
        return;
      }
      if (existing != null && existing.tier >= e.tier) {
        tx.warn(GameWarningCode.duplicateBuild,
            '${e.buildingType.name} tier ${e.tier}');
        return;
      }
      tx.hall = tx.hall.copyWith(
        plots: _put(
          tx.hall.plots,
          e.plotIndex,
          PlotState(
            e.plotIndex,
            BuildingState(
              type: e.buildingType,
              tier: e.tier,
              startedAt: e.occurredAt,
              completesAt: e.completesAt,
            ),
          ),
        ),
      );
      tx.pay(actor, e.cost);

    case GearUpgraded e:
      final owner = tx.person(e.heroId);
      final current = owner.hero.gear[e.slot];
      if (current != null &&
          current.gearType == e.gearType &&
          current.tier >= e.tier) {
        tx.warn(GameWarningCode.duplicateGear, '${e.slot} ${e.gearType}');
        return;
      }
      tx.put(owner.copyWith(
        hero: HeroState(
          cosmetics: owner.hero.cosmetics,
          gear: _put(owner.hero.gear, e.slot, GearPiece(e.gearType, e.tier)),
        ),
      ));
      tx.pay(actor, e.cost);

    case HeroCustomized e:
      final owner = tx.person(e.heroId);
      tx.put(owner.copyWith(
        hero: HeroState(
          cosmetics: _put(owner.hero.cosmetics, e.field, e.value),
          gear: owner.hero.gear,
        ),
      ));

    case ExpeditionStarted e:
      final hero = tx.person(e.heroId);
      if (hero.activeExpedition != null) {
        tx.warn(GameWarningCode.expeditionAlreadyActive, e.region.name);
        return;
      }
      tx.put(hero.copyWith(
        activeExpedition: ActiveExpedition(
          region: e.region,
          startedAt: e.occurredAt,
          durationMinutes: e.durationMinutes,
        ),
      ));

    case ExpeditionResolved e:
      final hero = tx.person(e.heroId);
      if (hero.activeExpedition?.region != e.region) {
        tx.warn(GameWarningCode.noActiveExpedition, e.region.name);
        return;
      }
      tx.put(hero.copyWith(
        activeExpedition: null,
        lastExpedition: ExpeditionReport(
          region: e.region,
          loot: e.loot,
          reportLines: List.unmodifiable(e.reportLines),
          returnedAt: e.occurredAt,
        ),
      ));
      tx.adjustPool(e.loot, 1);

    case ChestGranted e:
      final p = tx.person(actor);
      if (p.seenChestIds.contains(e.chestId)) return;
      tx.put(p.copyWith(
        seenChestIds: _with(p.seenChestIds, e.chestId),
        unopenedChests: _put(p.unopenedChests, e.chestId, e.chestType),
      ));

    case ChestOpened e:
      final p = tx.person(actor);
      if (!p.unopenedChests.containsKey(e.chestId)) {
        tx.warn(GameWarningCode.unknownChest, e.chestId);
        return;
      }
      tx.put(p.copyWith(unopenedChests: _without(p.unopenedChests, e.chestId)));
      tx.credit(actor, e.contents);

    case StreakFreezeUsed e:
      final p = tx.person(actor);
      // Already covered (logged, or frozen by another device): nothing to
      // spend a token on.
      if (p.streak.coveredDays.contains(e.date)) return;
      // The day is covered even if the tokens ran short: streaks forgive.
      tx.put(p.copyWith(
        streak: StreakState(
          _with(p.streak.coveredDays, e.date),
          _with(p.streak.frozenDays, e.date),
        ),
      ));
      tx.adjustTokens(actor, -1);

    case RitualStepCompleted e:
      final p = tx.person(actor);
      final progress = p.ritual[e.month] ?? const RitualProgress();
      tx.put(p.copyWith(
        ritual: _put(
          p.ritual,
          e.month,
          RitualProgress(steps: _with(progress.steps, e.step), boss: progress.boss),
        ),
      ));

    case BossFightResolved e:
      final p = tx.person(actor);
      final progress = p.ritual[e.month] ?? const RitualProgress();
      if (progress.boss != null) {
        tx.warn(GameWarningCode.duplicateBossFight, e.month.toKey());
        return;
      }
      tx.put(p.copyWith(
        ritual: _put<Month, RitualProgress>(
          p.ritual,
          e.month,
          RitualProgress(
            steps: progress.steps,
            boss: BossResult(
              bossKey: e.bossKey,
              won: e.won,
              turns: e.turns,
              rewards: e.rewards,
            ),
          ),
        ),
      ));
      tx.credit(actor, e.rewards);

    case PartyJoined e:
      tx.put(tx.person(actor).copyWith(partyId: e.partyId));

    case PartyLeft e:
      final p = tx.person(actor);
      if (p.partyId != e.partyId) {
        tx.warn(GameWarningCode.notInParty, e.partyId);
        return;
      }
      tx.put(p.copyWith(partyId: null));

    case UnknownGameEvent _:
      return;
  }
}

/// One event's worth of changes, applied copy-on-write to the prior state.
class _Tx {
  _Tx(GameState prior, this.eventId)
      : hall = prior.hall,
        _people = prior.people,
        _warnings = prior.warnings;

  final String eventId;
  HallState hall;
  Map<String, PersonState> _people;
  List<GameWarning> _warnings;

  PersonState person(String id) =>
      _people[id] ?? PersonState(personId: id);

  void put(PersonState p) => _people = _put(_people, p.personId, p);

  void warn(GameWarningCode code, [String detail = '']) =>
      _warnings = List.unmodifiable([..._warnings, GameWarning(eventId, code, detail)]);

  void adjustGems(String personId, int delta) {
    if (delta == 0) return;
    final p = person(personId);
    var gems = p.gems + delta;
    if (gems < 0) {
      warn(GameWarningCode.gemsClamped, '$personId short ${-gems}');
      gems = 0;
    }
    put(p.copyWith(gems: gems));
  }

  void adjustTokens(String personId, int delta) {
    if (delta == 0) return;
    final p = person(personId);
    var tokens = p.freezeTokens + delta;
    if (tokens < 0) {
      warn(GameWarningCode.tokensClamped, '$personId short ${-tokens}');
      tokens = 0;
    }
    put(p.copyWith(freezeTokens: tokens));
  }

  /// Adds ([sign] = 1) or removes ([sign] = -1) [delta] from the shared pool,
  /// clamping each kind at zero.
  void adjustPool(MaterialBundle delta, int sign) {
    if (delta.isEmpty) return;
    final next = Map.of(hall.materials.amounts);
    final short = <String>[];
    for (final e in delta.amounts.entries) {
      final v = (next[e.key] ?? 0) + sign * e.value;
      if (v < 0) short.add('${e.key.name} ${-v}');
      next[e.key] = v < 0 ? 0 : v;
    }
    if (short.isNotEmpty) {
      warn(GameWarningCode.materialsClamped, short.join(', '));
    }
    hall = hall.copyWith(materials: MaterialBundle(next));
  }

  void credit(String personId, Loot loot) {
    adjustGems(personId, loot.gems);
    adjustPool(loot.materials, 1);
    adjustTokens(personId, loot.tokens);
  }

  void pay(String personId, Loot cost) {
    adjustGems(personId, -cost.gems);
    adjustPool(cost.materials, -1);
    adjustTokens(personId, -cost.tokens);
  }

  GameState build(GameEvent applied) => GameState(
        hall: hall,
        people: _people,
        warnings: _warnings,
        cursor: applied,
      );
}

StreakState _cover(StreakState s, GameDay day) => s.coveredDays.contains(day)
    ? s
    : StreakState(_with(s.coveredDays, day), s.frozenDays);

Map<K, V> _put<K, V>(Map<K, V> m, K key, V value) =>
    Map.unmodifiable({...m, key: value});

Map<K, V> _without<K, V>(Map<K, V> m, K key) =>
    Map.unmodifiable({...m}..remove(key));

Set<T> _with<T>(Set<T> s, T value) =>
    s.contains(value) ? s : Set.unmodifiable({...s, value});
