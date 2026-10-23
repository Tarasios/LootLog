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
int compareGameEvents(GameEvent first, GameEvent second) {
  final byTime = first.occurredAt.compareTo(second.occurredAt);
  return byTime != 0 ? byTime : first.eventId.compareTo(second.eventId);
}

/// Rebuilds the state from scratch. Input order does not matter and duplicate
/// event ids are applied once.
GameState projectGameState(Iterable<GameEvent> events) {
  final sorted = [...events]..sort(compareGameEvents);
  final seen = <String>{};
  var state = GameState.initial();
  for (final event in sorted) {
    if (seen.add(event.eventId)) {
      state = applyGameEvent(state, event);
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
  final draft = _GameStateDraft(state, event.eventId);
  _apply(draft, event);
  return draft.build(event);
}

void _apply(_GameStateDraft draft, GameEvent event) {
  final actor = event.actorId;
  switch (event) {
    case RewardGranted granted:
      final person = draft.person(actor);
      if (person.seenRewardIds.contains(granted.rewardId)) return;
      var streak = person.streak;
      if (GameReasonCodes.streakDays.contains(granted.reasonCode)) {
        streak = _cover(streak, GameDay.fromInstant(granted.occurredAt));
      }
      draft.put(person.copyWith(
        seenRewardIds: _with(person.seenRewardIds, granted.rewardId),
        unclaimedRewards: _put(
          person.unclaimedRewards,
          granted.rewardId,
          PendingReward(
            rewardId: granted.rewardId,
            kind: granted.kind,
            reasonCode: granted.reasonCode,
            loot: Loot(gems: granted.gems, materials: granted.materials, tokens: granted.tokens),
            grantedAt: granted.occurredAt,
          ),
        ),
        streak: streak,
      ));

    case RewardClaimed claimed:
      final person = draft.person(actor);
      final reward = person.unclaimedRewards[claimed.rewardId];
      if (reward == null) {
        draft.warn(GameWarningCode.unknownReward, claimed.rewardId);
        return;
      }
      draft.put(person.copyWith(unclaimedRewards: _without(person.unclaimedRewards, claimed.rewardId)));
      draft.credit(actor, reward.loot);

    case MaterialsCollected collected:
      final known = draft.hall.plots.values
          .any((plot) => plot.building != null && plot.buildingId == collected.buildingId);
      if (!known) draft.warn(GameWarningCode.unknownBuilding, collected.buildingId);
      draft.adjustPool(collected.amounts, 1);
      final last = draft.hall.lastCollectedAt[collected.buildingId];
      if (last == null || collected.occurredAt.isAfter(last)) {
        draft.hall = draft.hall.copyWith(
            lastCollectedAt:
                _put(draft.hall.lastCollectedAt, collected.buildingId, collected.occurredAt));
      }

    case PlotUnlocked unlocked:
      if (draft.hall.plots.containsKey(unlocked.plotIndex)) {
        draft.warn(GameWarningCode.duplicateUnlock, 'plot ${unlocked.plotIndex}');
        return;
      }
      draft.hall = draft.hall.copyWith(
          plots: _put(draft.hall.plots, unlocked.plotIndex, PlotState(unlocked.plotIndex)));
      draft.adjustGems(actor, -unlocked.gemCost);

    case BuildingStarted started:
      final plot = draft.hall.plots[started.plotIndex];
      if (plot == null) {
        draft.warn(GameWarningCode.plotLocked, 'plot ${started.plotIndex}');
      }
      final existing = plot?.building;
      if (existing != null && existing.type != started.buildingType) {
        draft.warn(GameWarningCode.plotOccupied,
            'plot ${started.plotIndex} holds ${existing.type.name}');
        return;
      }
      if (existing != null && existing.tier >= started.tier) {
        draft.warn(GameWarningCode.duplicateBuild,
            '${started.buildingType.name} tier ${started.tier}');
        return;
      }
      draft.hall = draft.hall.copyWith(
        plots: _put(
          draft.hall.plots,
          started.plotIndex,
          PlotState(
            started.plotIndex,
            BuildingState(
              type: started.buildingType,
              tier: started.tier,
              startedAt: started.occurredAt,
              completesAt: started.completesAt,
            ),
          ),
        ),
      );
      draft.pay(actor, started.cost);

    case GearUpgraded upgraded:
      final owner = draft.person(upgraded.heroId);
      final current = owner.hero.gear[upgraded.slot];
      if (current != null &&
          current.gearType == upgraded.gearType &&
          current.tier >= upgraded.tier) {
        draft.warn(GameWarningCode.duplicateGear, '${upgraded.slot} ${upgraded.gearType}');
        return;
      }
      draft.put(owner.copyWith(
        hero: HeroState(
          cosmetics: owner.hero.cosmetics,
          gear: _put(owner.hero.gear, upgraded.slot, GearPiece(upgraded.gearType, upgraded.tier)),
        ),
      ));
      draft.pay(actor, upgraded.cost);

    case HeroCustomized customized:
      final owner = draft.person(customized.heroId);
      draft.put(owner.copyWith(
        hero: HeroState(
          cosmetics: _put(owner.hero.cosmetics, customized.field, customized.value),
          gear: owner.hero.gear,
        ),
      ));

    case ExpeditionStarted expedition:
      final hero = draft.person(expedition.heroId);
      if (hero.activeExpedition != null) {
        draft.warn(GameWarningCode.expeditionAlreadyActive, expedition.region.name);
        return;
      }
      draft.put(hero.copyWith(
        activeExpedition: ActiveExpedition(
          region: expedition.region,
          startedAt: expedition.occurredAt,
          durationMinutes: expedition.durationMinutes,
        ),
      ));

    case ExpeditionResolved resolved:
      final hero = draft.person(resolved.heroId);
      if (hero.activeExpedition?.region != resolved.region) {
        draft.warn(GameWarningCode.noActiveExpedition, resolved.region.name);
        return;
      }
      draft.put(hero.copyWith(
        activeExpedition: null,
        lastExpedition: ExpeditionReport(
          region: resolved.region,
          loot: resolved.loot,
          reportLines: List.unmodifiable(resolved.reportLines),
          returnedAt: resolved.occurredAt,
        ),
      ));
      draft.adjustPool(resolved.loot, 1);

    case ChestGranted chest:
      final person = draft.person(actor);
      if (person.seenChestIds.contains(chest.chestId)) return;
      draft.put(person.copyWith(
        seenChestIds: _with(person.seenChestIds, chest.chestId),
        unopenedChests: _put(person.unopenedChests, chest.chestId, chest.chestType),
      ));

    case ChestOpened opened:
      final person = draft.person(actor);
      if (!person.unopenedChests.containsKey(opened.chestId)) {
        draft.warn(GameWarningCode.unknownChest, opened.chestId);
        return;
      }
      draft.put(person.copyWith(unopenedChests: _without(person.unopenedChests, opened.chestId)));
      draft.credit(actor, opened.contents);

    case StreakFreezeUsed freeze:
      final person = draft.person(actor);
      // Already covered (logged, or frozen by another device): nothing to
      // spend a token on.
      if (person.streak.coveredDays.contains(freeze.date)) return;
      // The day is covered even if the tokens ran short: streaks forgive.
      draft.put(person.copyWith(
        streak: StreakState(
          _with(person.streak.coveredDays, freeze.date),
          _with(person.streak.frozenDays, freeze.date),
        ),
      ));
      draft.adjustTokens(actor, -1);

    case RitualStepCompleted step:
      final person = draft.person(actor);
      final progress = person.ritual[step.month] ?? const RitualProgress();
      draft.put(person.copyWith(
        ritual: _put(
          person.ritual,
          step.month,
          RitualProgress(steps: _with(progress.steps, step.step), boss: progress.boss),
        ),
      ));

    case BossFightResolved fight:
      final person = draft.person(actor);
      final progress = person.ritual[fight.month] ?? const RitualProgress();
      if (progress.boss != null) {
        draft.warn(GameWarningCode.duplicateBossFight, fight.month.toKey());
        return;
      }
      draft.put(person.copyWith(
        ritual: _put<Month, RitualProgress>(
          person.ritual,
          fight.month,
          RitualProgress(
            steps: progress.steps,
            boss: BossResult(
              bossKey: fight.bossKey,
              won: fight.won,
              turns: fight.turns,
              rewards: fight.rewards,
            ),
          ),
        ),
      ));
      draft.credit(actor, fight.rewards);

    case PartyJoined joined:
      draft.put(draft.person(actor).copyWith(partyId: joined.partyId));

    case PartyLeft left:
      final person = draft.person(actor);
      if (person.partyId != left.partyId) {
        draft.warn(GameWarningCode.notInParty, left.partyId);
        return;
      }
      draft.put(person.copyWith(partyId: null));

    case UnknownGameEvent _:
      return;
  }
}

/// One event's worth of changes, applied copy-on-write to the prior state.
class _GameStateDraft {
  _GameStateDraft(GameState prior, this.eventId)
      : hall = prior.hall,
        _people = prior.people,
        _warnings = prior.warnings;

  final String eventId;
  HallState hall;
  Map<String, PersonState> _people;
  List<GameWarning> _warnings;

  PersonState person(String id) =>
      _people[id] ?? PersonState(personId: id);

  void put(PersonState person) => _people = _put(_people, person.personId, person);

  void warn(GameWarningCode code, [String detail = '']) =>
      _warnings = List.unmodifiable([..._warnings, GameWarning(eventId, code, detail)]);

  void adjustGems(String personId, int delta) {
    if (delta == 0) return;
    final personState = person(personId);
    var gems = personState.gems + delta;
    if (gems < 0) {
      warn(GameWarningCode.gemsClamped, '$personId short ${-gems}');
      gems = 0;
    }
    put(personState.copyWith(gems: gems));
  }

  void adjustTokens(String personId, int delta) {
    if (delta == 0) return;
    final personState = person(personId);
    var tokens = personState.freezeTokens + delta;
    if (tokens < 0) {
      warn(GameWarningCode.tokensClamped, '$personId short ${-tokens}');
      tokens = 0;
    }
    put(personState.copyWith(freezeTokens: tokens));
  }

  /// Adds ([sign] = 1) or removes ([sign] = -1) [delta] from the shared pool,
  /// clamping each kind at zero.
  void adjustPool(MaterialBundle delta, int sign) {
    if (delta.isEmpty) return;
    final next = Map.of(hall.materials.amounts);
    final short = <String>[];
    for (final entry in delta.amounts.entries) {
      final adjusted = (next[entry.key] ?? 0) + sign * entry.value;
      if (adjusted < 0) short.add('${entry.key.name} ${-adjusted}');
      next[entry.key] = adjusted < 0 ? 0 : adjusted;
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

StreakState _cover(StreakState streak, GameDay day) => streak.coveredDays.contains(day)
    ? streak
    : StreakState(_with(streak.coveredDays, day), streak.frozenDays);

Map<K, V> _put<K, V>(Map<K, V> map, K key, V value) =>
    Map.unmodifiable({...map, key: value});

Map<K, V> _without<K, V>(Map<K, V> map, K key) =>
    Map.unmodifiable({...map}..remove(key));

Set<T> _with<T>(Set<T> set, T value) =>
    set.contains(value) ? set : Set.unmodifiable({...set, value});
