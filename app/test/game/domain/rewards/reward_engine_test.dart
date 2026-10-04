import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/reason_codes.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';

const _ada = 'ada';
const _ben = 'ben';

/// 18:00 UTC is 10–11am in Vancouver, safely inside the local day.
DateTime _at(int m, int d, [int hour = 18]) => DateTime.utc(2026, m, d, hour);

GameDay _day(int m, int d) => GameDay(2026, m, d);

class _Ledger {
  int _n = 0;
  String _id() => 'e${(_n++).toString().padLeft(5, '0')}';

  PurchaseAdded buy(
    String who,
    DateTime loggedAt, {
    DateTime? happenedAt,
    int cents = 1000,
    String? amends,
    String? purchaseId,
  }) =>
      PurchaseAdded(
        eventId: _id(),
        deviceId: 'd-$who',
        userId: who,
        occurredAt: happenedAt ?? loggedAt,
        createdAt: loggedAt,
        purchaseId: purchaseId ?? 'p$_n',
        target: const VaultCharge(),
        amountCents: cents,
        amendsPurchaseId: amends,
      );

  PurchaseVoided voided(String who, DateTime at, String purchaseId) =>
      PurchaseVoided(
        eventId: _id(),
        deviceId: 'd-$who',
        userId: who,
        occurredAt: at,
        createdAt: at,
        purchaseId: purchaseId,
      );

  NoSpendCheckedIn noSpend(String who, DateTime at) => NoSpendCheckedIn(
        eventId: _id(),
        deviceId: 'd-$who',
        userId: who,
        occurredAt: at,
        createdAt: at,
      );

  ReconcileCompleted reconcile(String who, DateTime at, GameDay week) =>
      ReconcileCompleted(
        eventId: _id(),
        deviceId: 'd-$who',
        userId: who,
        occurredAt: at,
        createdAt: at,
        weekStart: week,
      );
}

const _soloAda = Party([PartyAdult(_ada, inAdventure: true)]);
const _duo = Party([
  PartyAdult(_ada, inAdventure: true),
  PartyAdult(_ben, inAdventure: true),
]);
const _adaWithStandardBen = Party([
  PartyAdult(_ada, inAdventure: true),
  PartyAdult(_ben, inAdventure: false),
]);

/// One device: runs the engine, keeps the game log it wrote, and projects it
/// the way the app does.
class _Device {
  _Device({this.party = _soloAda, this.lookbackDays = Balance.rewardLookbackDays, this.name = 'dev'});

  final Party party;
  final int lookbackDays;
  final String name;
  final List<GameEvent> log = [];
  int _ids = 0;

  late final RewardEngine engine = RewardEngine(lookbackDays: lookbackDays);

  GameState get state => projectGameState(log);

  List<GameEvent> run(List<Event> ledger, DateTime now) {
    final out = engine.evaluate(
      ledger,
      state,
      FixedClock(now),
      party: party,
      stamp: GameEventStamp(
        deviceId: name,
        newEventId: () => '$name-${(_ids++).toString().padLeft(5, '0')}',
      ),
    );
    log.addAll(out);
    return out;
  }

  /// The person taps a waiting reward in the hall.
  void claim(String who, String rewardId, DateTime when) =>
      log.add(RewardClaimed(
        eventId: '$name-claim-${_ids++}',
        deviceId: name,
        actorId: who,
        occurredAt: when,
        createdAt: when,
        rewardId: rewardId,
      ));

  List<RewardGranted> grants([List<GameEvent>? events]) =>
      (events ?? log).whereType<RewardGranted>().toList();

  List<ChestGranted> chests([List<GameEvent>? events]) =>
      (events ?? log).whereType<ChestGranted>().toList();

  List<RewardGranted> byReason(String code, [List<GameEvent>? events]) =>
      grants(events).where((r) => r.reasonCode == code).toList();

  /// Gems waiting for [who] in the hall, claimed or not.
  int gemsEarned(String who) =>
      grants().where((r) => r.actorId == who).fold(0, (s, r) => s + r.gems);
}

int _capped(_Device d) =>
    d.byReason(GameReasonCodes.extraLog).length +
    d.byReason(GameReasonCodes.timely).length;

void main() {
  late _Ledger ledger;
  setUp(() => ledger = _Ledger());

  group('active day', () {
    test('the first purchase of a day grants an unclaimed 5-gem pouch', () {
      final dev = _Device();
      final out = dev.run(
          [ledger.buy(_ada, _at(10, 1), happenedAt: _at(9, 20))], _at(10, 1));
      final pouch = dev.grants(out).single;
      expect(pouch.rewardId, 'log.daily:$_ada:2026-10-01');
      expect(pouch.kind, 'gemPouch');
      expect(pouch.reasonCode, GameReasonCodes.dailyLog);
      expect(pouch.actorId, _ada);
      expect(pouch.gems, 5);
      final p = dev.state.person(_ada);
      expect(p.unclaimedRewards.keys, [pouch.rewardId]);
      expect(p.gems, 0); // not in the wallet until tapped in the hall
      expect(p.streak.loggedDays, {_day(10, 1)});
    });

    test('a no-spend check-in opens the day just like a purchase', () {
      final dev = _Device();
      final out = dev.run([ledger.noSpend(_ada, _at(10, 1))], _at(10, 1));
      expect(dev.grants(out).single.reasonCode, GameReasonCodes.noSpendCheckIn);
      expect(dev.state.person(_ada).streak.loggedDays, {_day(10, 1)});
    });

    test('the pouch is stamped with the logged instant, not when it ran', () {
      final dev = _Device();
      final out = dev.run([ledger.buy(_ada, _at(9, 28))], _at(10, 1));
      expect(dev.grants(out).first.occurredAt, _at(9, 28));
    });

    test('a claimed pouch moves its gems into the wallet', () {
      final dev = _Device();
      dev.run([ledger.noSpend(_ada, _at(10, 1))], _at(10, 1));
      dev.claim(_ada, 'log.daily:$_ada:2026-10-01', _at(10, 1, 19));
      expect(dev.state.person(_ada).gems, 5);
    });
  });

  group('further purchases', () {
    test('each further purchase that day grants +1 gem', () {
      final dev = _Device();
      final late = _at(9, 28); // logged days later: no timely bonus
      dev.run([
        ledger.buy(_ada, _at(10, 1), happenedAt: late),
        ledger.buy(_ada, _at(10, 1, 19), happenedAt: late),
        ledger.buy(_ada, _at(10, 1, 20), happenedAt: late),
      ], _at(10, 1, 21));
      final extras = dev.byReason(GameReasonCodes.extraLog);
      expect(extras, hasLength(2));
      expect(extras.every((r) => r.gems == 1), isTrue);
      expect(dev.gemsEarned(_ada), 5 + 2);
    });

    test('the daily cap stops extra gems at +5', () {
      final dev = _Device();
      final late = _at(9, 20);
      dev.run([
        for (var h = 0; h < 9; h++)
          ledger.buy(_ada, _at(10, 1, 16 + h), happenedAt: late),
      ], _at(10, 2, 1));
      expect(dev.byReason(GameReasonCodes.extraLog), hasLength(5));
      // The pouch is not part of the cap.
      expect(dev.byReason(GameReasonCodes.dailyLog), hasLength(1));
      expect(dev.gemsEarned(_ada), 5 + 5);
    });

    test('the cap is per day: a new day starts fresh', () {
      final dev = _Device();
      final late = _at(9, 1);
      dev.run([
        for (var h = 0; h < 7; h++)
          ledger.buy(_ada, _at(10, 1, 16 + h), happenedAt: late),
        for (var h = 0; h < 3; h++)
          ledger.buy(_ada, _at(10, 2, 16 + h), happenedAt: late),
      ], _at(10, 2, 20));
      expect(dev.gemsEarned(_ada), (5 + 5) + (5 + 2));
    });
  });

  group('timely bonus', () {
    test('a purchase logged within 24h of when it happened earns +1', () {
      final dev = _Device();
      final out = dev.run([
        ledger.buy(_ada, _at(10, 1, 20), happenedAt: _at(10, 1, 2)),
      ], _at(10, 1, 21));
      expect(dev.byReason(GameReasonCodes.timely, out).single.gems, 1);
    });

    test('a purchase logged more than 24h late earns no timely bonus', () {
      final dev = _Device();
      final out = dev.run(
          [ledger.buy(_ada, _at(10, 3), happenedAt: _at(10, 1))], _at(10, 3));
      expect(dev.byReason(GameReasonCodes.timely, out), isEmpty);
    });

    test('timely gems share the daily cap with further purchases', () {
      final dev = _Device();
      dev.run([
        // All timely: 1st = pouch + timely, 2nd/3rd = extra + timely each.
        for (var h = 0; h < 5; h++) ledger.buy(_ada, _at(10, 1, 16 + h)),
      ], _at(10, 1, 22));
      expect(_capped(dev), 5);
      expect(dev.gemsEarned(_ada), 5 + 5);
    });
  });

  group('edits and deletes', () {
    test('an edited purchase grants nothing', () {
      final dev = _Device();
      dev.run([ledger.buy(_ada, _at(10, 1), purchaseId: 'p-orig')], _at(10, 1));
      final out = dev.run([
        ledger.voided(_ada, _at(10, 1, 19), 'p-orig'),
        ledger.buy(_ada, _at(10, 1, 19), amends: 'p-orig', purchaseId: 'p-fix'),
      ], _at(10, 1, 19));
      expect(out, isEmpty);
    });

    test('an edit on a fresh day does not open that day either', () {
      final dev = _Device();
      final out = dev.run(
          [ledger.buy(_ada, _at(10, 2), amends: 'p-old', purchaseId: 'p-new')],
          _at(10, 2));
      expect(out, isEmpty);
    });

    test('deleting a purchase leaves its granted rewards intact', () {
      final dev = _Device();
      final buy = ledger.buy(_ada, _at(10, 1), purchaseId: 'p1');
      dev.run([buy], _at(10, 1));
      dev.claim(_ada, 'log.daily:$_ada:2026-10-01', _at(10, 1, 19));
      final before = dev.state.person(_ada);

      // The ledger now holds the purchase AND its void; re-evaluate it all.
      final out = dev.run(
          [buy, ledger.voided(_ada, _at(10, 1, 20), 'p1')], _at(10, 1, 20));
      expect(out, isEmpty);
      final after = dev.state.person(_ada);
      expect(after.gems, before.gems);
      expect(after.seenRewardIds, before.seenRewardIds);
      expect(after.unclaimedRewards.keys, before.unclaimedRewards.keys);
    });
  });

  group('idempotency', () {
    List<Event> week() => [
          for (var d = 0; d < 4; d++) ledger.buy(_ada, _at(9, 28 + d)),
          ledger.buy(_ben, _at(9, 29)),
          ledger.reconcile(_ada, _at(10, 1), _day(9, 21)),
        ];

    test('re-running evaluate over the same events grants nothing new', () {
      final dev = _Device(party: _duo);
      final events = week();
      expect(dev.run(events, _at(10, 1, 23)), isNotEmpty);
      expect(dev.run(events, _at(10, 1, 23)), isEmpty);
      expect(dev.run(events, _at(10, 1, 23)), isEmpty);
    });

    test('reward ids are built from rule, person and period', () {
      final dev = _Device(party: _duo)..run(week(), _at(10, 1, 23));
      expect(
          dev.grants().map((r) => r.rewardId),
          containsAll([
            'log.daily:$_ada:2026-09-28',
            'week.reconcile:$_ada:2026-09-21',
          ]));
      expect(
          dev.chests().map((c) => c.chestId).toSet(),
          containsAll([
            'week.checkin:$_ada:2026-09-28',
            'week.party:$_ada:2026-09-28',
            'week.party:$_ben:2026-09-28',
            'week.reconcile:$_ada:2026-09-21',
          ]));
    });

    test('two devices granting the same rewards credit them once', () {
      // Both devices see Ada's purchases before syncing each other's grants.
      final events = week();
      final phone = _Device(party: _duo, name: 'phone')
        ..run(events, _at(10, 1, 20));
      final desktop = _Device(party: _duo, name: 'desktop')
        ..run(events, _at(10, 1, 23));
      final merged = projectGameState([...phone.log, ...desktop.log]);
      expect(merged, phone.state);
      expect(merged.warnings, isEmpty);
    });
  });

  group('weekly check-in', () {
    test('4 active days in a Mon–Sun week earn a wood chest', () {
      final dev = _Device();
      // Week of Mon 2026-09-28: active Mon, Tue, Thu, then Sun.
      dev.run([
        ledger.buy(_ada, _at(9, 28)),
        ledger.noSpend(_ada, _at(9, 29)),
        ledger.buy(_ada, _at(10, 1)),
      ], _at(10, 1));
      expect(dev.chests(), isEmpty);
      final out = dev.run([ledger.buy(_ada, _at(10, 4))], _at(10, 4));
      final chest = dev.chests(out).single;
      expect(chest.chestId, 'week.checkin:$_ada:2026-09-28');
      expect(chest.chestType, ChestType.wood);
      expect(chest.reasonCode, GameReasonCodes.weeklyCheckIn);
      expect(dev.state.person(_ada).unopenedChests.keys, [chest.chestId]);
    });

    test('active days in two different weeks do not combine', () {
      final dev = _Device();
      dev.run([
        ledger.buy(_ada, _at(9, 26)), // Sat, previous week
        ledger.buy(_ada, _at(9, 27)), // Sun, previous week
        ledger.buy(_ada, _at(9, 28)), // Mon
        ledger.buy(_ada, _at(9, 29)), // Tue
      ], _at(9, 29));
      expect(dev.chests(), isEmpty);
    });

    test('a frozen day is not an active day', () {
      final dev = _Device(lookbackDays: 60);
      // A 7-day streak earns a token; the 8th (Tue Sep 8) is frozen.
      dev.run([for (var d = 1; d <= 7; d++) ledger.noSpend(_ada, _at(9, d))],
          _at(9, 7));
      dev.run([ledger.noSpend(_ada, _at(9, 9))], _at(9, 9));
      expect(dev.state.person(_ada).streak.frozenDays, {_day(9, 8)});
      // Week of Mon Sep 7: Mon + Wed active, Tue frozen → 2 active days.
      expect(dev.chests().where((c) => c.chestId.endsWith('2026-09-07')),
          isEmpty);
    });
  });

  group('weekly reconcile', () {
    test('completing a reconcile earns an iron chest and 10 gems', () {
      final dev = _Device();
      final out = dev.run(
          [ledger.reconcile(_ada, _at(10, 5), _day(9, 28))], _at(10, 5));
      expect(dev.chests(out).single.chestType, ChestType.iron);
      final gems = dev.grants(out).single;
      expect(gems.reasonCode, GameReasonCodes.weeklyReconcile);
      expect(gems.gems, 10);
      expect(gems.rewardId, 'week.reconcile:$_ada:2026-09-28');
    });

    test('reconciling the same week twice earns once', () {
      final dev = _Device();
      dev.run([ledger.reconcile(_ada, _at(10, 5), _day(9, 28))], _at(10, 5));
      final out = dev.run(
          [ledger.reconcile(_ada, _at(10, 6), _day(9, 28))], _at(10, 6));
      expect(out, isEmpty);
    });

    test('reconciling is not an active day', () {
      final dev = _Device();
      dev.run([ledger.reconcile(_ada, _at(10, 5), _day(9, 28))], _at(10, 5));
      expect(dev.state.person(_ada).streak.coveredDays, isEmpty);
    });

    test('a week that has not started cannot be reconciled', () {
      final dev = _Device();
      final out = dev.run(
          [ledger.reconcile(_ada, _at(10, 5), _day(10, 12))], _at(10, 5));
      expect(out, isEmpty);
    });
  });

  group('streak & freeze tokens', () {
    List<Event> daily(int from, int to) => [
          for (var d = from; d <= to; d++) ledger.noSpend(_ada, _at(9, d)),
        ];

    test('consecutive active days build a streak', () {
      final dev = _Device(lookbackDays: 60)..run(daily(1, 5), _at(9, 5));
      expect(dev.state.person(_ada).streak.count, 5);
    });

    test('every 7-day streak earns one freeze token', () {
      final dev = _Device(lookbackDays: 60)..run(daily(1, 6), _at(9, 6));
      expect(dev.byReason(GameReasonCodes.streakToken), isEmpty);
      final out = dev.run(daily(7, 7), _at(9, 7));
      final token = dev.byReason(GameReasonCodes.streakToken, out).single;
      expect(token.rewardId, 'streak.token:$_ada:2026-09-01:7');
      expect(token.tokens, 1);
      expect(token.kind, 'freezeToken');
    });

    test('a missed day auto-consumes a token and keeps the streak', () {
      final dev = _Device(lookbackDays: 60)..run(daily(1, 7), _at(9, 7));
      // Sept 8 missed; Ada shows up on the 9th.
      final out = dev.run(daily(9, 9), _at(9, 9));
      // The waiting token is collected and spent on the missed day.
      expect(out.whereType<RewardClaimed>().single.rewardId,
          'streak.token:$_ada:2026-09-01:7');
      expect(out.whereType<StreakFreezeUsed>().single.date, _day(9, 8));
      final p = dev.state.person(_ada);
      expect(p.streak.count, 9);
      expect(p.freezeTokens, 0);
      expect(dev.state.warnings, isEmpty);
    });

    test('a freeze is used as soon as the missed day is over', () {
      final dev = _Device(lookbackDays: 60)..run(daily(1, 7), _at(9, 7));
      // Evaluated on the 9th with nothing new: the 8th is over and missed.
      final out = dev.run(const [], _at(9, 9));
      expect(out.whereType<StreakFreezeUsed>().single.date, _day(9, 8));
      // Running again does not use a second token for the same day.
      expect(dev.run(const [], _at(9, 9)), isEmpty);
    });

    test('a claimed token is spent from the wallet', () {
      final dev = _Device(lookbackDays: 60)..run(daily(1, 7), _at(9, 7));
      dev.claim(_ada, 'streak.token:$_ada:2026-09-01:7', _at(9, 8));
      final out = dev.run(const [], _at(9, 9));
      expect(out.whereType<RewardClaimed>(), isEmpty);
      expect(out.whereType<StreakFreezeUsed>(), hasLength(1));
      expect(dev.state.person(_ada).freezeTokens, 0);
      expect(dev.state.warnings, isEmpty);
    });

    test('with no token, a missed day quietly resets the streak', () {
      final dev = _Device(lookbackDays: 60)..run(daily(1, 3), _at(9, 3));
      final out = dev.run(daily(5, 5), _at(9, 5));
      expect(out.whereType<StreakFreezeUsed>(), isEmpty);
      // Nothing negative is emitted — only the new day's rewards.
      expect(out.every((e) => e is RewardGranted || e is ChestGranted), isTrue);
      expect(dev.state.person(_ada).streak.count, 1);
    });

    test('tokens are held to a maximum of 3', () {
      final dev = _Device(lookbackDays: 60)..run(daily(1, 30), _at(9, 30));
      final tokens = dev.byReason(GameReasonCodes.streakToken);
      expect(tokens, hasLength(3)); // days 7, 14, 21 — 28 is over the cap
    });

    test('two missed days use two tokens, a third resets', () {
      final dev = _Device(lookbackDays: 60)..run(daily(1, 14), _at(9, 14));
      final out = dev.run(daily(18, 18), _at(9, 18)); // 15, 16, 17 missed
      expect(out.whereType<StreakFreezeUsed>().map((f) => f.date),
          [_day(9, 15), _day(9, 16)]);
      expect(dev.state.person(_ada).streak.count, 1);
      expect(dev.state.warnings, isEmpty);
    });
  });

  group('party', () {
    test('both Adventure partners active in a week earn a party chest each',
        () {
      final dev = _Device(party: _duo);
      dev.run([ledger.buy(_ada, _at(9, 28))], _at(9, 28));
      expect(dev.chests(), isEmpty);
      final out = dev.run([ledger.noSpend(_ben, _at(10, 2))], _at(10, 2));
      final party =
          dev.chests(out).where((c) => c.chestType == ChestType.party);
      expect(party.map((c) => c.actorId).toSet(), {_ada, _ben});
    });

    test('no party chest when one partner is in Standard mode', () {
      final dev = _Device(party: _adaWithStandardBen)
        ..run([ledger.buy(_ada, _at(9, 28)), ledger.buy(_ben, _at(9, 29))],
            _at(9, 29));
      expect(dev.chests().where((c) => c.chestType == ChestType.party),
          isEmpty);
    });

    test("an inactive partner never reduces the other's rewards", () {
      List<String> idsFor(Party party) {
        final l = _Ledger();
        final dev = _Device(party: party)
          ..run([for (var d = 28; d <= 30; d++) l.buy(_ada, _at(9, d))],
              _at(9, 30));
        return [for (final e in dev.log) _identity(e)];
      }

      expect(idsFor(_duo), idsFor(_soloAda));
    });
  });

  group('caravan', () {
    test("a Standard partner's active day sends a caravan to the party pool",
        () {
      final dev = _Device(party: _adaWithStandardBen);
      final out = dev.run([ledger.buy(_ben, _at(10, 1))], _at(10, 1));
      final caravan = dev.grants(out).single;
      expect(caravan.reasonCode, GameReasonCodes.caravan);
      expect(caravan.rewardId, 'caravan:$_ben:2026-10-01');
      expect(caravan.gems, 0);
      expect(caravan.materials, Balance.caravanMaterials);
      // The caravan delivers itself: straight into the shared pool.
      expect(out.whereType<RewardClaimed>().single.rewardId, caravan.rewardId);
      final s = dev.state;
      expect(s.hall.materials, Balance.caravanMaterials);
      expect(s.person(_ben).gems, 0);
      expect(s.person(_ben).streak.coveredDays, isEmpty);
    });

    test('one caravan per Standard partner per day', () {
      final dev = _Device(party: _adaWithStandardBen)
        ..run([
          ledger.buy(_ben, _at(10, 1)),
          ledger.buy(_ben, _at(10, 1, 19)),
          ledger.noSpend(_ben, _at(10, 1, 20)),
        ], _at(10, 1, 21));
      expect(dev.grants(), hasLength(1));
    });

    test('no caravan without an Adventure party to supply', () {
      final dev = _Device(party: const Party([
        PartyAdult(_ben, inAdventure: false),
      ]));
      expect(dev.run([ledger.buy(_ben, _at(10, 1))], _at(10, 1)), isEmpty);
    });
  });

  group('guards', () {
    test('no reward depends on transaction amounts', () {
      List<String> runWith(int cents) {
        final l = _Ledger();
        final dev = _Device(party: _duo)
          ..run([
            for (var d = 26; d <= 30; d++)
              l.buy(_ada, _at(9, d), cents: cents * d),
            l.buy(_ben, _at(9, 29), cents: cents),
            l.buy(_ada, _at(9, 30, 20), cents: cents * 7),
          ], _at(9, 30, 22));
        return [for (final e in dev.log) _identity(e)];
      }

      expect(runWith(1), runWith(999999));
    });

    test('no emitted event reduces anything', () {
      final dev = _Device(party: _adaWithStandardBen, lookbackDays: 60)
        ..run([
          for (var d = 1; d <= 20; d++) ledger.buy(_ada, _at(9, d)),
          for (var d = 1; d <= 20; d += 3) ledger.buy(_ben, _at(9, d)),
          ledger.reconcile(_ada, _at(9, 21), _day(9, 14)),
        ], _at(9, 25));
      for (final r in dev.grants()) {
        expect(r.gems, greaterThanOrEqualTo(0));
        expect(r.tokens, greaterThanOrEqualTo(0));
        expect(r.materials.amounts.values.every((n) => n > 0), isTrue);
      }
      // Only the reward kinds the engine is allowed to write.
      expect(
          dev.log.every((e) =>
              e is RewardGranted ||
              e is ChestGranted ||
              e is RewardClaimed ||
              e is StreakFreezeUsed),
          isTrue);
      expect(dev.state.warnings, isEmpty);
    });

    test('activity older than the lookback window is not rewarded', () {
      final dev = _Device();
      expect(dev.run([ledger.buy(_ada, _at(9, 1))], _at(10, 1)), isEmpty);
    });

    test('people outside the party earn nothing', () {
      final dev = _Device();
      expect(dev.run([ledger.buy('stranger', _at(10, 1))], _at(10, 1)),
          isEmpty);
    });

    test('the month-end hook runs with the evaluation', () {
      final hook = _RecordingMonthEnd();
      final out = RewardEngine(monthEnd: hook).evaluate(
        [ledger.noSpend(_ada, _at(10, 1))],
        GameState.initial(),
        FixedClock(_at(10, 1)),
        party: _soloAda,
        stamp: GameEventStamp(deviceId: 'dev', newEventId: () => 'x'),
      );
      expect(hook.calls, 1);
      expect(out.whereType<ChestGranted>().map((c) => c.chestId),
          contains('spoils:test'));
    });
  });
}

/// What an event grants, without its device-specific envelope.
String _identity(GameEvent e) => '${e.type}:${e.payload()}';

class _RecordingMonthEnd implements MonthEndRewards {
  int calls = 0;

  @override
  List<GameEvent> evaluate(
    List<Event> newLedgerEvents,
    GameState state,
    Clock clock, {
    required Party party,
    required GameEventStamp stamp,
  }) {
    calls++;
    return [
      ChestGranted(
        eventId: stamp.newEventId(),
        deviceId: stamp.deviceId,
        actorId: _ada,
        occurredAt: clock.now(),
        createdAt: clock.now(),
        chestId: 'spoils:test',
        chestType: ChestType.spoils,
        reasonCode: 'spoils.test',
      ),
    ];
  }
}
