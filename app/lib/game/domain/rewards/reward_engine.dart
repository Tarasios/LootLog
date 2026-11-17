/// The reward engine: turns ledger events into guild-hall game events.
///
/// Pure and deterministic — the same ledger events, game state, clock and
/// party produce the same rewards. It is idempotent: every reward and chest
/// has an id built from (rule, person, period), and anything the [GameState]
/// has already seen is never granted again, so re-running it (after every
/// local write, after every sync merge, on two devices at once) never
/// double-grants. The projection dedupes by those ids too.
///
/// The design rules it upholds:
/// - Honest logging is what pays. No reward reads a purchase amount, and
///   nothing here is ever negative or taken back: editing or voiding a
///   purchase grants nothing and removes nothing.
/// - Gems from logging are capped per day ([Balance.dailyGemCapFor] the tier
///   held that day).
/// - A "nothing spent today" check-in counts as showing up.
/// - Streaks forgive: a freeze token covers a missed day automatically.
/// - Party rewards only add. A quiet partner costs the other nothing.
///
/// Opening a day also brings that day's town event (`town/daily_event.dart`),
/// rolled once from the ledger event that opened it; every weekend brings a
/// festival sized to the weekdays logged (`town/festival.dart`).
///
/// The first run on a household that still shares one town splits it, once,
/// into one town per Adventure adult (`town/town_ownership.dart`).
///
/// Every run also grows each Adventure adult's town (`town/prosperity.dart`):
/// a new peak prosperity, the tiers it opens and their rewards, and the food
/// its residents ate on each day since the last run (`town/food.dart`).
///
/// Pure Dart, zero Flutter imports.
library;

import '../../../domain/event.dart';
import '../../../domain/state.dart';
import '../../config/balance.dart';
import '../clock.dart';
import '../game_event.dart';
import '../game_event_stamp.dart';
import '../game_state.dart';
import '../game_values.dart';
import '../reason_codes.dart';
import '../town/daily_event.dart';
import '../town/festival.dart';
import '../town/food.dart';
import '../town/prosperity.dart';
import '../town/town_ownership.dart';
import '../town/trade_road.dart';
import 'month_end_rewards.dart';

export '../game_event_stamp.dart';

/// One adult in the household and the mode they play in.
class PartyAdult {
  const PartyAdult(this.memberId, {required this.inAdventure});

  final String memberId;

  /// Adventure adults are party members. Standard adults back the party as a
  /// supply caravan.
  final bool inAdventure;
}

/// The household's adults, as the engine needs them.
class Party {
  const Party(this.adults);

  final List<PartyAdult> adults;

  PartyAdult? adult(String memberId) {
    for (final adult in adults) {
      if (adult.memberId == memberId) return adult;
    }
    return null;
  }

  Iterable<PartyAdult> get adventurers => adults.where((adult) => adult.inAdventure);
}

/// The month-end rewards (gold chests, Vault milestones), evaluated on every
/// engine run. The default is `LedgerMonthEndRewards`.
///
/// Month-end rewards read closed months, so they need the whole ledger (and
/// ideally its reduced [household] state, which the app already has); when
/// [household] is null the implementation reduces the ledger itself.
abstract interface class MonthEndRewards {
  List<GameEvent> evaluate(
    List<Event> newLedgerEvents,
    GameState state,
    Clock clock, {
    required Party party,
    required GameEventStamp stamp,
    HouseholdState? household,
  });
}

/// Month-end rewards switched off (tests that only exercise daily rewards).
class NoMonthEndRewards implements MonthEndRewards {
  const NoMonthEndRewards();

  @override
  List<GameEvent> evaluate(
    List<Event> newLedgerEvents,
    GameState state,
    Clock clock, {
    required Party party,
    required GameEventStamp stamp,
    HouseholdState? household,
  }) =>
      const [];
}

class RewardEngine {
  const RewardEngine({
    this.lookbackDays = Balance.rewardLookbackDays,
    this.monthEnd = const LedgerMonthEndRewards(),
  });

  /// How many days back activity is still rewarded.
  final int lookbackDays;
  final MonthEndRewards monthEnd;

  /// The game events [newLedgerEvents] earn, given what [gameState] already
  /// holds. Any batch is safe to pass — even the whole log — because what is
  /// already rewarded is skipped and activity older than [lookbackDays] is
  /// ignored. Month-end rewards need the whole ledger, or its reduced
  /// [household] state (see [MonthEndRewards]).
  ///
  /// [mayMigrateTowns] says this device is not waiting on sync (no paired
  /// hubs, or a clean cycle with every hub since the app started), so it may
  /// write the one-time `TownsSplit`. Until then the shared town keeps
  /// working: two unsynced devices splitting at once could each name a
  /// different owner, and the later split's interim play would be set aside.
  List<GameEvent> evaluate(
    Iterable<Event> newLedgerEvents,
    GameState gameState,
    Clock clock, {
    required Party party,
    required GameEventStamp stamp,
    HouseholdState? household,
    bool mayMigrateTowns = true,
  }) {
    final now = clock.now();
    final today = GameDay.fromInstant(now);
    final oldest = today.addDays(-lookbackDays);
    final ledger = newLedgerEvents.toList();

    // Activity is keyed to the day it was logged (createdAt): showing up is
    // the habit. Ordered by (createdAt, eventId) so every device agrees which
    // event opened a day and which ones fill the cap.
    final rewardable = [
      for (final event in ledger)
        if (party.adult(event.userId) != null && _inWindow(event, oldest, today)) event,
    ]..sort((first, second) {
        final byTime = first.createdAt.compareTo(second.createdAt);
        return byTime != 0 ? byTime : first.eventId.compareTo(second.eventId);
      });

    final run = _Run(gameState, party, stamp, now, today);
    if (mayMigrateTowns) run.splitTowns();
    for (final event in rewardable) {
      final adult = party.adult(event.userId)!;
      switch (event) {
        // An edit's corrected copy is not a new purchase.
        case PurchaseAdded(amendsPurchaseId: null):
          run.activity(adult, event, purchase: event);
        case NoSpendCheckedIn():
          run.activity(adult, event);
        case ReconcileCompleted():
          run.reconcile(adult, event);
        default:
          break;
      }
    }
    for (final adult in party.adventurers) {
      run.bridge(adult.memberId, today);
      run.tokens(adult.memberId);
    }
    // Festivals are held for every Adventure adult on every run, not only
    // for whoever just logged.
    for (final adult in party.adventurers) {
      run.festivals(adult.memberId, oldest);
    }
    run.jointFestivals(oldest);
    run.tradeRoads(oldest);
    for (final adult in party.adventurers) {
      run.townGrowth(adult.memberId, oldest);
    }

    run.out.addAll(monthEnd.evaluate(ledger, gameState, clock,
        party: party, stamp: stamp, household: household));
    return run.out;
  }

  static bool _inWindow(Event event, GameDay oldest, GameDay today) {
    final day = GameDay.fromInstant(event.createdAt);
    return day >= oldest && day <= today;
  }
}

/// What one evaluation knows about a person: the projection plus everything
/// this run has already emitted for them.
class _Person {
  _Person(PersonState state)
      : covered = {...state.streak.coveredDays},
        logged = {...state.streak.loggedDays},
        frontier = state.streak.lastDay,
        seenRewards = {...state.seenRewardIds},
        seenChests = {...state.seenChestIds},
        seenOffers = {...state.seenOfferIds},
        festivalTiers = {...state.festivals},
        caravanDays = {
          for (final rewardId in state.seenRewardIds) ?caravanRewardDay(rewardId),
        },
        wallet = state.freezeTokens,
        waitingTokens = [
          for (final reward in state.unclaimedRewards.values)
            if (reward.loot.tokens > 0) (rewardId: reward.rewardId, tokens: reward.loot.tokens),
        ]..sort((first, second) => first.rewardId.compareTo(second.rewardId));

  final Set<GameDay> covered;
  final Set<GameDay> logged;

  /// The latest covered day: the edge the streak grows from.
  GameDay? frontier;
  final Set<String> seenRewards;
  final Set<String> seenChests;
  final Set<String> seenOffers;

  /// The Mondays of the weeks whose festival is held.
  /// The festival tier held per week (by its Monday).
  final Map<GameDay, FestivalTier> festivalTiers;

  /// Days the person backed the party as a Standard adult.
  final Set<GameDay> caravanDays;

  /// Claimed freeze tokens.
  int wallet;

  /// Granted but unclaimed freeze-token rewards.
  final List<({String rewardId, int tokens})> waitingTokens;

  int get heldTokens =>
      wallet + waitingTokens.fold(0, (sum, waiting) => sum + waiting.tokens);

  void cover(GameDay day) {
    covered.add(day);
    final currentFrontier = frontier;
    if (currentFrontier == null || day > currentFrontier) frontier = day;
  }

  int loggedInWeek(GameDay weekStart) {
    final end = weekStart.addDays(6);
    return logged.where((day) => day >= weekStart && day <= end).length;
  }
}

class _Run {
  _Run(this.state, this.party, this.stamp, this.now, this.today);

  final GameState state;
  final Party party;
  final GameEventStamp stamp;
  final DateTime now;
  final GameDay today;
  final List<GameEvent> out = [];
  final Map<String, _Person> _people = {};

  /// Which ledger event opened each person's day: the earliest active one.
  final Map<String, String> _openers = {};

  /// The split this run wrote, when the household still shared one town.
  TownsSplit? _split;

  /// Splits a still-shared town once (see `town/town_ownership.dart`). With
  /// no Adventure adult there is nobody to own a town yet.
  void splitTowns() {
    if (state.townsSplit) return;
    final owner = townsSplitOwner(
      state.ownership.hallCommandCounts,
      party.adventurers.map((adult) => adult.memberId),
    );
    if (owner == null) return;
    final split = TownsSplit(
      eventId: stamp.newEventId(),
      deviceId: stamp.deviceId,
      actorId: owner,
      occurredAt: now,
      createdAt: now,
      ownerId: owner,
      welcome: Balance.welcomeGrant,
    );
    _split = split;
    out.add(split);
  }

  /// [who]'s town as it stands once this run's split (if any) applies.
  HallState townOf(String who) {
    final split = _split;
    if (split == null) return state.townOf(who);
    return townAfterSplit(state, who, ownerId: split.ownerId, welcome: split.welcome);
  }

  _Person person(String id) =>
      _people.putIfAbsent(id, () => _Person(state.person(id)));

  /// An active-day event: a new purchase or a no-spend check-in.
  void activity(PartyAdult adult, Event event, {PurchaseAdded? purchase}) {
    final who = adult.memberId;
    final day = GameDay.fromInstant(event.createdAt);
    if (!adult.inAdventure) {
      _caravan(who, day);
      return;
    }
    final personRecord = person(who);
    final opener = _openers.putIfAbsent('$who|${day.toKey()}', () => event.eventId);
    final opensDay = opener == event.eventId;

    // Missed days before this one are settled first, so a gap never hides
    // behind the day that ends it.
    bridge(who, day);

    if (opensDay) {
      _grant(
        who,
        rewardId: 'log.daily:$who:${day.toKey()}',
        kind: 'gemPouch',
        gems: Balance.activeDayPouchGems,
        reasonCode: purchase == null
            ? GameReasonCodes.noSpendCheckIn
            : GameReasonCodes.dailyLog,
        source: event.eventId,
        // Stamped with the logged instant: the projection covers that day.
        occurredAt: event.createdAt,
      );
      personRecord
        ..logged.add(day)
        ..cover(day);
      _dailyEvent(who, day, event);
    }

    if (purchase != null) {
      if (!opensDay) {
        _capped(who, day, GameReasonCodes.extraLog, Balance.extraLogGems,
            purchase);
      }
      final delay = purchase.createdAt.difference(purchase.occurredAt).abs();
      if (delay <= Balance.timelyWindow) {
        _capped(who, day, GameReasonCodes.timely, Balance.timelyBonusGems,
            purchase);
      }
    }

    tokens(who);
    _weekly(who, day.weekStart);
  }

  /// Today's town event, rolled from the ledger event that opened the day.
  /// Only today gets one: an offer can only be taken on its own day, so a
  /// catch-up over earlier days offers nothing.
  void _dailyEvent(String who, GameDay day, Event opener) {
    if (day != today) return;
    final offerId = dailyEventOfferId(who, day);
    if (!person(who).seenOffers.add(offerId)) return;
    final offer = rollDailyOffer(
      personId: who,
      day: day,
      seedEventId: opener.eventId,
      hall: townOf(who),
      now: now,
    );
    out.add(DailyEventOffered(
      eventId: stamp.newEventId(),
      deviceId: stamp.deviceId,
      actorId: who,
      // Stamped with the logged instant, like the day's pouch.
      occurredAt: opener.createdAt,
      createdAt: now,
      offerId: offer.offerId,
      day: offer.day,
      kind: offer.kind,
      gives: offer.gives,
      receives: offer.receives,
      flavourKey: offer.flavourKey,
      plotIndex: offer.plotIndex,
    ));
  }

  /// Holds each weekend festival due for [who] (see `festivalWeeksDue`),
  /// sized by the week's town spirit. A device that sees more logged
  /// weekdays than the tier already held tops it up: a new `FestivalHeld`
  /// and one reward per tier reached, each paying what that tier adds, so
  /// every device ends with the same rewards whatever it saw first.
  void festivals(String who, GameDay oldest) {
    final record = person(who);
    final due = festivalWeeksDue(
      loggedDays: record.logged,
      caravanDays: record.caravanDays,
      today: today,
      oldest: oldest,
    );
    for (final week in due) {
      final weekdays = weekdaysLogged(record.logged, week);
      final tier = festivalTierFor(weekdays);
      final held = record.festivalTiers[week];
      if (held == null || tier.index > held.index) {
        record.festivalTiers[week] = tier;
        out.add(FestivalHeld(
          eventId: stamp.newEventId(),
          deviceId: stamp.deviceId,
          actorId: who,
          occurredAt: now,
          createdAt: now,
          week: week,
          tier: tier,
          weekdaysLogged: weekdays,
        ));
      }
      final reached = record.festivalTiers[week]!;
      for (final step in FestivalTier.values.take(reached.index + 1)) {
        if (festivalTierPaid(record.seenRewards, who, week, step)) continue;
        final loot = festivalTierReward(step);
        _grant(who,
            rewardId: festivalRewardId(who, week, step),
            kind: 'festival',
            gems: loot.gems,
            materials: loot.materials,
            reasonCode: GameReasonCodes.festival);
      }
    }
  }

  /// The joint bonus for every Adventure adult at a fair or better in a
  /// week at least one other Adventure adult also reached a fair. Additive:
  /// someone alone simply has no bonus, and nobody is ever named.
  void jointFestivals(GameDay oldest) {
    for (final week in festivalWeeksInWindow(today: today, oldest: oldest)) {
      final festive = [
        for (final adult in party.adventurers)
          if (weekdaysLogged(person(adult.memberId).logged, week) >=
              Balance.festivalFairWeekdays)
            adult.memberId,
      ];
      if (festive.length < 2) continue;
      for (final who in festive) {
        _grant(who,
            rewardId: jointFestivalRewardId(who, week),
            kind: 'gems',
            gems: Balance.jointFestivalGems,
            reasonCode: GameReasonCodes.festivalJoint);
      }
    }
  }

  /// The trade road's caravans (`town/trade_road.dart`) for every day since
  /// the towns were split, within the lookback. Additive only: someone
  /// alone that day simply has no caravan.
  void tradeRoads(GameDay oldest) {
    final splitAt = _split?.occurredAt ?? state.ownership.split?.splitAt;
    if (splitAt == null) return;
    final opened = GameDay.fromInstant(splitAt);
    final standardIds = {
      for (final adult in party.adults)
        if (!adult.inAdventure) adult.memberId,
    };
    final due = tradeRoadCaravansDue(
      from: opened > oldest ? opened : oldest,
      to: today,
      adventurerDays: {
        for (final adult in party.adventurers)
          adult.memberId: person(adult.memberId).logged,
      },
      caravanDays: {
        for (final id in standardIds) id: person(id).caravanDays,
      },
    );
    for (final caravan in due) {
      final goods = standardIds.contains(caravan.neighbourId)
          ? Balance.caravanTradeBundle
          : tradeRoadDelivery(townOf(caravan.neighbourId), now);
      _grant(caravan.who,
          rewardId: tradeRoadRewardId(caravan.who, caravan.day, caravan.neighbourId),
          kind: 'tradeRoad',
          materials: goods,
          reasonCode: GameReasonCodes.tradeRoad);
    }
  }

  /// [who]'s town growth: a new peak prosperity when the town's prosperity
  /// rose past the stored one (topping it up, never locking a stale value
  /// in), then every tier that peak opens and a reward for each tier
  /// reached that was not granted yet. Tiers past the hamlet wait for food
  /// in store. Then the residents eat each finished day still due.
  void townGrowth(String who, GameDay oldest) {
    final personState = state.person(who);
    final record = person(who);
    final town = townOf(who);
    // This run's town and festivals, counted exactly as the town book counts.
    final prosperity = prosperityOf(state, who, now, town: town, festivals: record.festivalTiers);
    var peak = personState.peakProsperity;
    if (prosperity > peak) {
      peak = prosperity;
      out.add(ProsperityReached(
        eventId: stamp.newEventId(),
        deviceId: stamp.deviceId,
        actorId: who,
        occurredAt: now,
        createdAt: now,
        value: prosperity,
      ));
    }
    var tier = personState.townTier;
    for (final reached in tiersDue(
      current: tier,
      peak: peak,
      foodSecureFor: (target) => foodSecure(town, target),
    )) {
      tier = reached;
      out.add(TierReached(
        eventId: stamp.newEventId(),
        deviceId: stamp.deviceId,
        actorId: who,
        occurredAt: now,
        createdAt: now,
        tier: reached,
      ));
    }
    for (final reached in TownTier.values.skip(1).take(tier.index)) {
      final loot = Balance.tierRewards[reached]!;
      _grant(who,
          rewardId: tierRewardId(who, reached),
          kind: 'townTier',
          gems: loot.gems,
          materials: loot.materials,
          tokens: loot.tokens,
          reasonCode: GameReasonCodes.townTier);
    }
    for (final meal in foodConsumptionDue(
      food: town.food,
      tierOn: personState.tierOn,
      oldest: oldest,
      today: today,
    )) {
      out.add(FoodConsumed(
        eventId: stamp.newEventId(),
        deviceId: stamp.deviceId,
        actorId: who,
        occurredAt: now,
        createdAt: now,
        day: meal.day,
        amount: meal.amount,
      ));
    }
  }

  /// Gems under the per-day cap, one per purchase per rule.
  void _capped(
    String who,
    GameDay day,
    String reasonCode,
    int gems,
    PurchaseAdded purchase,
  ) {
    final personRecord = person(who);
    final rewardId = '$reasonCode:$who:${day.toKey()}:${purchase.purchaseId}';
    if (personRecord.seenRewards.contains(rewardId)) return;
    final extra = '${GameReasonCodes.extraLog}:$who:${day.toKey()}:';
    final timely = '${GameReasonCodes.timely}:$who:${day.toKey()}:';
    final used = personRecord.seenRewards
        .where((id) => id.startsWith(extra) || id.startsWith(timely))
        .length;
    // The cap of the tier held ON [day], so a purchase that syncs in after a
    // tier-up is judged by its own day's cap.
    if (used >= Balance.dailyGemCapFor(state.person(who).tierOn(day))) return;
    _grant(who,
        rewardId: rewardId,
        kind: 'gems',
        gems: gems,
        reasonCode: reasonCode,
        source: purchase.eventId);
  }

  /// The weekly check-in chest and the party chest.
  void _weekly(String who, GameDay week) {
    if (person(who).loggedInWeek(week) >= Balance.weeklyCheckInActiveDays) {
      _chest(who, GameReasonCodes.weeklyCheckIn, ChestType.wood, week);
    }
    // Each Adventure adult who showed up in a week another Adventure adult
    // also showed up gets a party chest. With two partners that's "both were
    // active"; it never depends on anyone being blamed or left out.
    for (final other in party.adventurers) {
      if (other.memberId == who) continue;
      if (person(other.memberId).loggedInWeek(week) == 0) continue;
      _chest(who, GameReasonCodes.partyWeek, ChestType.party, week);
      _chest(other.memberId, GameReasonCodes.partyWeek, ChestType.party, week);
    }
  }

  void reconcile(PartyAdult adult, ReconcileCompleted event) {
    if (!adult.inAdventure) return;
    final week = event.weekStart.weekStart;
    if (week > today.weekStart) return; // a week that hasn't started
    final who = adult.memberId;
    _chest(who, GameReasonCodes.weeklyReconcile, ChestType.iron, week);
    _grant(who,
        rewardId: '${GameReasonCodes.weeklyReconcile}:$who:${week.toKey()}',
        kind: 'gems',
        gems: Balance.weeklyReconcileGems,
        reasonCode: GameReasonCodes.weeklyReconcile,
        source: event.eventId);
  }

  /// A Standard adult's active day, recorded as their caravan reward (the
  /// id marks the day). A Standard adult has no town, so the caravan itself
  /// carries nothing here: its goods travel the trade road to the Adventure
  /// adults active the same day. Delivered at once, since they never visit
  /// the town to claim it.
  void _caravan(String who, GameDay day) {
    if (party.adventurers.isEmpty) return; // no party to supply
    final rewardId = caravanRewardId(who, day);
    final record = person(who);
    if (record.seenRewards.contains(rewardId)) return;
    record.caravanDays.add(day);
    _grant(who,
        rewardId: rewardId,
        kind: 'caravan',
        reasonCode: GameReasonCodes.caravan);
    _claim(who, rewardId);
  }

  /// Covers missed days after the person's last covered day, up to (not
  /// including) [until], spending a freeze token per day while any are held.
  /// With none left the streak simply resets — no event says so.
  void bridge(String who, GameDay until) {
    final personRecord = person(who);
    final from = personRecord.frontier;
    if (from == null) return;
    for (var day = from.next(); day < until; day = day.next()) {
      if (personRecord.heldTokens == 0) return;
      if (personRecord.wallet == 0) {
        // Collect a waiting token on the person's behalf to spend it.
        final token = personRecord.waitingTokens.removeAt(0);
        _claim(who, token.rewardId);
        personRecord.wallet += token.tokens;
      }
      personRecord.wallet--;
      out.add(StreakFreezeUsed(
        eventId: stamp.newEventId(),
        deviceId: stamp.deviceId,
        actorId: who,
        occurredAt: now,
        createdAt: now,
        date: day,
      ));
      personRecord.cover(day);
    }
  }

  /// Grants the freeze tokens the current run has earned: one per
  /// [Balance.streakDaysPerFreezeToken] days, while fewer than
  /// [Balance.maxFreezeTokens] are held.
  void tokens(String who) {
    final personRecord = person(who);
    final end = personRecord.frontier;
    if (end == null) return;
    var start = end;
    while (personRecord.covered.contains(start.previous())) {
      start = start.previous();
    }
    final length = start.daysUntil(end) + 1;
    for (var milestone = Balance.streakDaysPerFreezeToken;
        milestone <= length;
        milestone += Balance.streakDaysPerFreezeToken) {
      final rewardId =
          '${GameReasonCodes.streakToken}:$who:${start.toKey()}:$milestone';
      if (personRecord.seenRewards.contains(rewardId)) continue;
      if (personRecord.heldTokens >= Balance.maxFreezeTokens) return;
      _grant(who,
          rewardId: rewardId,
          kind: 'freezeToken',
          tokens: 1,
          reasonCode: GameReasonCodes.streakToken);
      personRecord.waitingTokens.add((rewardId: rewardId, tokens: 1));
    }
  }

  void _grant(
    String who, {
    required String rewardId,
    required String kind,
    required String reasonCode,
    int gems = 0,
    MaterialBundle materials = const MaterialBundle.empty(),
    int tokens = 0,
    String? source,
    DateTime? occurredAt,
  }) {
    final personRecord = person(who);
    if (!personRecord.seenRewards.add(rewardId)) return;
    out.add(RewardGranted(
      eventId: stamp.newEventId(),
      deviceId: stamp.deviceId,
      actorId: who,
      occurredAt: occurredAt ?? now,
      createdAt: now,
      rewardId: rewardId,
      kind: kind,
      gems: gems,
      materials: materials,
      tokens: tokens,
      reasonCode: reasonCode,
      sourceLedgerEventIds: [?source],
    ));
  }

  void _claim(String who, String rewardId) => out.add(RewardClaimed(
        eventId: stamp.newEventId(),
        deviceId: stamp.deviceId,
        actorId: who,
        occurredAt: now,
        createdAt: now,
        rewardId: rewardId,
      ));

  void _chest(String who, String reasonCode, ChestType type, GameDay week) {
    final chestId = '$reasonCode:$who:${week.toKey()}';
    if (!person(who).seenChests.add(chestId)) return;
    out.add(ChestGranted(
      eventId: stamp.newEventId(),
      deviceId: stamp.deviceId,
      actorId: who,
      occurredAt: now,
      createdAt: now,
      chestId: chestId,
      chestType: type,
      reasonCode: reasonCode,
    ));
  }
}
