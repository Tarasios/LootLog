/// The game projection: [GameState] as a pure, deterministic fold over the
/// game event log in canonical `(occurredAt, eventId)` order.
///
/// The event log is the truth. The projection never rejects an event; when one
/// conflicts with the state (a debit beyond a balance, a race between two
/// devices), it applies what it safely can, never lets an amount go below
/// zero, never charges twice for the same thing, and records a [GameWarning].
///
/// Town events apply to their actor's own town (see
/// `town/town_ownership.dart`): the shared town before the `TownsSplit`,
/// the actor's own after it.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../domain/time.dart';
import '../config/balance.dart';
import 'decor/decor_state.dart';
import 'decor/decor_values.dart';
import 'game_event.dart';
import 'game_state.dart';
import 'game_values.dart';
import 'reason_codes.dart';
import 'town/cheers.dart';
import 'town/districts.dart';
import 'town/food.dart';
import 'town/gifts.dart';
import 'town/town_ownership.dart';

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
  final draft = _GameStateDraft(state, event.eventId, event.occurredAt);
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
      draft.countHallCommand(actor);
      final known = draft.town(actor).plots.values
          .any((plot) => plot.building != null && plot.buildingId == collected.buildingId);
      if (!known) draft.warn(GameWarningCode.unknownBuilding, collected.buildingId);
      // After the split a collection must come from the actor's own town;
      // a stale device's collection from the owner's is credited nowhere.
      if (draft.ownership.isSplit &&
          !collectionFitsTown(draft.town(actor), collected.buildingId, collected.amounts)) {
        if (known) draft.warn(GameWarningCode.unknownBuilding, collected.buildingId);
        return;
      }
      draft.adjustPool(actor, collected.amounts, 1);
      final town = draft.town(actor);
      final last = town.lastCollectedAt[collected.buildingId];
      if (last == null || collected.occurredAt.isAfter(last)) {
        draft.setTown(
            actor,
            town.copyWith(
                lastCollectedAt:
                    _put(town.lastCollectedAt, collected.buildingId, collected.occurredAt)));
      }

    case PlotUnlocked unlocked:
      draft.countHallCommand(actor);
      final town = draft.town(actor);
      if (town.plots.containsKey(unlocked.plotIndex)) {
        draft.warn(GameWarningCode.duplicateUnlock, 'plot ${unlocked.plotIndex}');
        return;
      }
      if (draft.cannotPay(actor, Loot(gems: unlocked.gemCost))) return;
      draft.setTown(
          actor,
          town.copyWith(
              plots: _put(town.plots, unlocked.plotIndex, PlotState(unlocked.plotIndex))));
      draft.adjustGems(actor, -unlocked.gemCost);

    case BuildingStarted started:
      draft.countHallCommand(actor);
      final town = draft.town(actor);
      final plot = town.plots[started.plotIndex];
      if (plot == null) {
        draft.warn(GameWarningCode.plotLocked, 'plot ${started.plotIndex}');
        // After the split a build must fit the actor's own town.
        if (draft.ownership.isSplit) return;
      }
      if (plot != null && draft.ownership.isSplit && !buildFitsTown(plot, started.tier)) {
        draft.warn(GameWarningCode.unknownBuilding,
            '${started.buildingType.name} tier ${started.tier} on plot ${started.plotIndex}');
        return;
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
      if (draft.cannotPay(actor, started.cost)) return;
      draft.setTown(
        actor,
        town.copyWith(
          plots: _put(
            town.plots,
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
      draft.adjustPool(resolved.heroId, resolved.loot, 1);

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

    case ItemAcquired acquisition:
      if (draft.decor.seenAcquisitionIds.contains(acquisition.acquisitionId)) {
        draft.warn(GameWarningCode.duplicateAcquisition, acquisition.acquisitionId);
        return;
      }
      // A festival decoration the household already has comes as gems,
      // decided here so every device agrees whatever it knew when granting.
      final alreadyOwned = acquisition.toTown
          ? (draft.decor.townOwned[acquisition.itemId] ?? 0) > 0
          : draft.decor.ownedCount(actor, acquisition.itemId) > 0;
      if (isFestivalDecorAcquisition(acquisition.acquisitionId) && alreadyOwned) {
        draft.decor = draft.decor.markSeen(acquisition.acquisitionId);
        draft.adjustGems(actor, Balance.duplicateDecorGems);
        return;
      }
      draft.decor = draft.decor.acquire(
        personId: actor,
        itemId: acquisition.itemId,
        toTown: acquisition.toTown,
        acquisitionId: acquisition.acquisitionId,
      );

    case ItemPurchased purchase:
      draft.adjustGems(actor, -purchase.gemCost);
      draft.decor = draft.decor.acquire(
        personId: actor,
        itemId: purchase.itemId,
        toTown: purchase.itemId.startsWith('town_'),
      );

    case ItemPlaced placement:
      final isTown = placement.space == DecorSpace.town;
      final existing = draft.decor.placements[placement.placementId];
      // Only a move within the same space reuses the copy already placed; a
      // placementId reused across spaces needs a free copy in the destination.
      final movingSameItem = existing != null &&
          existing.itemId == placement.itemId &&
          existing.space == placement.space;
      final available = isTown
          ? draft.decor.townAvailableCount(placement.itemId)
          : draft.decor.availableCount(actor, placement.itemId);
      if (!movingSameItem && available <= 0) {
        draft.warn(GameWarningCode.decorNotOwned, '${placement.itemId} for $actor');
        return;
      }
      draft.decor = draft.decor.place(Placement(
        placementId: placement.placementId,
        itemId: placement.itemId,
        space: placement.space,
        ownerId: isTown ? '' : (movingSameItem ? existing.ownerId : actor),
        column: placement.column,
        row: placement.row,
        rotation: placement.rotation,
      ));

    case ItemStored storage:
      if (!draft.decor.placements.containsKey(storage.placementId)) {
        draft.warn(GameWarningCode.unknownPlacement, storage.placementId);
        return;
      }
      draft.decor = draft.decor.store(storage.placementId);

    case ItemEquipped equip:
      // The projection has no catalogue, so it reads the id naming the
      // catalogue file test enforces; an id of neither shape is ignored.
      if (equip.itemId.endsWith('_title') || equip.itemId.startsWith('title_')) {
        draft.decor = draft.decor.equipTitle(actor, equip.itemId);
      } else if (equip.itemId.startsWith('outfit_')) {
        draft.decor = draft.decor.equipOutfit(actor, equip.itemId);
      }

    case DailyEventOffered offered:
      final person = draft.person(actor);
      // A second device's copy of the same day's offer is ignored.
      if (person.seenOfferIds.contains(offered.offerId)) return;
      draft.put(person.copyWith(
        seenOfferIds: _with(person.seenOfferIds, offered.offerId),
        dailyOffers: _put(
          person.dailyOffers,
          offered.offerId,
          DailyOffer(
            offerId: offered.offerId,
            day: offered.day,
            kind: offered.kind,
            gives: offered.gives,
            receives: offered.receives,
            flavourKey: offered.flavourKey,
            plotIndex: offered.plotIndex,
          ),
        ),
      ));

    case DailyEventResolved resolved:
      final person = draft.person(actor);
      if (!person.dailyOffers.containsKey(resolved.offerId)) {
        draft.warn(GameWarningCode.unknownOffer, resolved.offerId);
        return;
      }
      draft.put(person.copyWith(
          dailyOffers: _without(person.dailyOffers, resolved.offerId)));
      draft.adjustPool(actor, resolved.paid, -1);
      draft.credit(actor, resolved.received);

    case FestivalHeld festival:
      final person = draft.person(actor);
      // The highest tier held for the week stands: a device that saw more
      // logged weekdays tops it up, and a lower or repeated copy is ignored.
      final held = person.festivals[festival.week];
      if (held != null && held.index >= festival.tier.index) return;
      draft.put(person.copyWith(
          festivals: _put(person.festivals, festival.week, festival.tier)));

    case TownsSplit split:
      // The earliest split stands; a second device's split is ignored.
      final applied = applyTownsSplit(draft.ownership, draft.towns, split);
      if (applied == null) return;
      draft
        ..ownership = applied.ownership
        ..towns = applied.towns;

    case GiftSent gift:
      // Only an Adventure neighbour has a town to receive it; otherwise the
      // materials stay with the sender.
      if (!draft.ownership.isSplit ||
          gift.toPersonId == actor ||
          draft.person(gift.toPersonId).partyId != kHouseholdPartyId) {
        draft.warn(GameWarningCode.giftIgnored, gift.toPersonId);
        return;
      }
      final outcome = moveGift(
        sender: draft.town(actor),
        recipient: draft.town(gift.toPersonId),
        bundle: gift.bundle,
        at: gift.occurredAt,
      );
      if (outcome.moved != gift.bundle) {
        draft.warn(GameWarningCode.giftTrimmed, gift.toPersonId);
      }
      draft
        ..setTown(actor, outcome.sender)
        ..setTown(gift.toPersonId, outcome.recipient);

    case CheerSent sent:
      // Cosmetic: one cheer per sender, neighbour and day; the earliest copy
      // stands, and a cheer to oneself is ignored.
      final key = cheerId(actor, sent.toPersonId, sent.day);
      if (sent.toPersonId == actor || draft.cheers.containsKey(key)) return;
      draft.cheers = _put(draft.cheers, key,
          Cheer(fromId: actor, toId: sent.toPersonId, day: sent.day, at: sent.occurredAt));

    case ProsperityReached reached:
      final person = draft.person(actor);
      if (reached.value <= person.peakProsperity) return;
      draft.put(person.copyWith(peakProsperity: reached.value));

    case TierReached reached:
      final person = draft.person(actor);
      // The earliest instant per tier stands (events arrive in order).
      if (person.tiersReached.containsKey(reached.tier)) return;
      draft.put(person.copyWith(
          tiersReached: _put(person.tiersReached, reached.tier, reached.occurredAt)));

    case DistrictPurchased purchase:
      final town = draft.town(actor);
      final outcome = applyDistrictPurchase(town, purchase);
      final districts = outcome.districts;
      if (districts == null) {
        draft.warn(outcome.warning!, purchase.districtId);
        return;
      }
      if (draft.cannotPay(actor, purchase.cost)) return;
      draft.setTown(actor, town.copyWith(districts: districts));
      draft.pay(actor, purchase.cost);

    case DistrictBuildingStarted started:
      final town = draft.town(actor);
      final outcome = applyDistrictBuilding(town, started);
      final districts = outcome.districts;
      if (districts == null) {
        draft.warn(outcome.warning!,
            '${started.buildingKey} tier ${started.tier} on ${started.districtId} ${started.plotIndex}');
        return;
      }
      if (draft.cannotPay(actor, started.cost)) return;
      draft.setTown(actor, town.copyWith(districts: districts));
      draft.pay(actor, started.cost);

    case FoodHarvested harvest:
      final town = draft.town(actor);
      final address = PlotAddress(harvest.districtId, harvest.plotIndex);
      final type = town.districts.buildingAt(address)?.farmType;
      if (type == null || !Balance.farmBuildings[type]!.growsFood) {
        // Credited nowhere: no farm of the actor's own grew it.
        draft.warn(GameWarningCode.unknownBuilding, address.buildingId);
        return;
      }
      final banked = harvestInto(town.food,
          address: address,
          amount: harvest.amount,
          capacity: foodCapacityAt(town, harvest.occurredAt),
          at: harvest.occurredAt);
      if (banked.capped) draft.warn(GameWarningCode.foodCapped, address.buildingId);
      draft.setTown(actor, town.copyWith(food: banked.food));

    case FoodConsumed eaten:
      final town = draft.town(actor);
      draft.setTown(actor,
          town.copyWith(food: eatFrom(town.food, day: eaten.day, amount: eaten.amount)));

    case UnknownGameEvent _:
      return;
  }
}

/// One event's worth of changes, applied copy-on-write to the prior state.
class _GameStateDraft {
  _GameStateDraft(GameState prior, this.eventId, this.at)
      : towns = prior.towns,
        ownership = prior.ownership,
        decor = prior.decor,
        cheers = prior.cheers,
        _people = prior.people,
        _warnings = prior.warnings;

  final String eventId;

  /// The applied event's instant (Storehouse capacity is read as of it).
  final DateTime at;
  Map<String, HallState> towns;
  TownOwnership ownership;
  DecorState decor;
  Map<String, Cheer> cheers;
  Map<String, PersonState> _people;
  List<GameWarning> _warnings;

  PersonState person(String id) =>
      _people[id] ?? PersonState(personId: id);

  /// [personId]'s town as it stands (the shared town before the split).
  HallState town(String personId) => ownership.townOf(personId, towns);

  /// Replaces [personId]'s town (the shared town before the split).
  void setTown(String personId, HallState hall) {
    if (ownership.isSplit) {
      towns = _put(towns, personId, hall);
    } else {
      ownership = ownership.withSharedHall(hall);
    }
  }

  void countHallCommand(String actorId) =>
      ownership = ownership.countHallCommand(actorId);

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

  /// Adds ([sign] = 1) or removes ([sign] = -1) [delta] from [personId]'s
  /// town, clamping each kind at zero and, on a credit, at the Storehouse
  /// capacity (never below what the town already held).
  void adjustPool(String personId, MaterialBundle delta, int sign) {
    if (delta.isEmpty) return;
    final hall = town(personId);
    final next = Map.of(hall.materials.amounts);
    final short = <String>[];
    final over = <String>[];
    final capacity = hall.storageCapacityAt(at);
    for (final entry in delta.amounts.entries) {
      final held = next[entry.key] ?? 0;
      var adjusted = held + sign * entry.value;
      if (adjusted < 0) {
        short.add('${entry.key.name} ${-adjusted}');
        adjusted = 0;
      }
      if (sign > 0 && !Balance.uncappedMaterials.contains(entry.key)) {
        final cap = held > capacity ? held : capacity;
        if (adjusted > cap) {
          over.add('${entry.key.name} ${adjusted - cap}');
          adjusted = cap;
        }
      }
      next[entry.key] = adjusted;
    }
    if (short.isNotEmpty) {
      warn(GameWarningCode.materialsClamped, short.join(', '));
    }
    if (over.isNotEmpty) {
      warn(GameWarningCode.materialsCapped, over.join(', '));
    }
    setTown(personId, hall.copyWith(materials: MaterialBundle(next)));
  }

  /// After the split, whether [cost] is more than [personId]'s own town and
  /// wallet hold; if so the event is not applied and the shortfall is
  /// recorded with the clamp warnings. A stale or older-build event never
  /// lands nearly free by clamping the pool. Before the split, pools clamp
  /// as they always did.
  bool cannotPay(String personId, Loot cost) {
    if (!ownership.isSplit) return false;
    final gems = person(personId).gems;
    if (gems < cost.gems) {
      warn(GameWarningCode.gemsClamped, '$personId short ${cost.gems - gems}');
      return true;
    }
    final tokens = person(personId).freezeTokens;
    if (tokens < cost.tokens) {
      warn(GameWarningCode.tokensClamped, '$personId short ${cost.tokens - tokens}');
      return true;
    }
    final held = town(personId).materials;
    if (!held.covers(cost.materials)) {
      warn(GameWarningCode.materialsClamped, [
        for (final entry in cost.materials.amounts.entries)
          if (held[entry.key] < entry.value) '${entry.key.name} ${entry.value - held[entry.key]}',
      ].join(', '));
      return true;
    }
    return false;
  }

  void credit(String personId, Loot loot) {
    adjustGems(personId, loot.gems);
    adjustPool(personId, loot.materials, 1);
    adjustTokens(personId, loot.tokens);
  }

  void pay(String personId, Loot cost) {
    adjustGems(personId, -cost.gems);
    adjustPool(personId, cost.materials, -1);
    adjustTokens(personId, -cost.tokens);
  }

  GameState build(GameEvent applied) => GameState(
        towns: towns,
        ownership: ownership,
        people: _people,
        warnings: _warnings,
        cursor: applied,
        decor: decor,
        cheers: cheers,
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
