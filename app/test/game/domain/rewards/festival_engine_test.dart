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

/// Monday 2026-10-05 is day 5; its Saturday is the 10th. 18:00 UTC is
/// late morning in Vancouver.
DateTime _oct(int day, [int hour = 18]) => DateTime.utc(2026, 10, day, hour);

const GameDay _week = GameDay(2026, 10, 5);

class _Ledger {
  int _count = 0;
  String _id() => 'e${(_count++).toString().padLeft(5, '0')}';

  PurchaseAdded buy(String who, DateTime at, {String? purchaseId}) =>
      PurchaseAdded(
        eventId: _id(),
        deviceId: 'd-$who',
        userId: who,
        occurredAt: at,
        createdAt: at,
        purchaseId: purchaseId ?? 'p$_count',
        target: const VaultCharge(),
        amountCents: 1000,
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

  /// [who] logs on each of the given October days.
  List<Event> days(String who, Iterable<int> octoberDays) => [
    for (final day in octoberDays) buy(who, _oct(day)),
  ];
}

const _solo = Party([PartyAdult(_ada, inAdventure: true)]);
const _duo = Party([
  PartyAdult(_ada, inAdventure: true),
  PartyAdult(_ben, inAdventure: true),
]);
const _adaWithStandardBen = Party([
  PartyAdult(_ada, inAdventure: true),
  PartyAdult(_ben, inAdventure: false),
]);

class _Device {
  _Device({this.party = _solo, this.name = 'dev'});

  final Party party;
  final String name;
  final List<GameEvent> log = [];
  int _ids = 0;

  GameState get state => projectGameState(log);

  List<GameEvent> run(List<Event> ledger, DateTime now) {
    final out = const RewardEngine(monthEnd: NoMonthEndRewards()).evaluate(
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

  // Logging in the week of the 5th also shows up after the weekend of the
  // 3rd, which holds that week's market day; these helpers look only at the
  // week under test.
  List<FestivalHeld> festivals([List<GameEvent>? events]) => [
    for (final festival in (events ?? log).whereType<FestivalHeld>())
      if (festival.week == _week) festival,
  ];

  List<RewardGranted> grants(String reasonCode, [List<GameEvent>? events]) => [
    for (final grant in (events ?? log).whereType<RewardGranted>())
      if (grant.reasonCode == reasonCode &&
          grant.rewardId.endsWith(_week.toKey()))
        grant,
  ];
}

void main() {
  late _Ledger ledger;
  setUp(() => ledger = _Ledger());

  group('the weekend festival', () {
    test('is held from Saturday, not before', () {
      final dev = _Device();
      dev.run(ledger.days(_ada, [5, 6, 7, 8, 9]), _oct(9, 23));
      expect(dev.festivals(), isEmpty);
      final out = dev.run(const [], _oct(10));
      final festival = dev.festivals(out).single;
      expect(festival.actorId, _ada);
      expect(festival.week, _week);
      expect(festival.tier, FestivalTier.grandFestival);
      expect(festival.weekdaysLogged, 5);
      final reward = dev.grants(GameReasonCodes.festival, out).single;
      expect(reward.rewardId, 'festival:$_ada:2026-10-05');
      final loot = Balance.festivalRewards[FestivalTier.grandFestival]!;
      expect(reward.gems, loot.gems);
      expect(reward.materials, loot.materials);
      expect(
        dev.state.person(_ada).festivals[_week],
        FestivalTier.grandFestival,
      );
    });

    test('is sized to the week: 0–2 weekdays, 3–4, all 5', () {
      for (final (weekdays, tier) in [
        (2, FestivalTier.marketDay),
        (3, FestivalTier.fair),
        (4, FestivalTier.fair),
        (5, FestivalTier.grandFestival),
      ]) {
        final dev = _Device();
        dev.run(
          ledger.days(_ada, [for (var d = 0; d < weekdays; d++) 5 + d]),
          _oct(10),
        );
        expect(dev.festivals().single.tier, tier, reason: '$weekdays weekdays');
        expect(
          dev.grants(GameReasonCodes.festival).single.gems,
          Balance.festivalRewards[tier]!.gems,
        );
      }
    });

    test('weekend logs add no spirit to the week just ending', () {
      final dev = _Device();
      dev.run(ledger.days(_ada, [5, 6, 10, 11]), _oct(11));
      expect(dev.festivals().single.weekdaysLogged, 2);
    });

    test('re-running grants nothing more', () {
      final dev = _Device();
      final events = ledger.days(_ada, [5, 6, 7]);
      dev.run(events, _oct(10));
      expect(dev.festivals(dev.run(events, _oct(10, 20))), isEmpty);
      expect(dev.festivals(dev.run(const [], _oct(11))), isEmpty);
      expect(dev.grants(GameReasonCodes.festival), hasLength(1));
    });

    test('two devices holding the same festival credit it once', () {
      final events = ledger.days(_ada, [5, 6, 7]);
      final phone = _Device(name: 'phone')..run(events, _oct(10));
      final desktop = _Device(name: 'desktop')..run(events, _oct(10, 20));
      final merged = projectGameState([...phone.log, ...desktop.log]);
      expect(merged.person(_ada).festivals[_week], FestivalTier.fair);
      expect(
        merged.person(_ada).unclaimedRewards.keys,
        contains('festival:$_ada:2026-10-05'),
      );
      expect(merged.warnings, isEmpty);
    });

    test(
      'a week with no logged weekday holds a market day once they show up',
      () {
        final dev = _Device();
        dev.run(const [], _oct(10));
        expect(dev.festivals(), isEmpty);
        final out = dev.run(ledger.days(_ada, [11]), _oct(11));
        final festival = dev.festivals(out).single;
        expect(festival.tier, FestivalTier.marketDay);
        expect(festival.weekdaysLogged, 0);
      },
    );

    test('is held for every Adventure adult, not only the one logging', () {
      final dev = _Device(party: _duo);
      dev.run([
        ...ledger.days(_ada, [5, 6, 7]),
        ...ledger.days(_ben, [5]),
      ], _oct(9));
      // Saturday: only Ada logs, yet Ben's festival is held too.
      final out = dev.run(ledger.days(_ada, [10]), _oct(10));
      expect(
        {for (final f in dev.festivals(out)) f.actorId: f.tier},
        {_ada: FestivalTier.fair, _ben: FestivalTier.marketDay},
      );
    });

    test('never for a weekend older than the reward lookback', () {
      final dev = _Device();
      dev.run(ledger.days(_ada, [5, 6, 7, 8, 9]), _oct(9));
      // The weekend's Sunday (the 11th) has left the window.
      final later = _oct(12 + Balance.rewardLookbackDays);
      final out = dev.run(const [], later);
      expect(dev.festivals(out), isEmpty);
    });

    test('a Standard adult holds no festival', () {
      final dev = _Device(party: _adaWithStandardBen);
      dev.run(ledger.days(_ben, [5, 6, 7, 8, 9, 10]), _oct(10));
      expect(dev.festivals().where((f) => f.actorId == _ben), isEmpty);
    });

    test('voiding a purchase afterwards takes nothing away', () {
      final dev = _Device();
      final week = ledger.days(_ada, [5, 6, 7]);
      dev.run(week, _oct(10));
      final before = dev.state.person(_ada);
      final purchaseId = (week.first as PurchaseAdded).purchaseId;
      final out = dev.run([
        ...week,
        ledger.voided(_ada, _oct(10, 20), purchaseId),
      ], _oct(10, 21));
      expect(out, isEmpty);
      final after = dev.state.person(_ada);
      expect(after.festivals, before.festivals);
      expect(after.seenRewardIds, before.seenRewardIds);
    });
  });

  group('the joint festival bonus', () {
    test('both reaching a fair each earn the joint gems', () {
      final dev = _Device(party: _duo);
      final out = dev.run([
        ...ledger.days(_ada, [5, 6, 7]),
        ...ledger.days(_ben, [6, 7, 8, 9]),
      ], _oct(10));
      final joint = dev.grants(GameReasonCodes.festivalJoint, out);
      expect(
        {for (final grant in joint) grant.rewardId},
        {'festival.joint:$_ada:2026-10-05', 'festival.joint:$_ben:2026-10-05'},
      );
      expect(
        joint.every((grant) => grant.gems == Balance.jointFestivalGems),
        isTrue,
      );
      expect(
        dev.grants(GameReasonCodes.festivalJoint, dev.run(const [], _oct(11))),
        isEmpty,
      );
    });

    test('nothing when only one reaches a fair', () {
      final dev = _Device(party: _duo);
      dev.run([
        ...ledger.days(_ada, [5, 6, 7, 8, 9]),
        ...ledger.days(_ben, [5, 6]),
      ], _oct(10));
      expect(dev.grants(GameReasonCodes.festivalJoint), isEmpty);
    });

    test('nothing when alone', () {
      final dev = _Device();
      dev.run(ledger.days(_ada, [5, 6, 7, 8, 9]), _oct(10));
      expect(dev.grants(GameReasonCodes.festivalJoint), isEmpty);
    });

    test("a partner's idle week changes nothing for the other", () {
      final solo = _Device();
      final duo = _Device(party: _duo);
      final adaWeek = ledger.days(_ada, [5, 6, 7, 8, 9]);
      solo.run(adaWeek, _oct(10));
      duo.run(adaWeek, _oct(10));
      List<String> adaFestivalRewards(_Device device) => [
        for (final grant in device.log.whereType<RewardGranted>())
          if (grant.actorId == _ada && grant.rewardId.startsWith('festival'))
            '${grant.rewardId} ${grant.gems} ${grant.materials}',
      ];
      expect(adaFestivalRewards(duo), adaFestivalRewards(solo));
      expect(
        duo.state.person(_ada).festivals,
        solo.state.person(_ada).festivals,
      );
    });
  });
}
