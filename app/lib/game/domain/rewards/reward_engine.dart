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
/// - Gems from logging are capped per day ([Balance.dailyGemCap]).
/// - A "nothing spent today" check-in counts as showing up.
/// - Streaks forgive: a freeze token covers a missed day automatically.
/// - Party rewards only add. A quiet partner costs the other nothing.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../../domain/event.dart';
import '../../../domain/ids.dart';
import '../../config/balance.dart';
import '../clock.dart';
import '../game_event.dart';
import '../game_state.dart';
import '../game_values.dart';
import '../reason_codes.dart';

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
    for (final a in adults) {
      if (a.memberId == memberId) return a;
    }
    return null;
  }

  Iterable<PartyAdult> get adventurers => adults.where((a) => a.inAdventure);
}

/// How the engine stamps the events it writes: this device, and fresh event
/// ids (UUIDv7 in the app, so events written together keep their order).
class GameEventStamp {
  const GameEventStamp({required this.deviceId, this.newEventId = uuidv7});

  final String deviceId;
  final String Function() newEventId;
}

/// The month-end rewards (the spoils ritual's chest and boss fight). Not built
/// yet; the engine already calls it on every evaluation.
abstract interface class MonthEndRewards {
  List<GameEvent> evaluate(
    List<Event> newLedgerEvents,
    GameState state,
    Clock clock, {
    required Party party,
    required GameEventStamp stamp,
  });
}

/// The placeholder until month-end rewards exist.
class NoMonthEndRewards implements MonthEndRewards {
  const NoMonthEndRewards();

  @override
  List<GameEvent> evaluate(
    List<Event> newLedgerEvents,
    GameState state,
    Clock clock, {
    required Party party,
    required GameEventStamp stamp,
  }) =>
      const [];
}

class RewardEngine {
  const RewardEngine({
    this.lookbackDays = Balance.rewardLookbackDays,
    this.monthEnd = const NoMonthEndRewards(),
  });

  /// How many days back activity is still rewarded.
  final int lookbackDays;
  final MonthEndRewards monthEnd;

  /// The game events [newLedgerEvents] earn, given what [gameState] already
  /// holds. Any batch is safe to pass — even the whole log — because what is
  /// already rewarded is skipped and activity older than [lookbackDays] is
  /// ignored.
  List<GameEvent> evaluate(
    Iterable<Event> newLedgerEvents,
    GameState gameState,
    Clock clock, {
    required Party party,
    required GameEventStamp stamp,
  }) {
    final now = clock.now();
    final today = GameDay.fromInstant(now);
    final oldest = today.addDays(-lookbackDays);
    final ledger = newLedgerEvents.toList();

    // Activity is keyed to the day it was logged (createdAt): showing up is
    // the habit. Ordered by (createdAt, eventId) so every device agrees which
    // event opened a day and which ones fill the cap.
    final rewardable = [
      for (final e in ledger)
        if (party.adult(e.userId) != null && _inWindow(e, oldest, today)) e,
    ]..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.eventId.compareTo(b.eventId);
      });

    final run = _Run(gameState, party, stamp, now, today);
    for (final e in rewardable) {
      final adult = party.adult(e.userId)!;
      switch (e) {
        // An edit's corrected copy is not a new purchase.
        case PurchaseAdded(amendsPurchaseId: null):
          run.activity(adult, e, purchase: e);
        case NoSpendCheckedIn():
          run.activity(adult, e);
        case ReconcileCompleted():
          run.reconcile(adult, e);
        default:
          break;
      }
    }
    for (final adult in party.adventurers) {
      run.bridge(adult.memberId, today);
      run.tokens(adult.memberId);
    }

    run.out.addAll(monthEnd.evaluate(ledger, gameState, clock,
        party: party, stamp: stamp));
    return run.out;
  }

  static bool _inWindow(Event e, GameDay oldest, GameDay today) {
    final day = GameDay.fromInstant(e.createdAt);
    return day >= oldest && day <= today;
  }
}

/// What one evaluation knows about a person: the projection plus everything
/// this run has already emitted for them.
class _Person {
  _Person(PersonState p)
      : covered = {...p.streak.coveredDays},
        logged = {...p.streak.loggedDays},
        frontier = p.streak.lastDay,
        seenRewards = {...p.seenRewardIds},
        seenChests = {...p.seenChestIds},
        wallet = p.freezeTokens,
        waitingTokens = [
          for (final r in p.unclaimedRewards.values)
            if (r.loot.tokens > 0) (rewardId: r.rewardId, tokens: r.loot.tokens),
        ]..sort((a, b) => a.rewardId.compareTo(b.rewardId));

  final Set<GameDay> covered;
  final Set<GameDay> logged;

  /// The latest covered day: the edge the streak grows from.
  GameDay? frontier;
  final Set<String> seenRewards;
  final Set<String> seenChests;

  /// Claimed freeze tokens.
  int wallet;

  /// Granted but unclaimed freeze-token rewards.
  final List<({String rewardId, int tokens})> waitingTokens;

  int get heldTokens =>
      wallet + waitingTokens.fold(0, (sum, t) => sum + t.tokens);

  void cover(GameDay day) {
    covered.add(day);
    final f = frontier;
    if (f == null || day > f) frontier = day;
  }

  int loggedInWeek(GameDay weekStart) {
    final end = weekStart.addDays(6);
    return logged.where((d) => d >= weekStart && d <= end).length;
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

  _Person person(String id) =>
      _people.putIfAbsent(id, () => _Person(state.person(id)));

  /// An active-day event: a new purchase or a no-spend check-in.
  void activity(PartyAdult adult, Event e, {PurchaseAdded? purchase}) {
    final who = adult.memberId;
    final day = GameDay.fromInstant(e.createdAt);
    if (!adult.inAdventure) {
      _caravan(who, day);
      return;
    }
    final p = person(who);
    final opener = _openers.putIfAbsent('$who|${day.toKey()}', () => e.eventId);
    final opensDay = opener == e.eventId;

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
        source: e.eventId,
        // Stamped with the logged instant: the projection covers that day.
        occurredAt: e.createdAt,
      );
      p
        ..logged.add(day)
        ..cover(day);
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

  /// Gems under the per-day cap, one per purchase per rule.
  void _capped(
    String who,
    GameDay day,
    String reasonCode,
    int gems,
    PurchaseAdded purchase,
  ) {
    final p = person(who);
    final rewardId = '$reasonCode:$who:${day.toKey()}:${purchase.purchaseId}';
    if (p.seenRewards.contains(rewardId)) return;
    final extra = '${GameReasonCodes.extraLog}:$who:${day.toKey()}:';
    final timely = '${GameReasonCodes.timely}:$who:${day.toKey()}:';
    final used = p.seenRewards
        .where((id) => id.startsWith(extra) || id.startsWith(timely))
        .length;
    if (used >= Balance.dailyGemCap) return;
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

  void reconcile(PartyAdult adult, ReconcileCompleted e) {
    if (!adult.inAdventure) return;
    final week = e.weekStart.weekStart;
    if (week > today.weekStart) return; // a week that hasn't started
    final who = adult.memberId;
    _chest(who, GameReasonCodes.weeklyReconcile, ChestType.iron, week);
    _grant(who,
        rewardId: '${GameReasonCodes.weeklyReconcile}:$who:${week.toKey()}',
        kind: 'gems',
        gems: Balance.weeklyReconcileGems,
        reasonCode: GameReasonCodes.weeklyReconcile,
        source: e.eventId);
  }

  /// A Standard adult's active day: materials for the shared pool, delivered
  /// at once (they never visit the hall to claim it).
  void _caravan(String who, GameDay day) {
    if (party.adventurers.isEmpty) return; // no party to supply
    final rewardId = 'caravan:$who:${day.toKey()}';
    if (person(who).seenRewards.contains(rewardId)) return;
    _grant(who,
        rewardId: rewardId,
        kind: 'caravan',
        materials: Balance.caravanMaterials,
        reasonCode: GameReasonCodes.caravan);
    _claim(who, rewardId);
  }

  /// Covers missed days after the person's last covered day, up to (not
  /// including) [until], spending a freeze token per day while any are held.
  /// With none left the streak simply resets — no event says so.
  void bridge(String who, GameDay until) {
    final p = person(who);
    final from = p.frontier;
    if (from == null) return;
    for (var d = from.next(); d < until; d = d.next()) {
      if (p.heldTokens == 0) return;
      if (p.wallet == 0) {
        // Collect a waiting token on the person's behalf to spend it.
        final t = p.waitingTokens.removeAt(0);
        _claim(who, t.rewardId);
        p.wallet += t.tokens;
      }
      p.wallet--;
      out.add(StreakFreezeUsed(
        eventId: stamp.newEventId(),
        deviceId: stamp.deviceId,
        actorId: who,
        occurredAt: now,
        createdAt: now,
        date: d,
      ));
      p.cover(d);
    }
  }

  /// Grants the freeze tokens the current run has earned: one per
  /// [Balance.streakDaysPerFreezeToken] days, while fewer than
  /// [Balance.maxFreezeTokens] are held.
  void tokens(String who) {
    final p = person(who);
    final end = p.frontier;
    if (end == null) return;
    var start = end;
    while (p.covered.contains(start.previous())) {
      start = start.previous();
    }
    final length = start.daysUntil(end) + 1;
    for (var m = Balance.streakDaysPerFreezeToken;
        m <= length;
        m += Balance.streakDaysPerFreezeToken) {
      final rewardId =
          '${GameReasonCodes.streakToken}:$who:${start.toKey()}:$m';
      if (p.seenRewards.contains(rewardId)) continue;
      if (p.heldTokens >= Balance.maxFreezeTokens) return;
      _grant(who,
          rewardId: rewardId,
          kind: 'freezeToken',
          tokens: 1,
          reasonCode: GameReasonCodes.streakToken);
      p.waitingTokens.add((rewardId: rewardId, tokens: 1));
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
    final p = person(who);
    if (!p.seenRewards.add(rewardId)) return;
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
