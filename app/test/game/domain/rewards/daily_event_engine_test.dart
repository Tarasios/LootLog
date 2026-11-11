import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';
import 'package:lootlog/game/domain/town/daily_event.dart';

const _ada = 'ada';
const _ben = 'ben';

/// 18:00 UTC is 10–11am in Vancouver, safely inside the local day.
DateTime _at(int month, int day, [int hour = 18]) =>
    DateTime.utc(2026, month, day, hour);

class _Ledger {
  int _count = 0;
  String _id() => 'e${(_count++).toString().padLeft(5, '0')}';

  PurchaseAdded buy(String who, DateTime loggedAt, {String? purchaseId}) =>
      PurchaseAdded(
        eventId: _id(),
        deviceId: 'd-$who',
        userId: who,
        occurredAt: loggedAt,
        createdAt: loggedAt,
        purchaseId: purchaseId ?? 'p$_count',
        target: const VaultCharge(),
        amountCents: 1000,
      );

  NoSpendCheckedIn noSpend(String who, DateTime at) => NoSpendCheckedIn(
    eventId: _id(),
    deviceId: 'd-$who',
    userId: who,
    occurredAt: at,
    createdAt: at,
  );
}

const _soloAda = Party([PartyAdult(_ada, inAdventure: true)]);
const _adaWithStandardBen = Party([
  PartyAdult(_ada, inAdventure: true),
  PartyAdult(_ben, inAdventure: false),
]);

class _Device {
  _Device({this.party = _soloAda, this.name = 'dev'});

  final Party party;
  final String name;
  final List<GameEvent> log = [];
  int _ids = 0;

  GameState get state => projectGameState(log);

  GameEventStamp get stamp => GameEventStamp(
    deviceId: name,
    newEventId: () => '$name-${(_ids++).toString().padLeft(5, '0')}',
  );

  List<GameEvent> run(List<Event> ledger, DateTime now) {
    final out = const RewardEngine(
      monthEnd: NoMonthEndRewards(),
    ).evaluate(ledger, state, FixedClock(now), party: party, stamp: stamp);
    log.addAll(out);
    return out;
  }

  GameCommandResult resolve(
    String who,
    String offerId,
    DateTime now, {
    required bool accept,
  }) {
    final result = GameCommands(
      state: state,
      clock: FixedClock(now),
      actorId: who,
      stamp: stamp,
    ).resolveDailyEvent(offerId, accept: accept);
    if (result.accepted) log.addAll(result.events);
    return result;
  }

  List<DailyEventOffered> offers([List<GameEvent>? events]) =>
      (events ?? log).whereType<DailyEventOffered>().toList();
}

void main() {
  late _Ledger ledger;
  setUp(() => ledger = _Ledger());

  group('the daily town event', () {
    test('opening the day emits one offer for that person and day', () {
      final dev = _Device();
      final out = dev.run([ledger.buy(_ada, _at(10, 1))], _at(10, 1, 19));
      final offer = dev.offers(out).single;
      expect(offer.actorId, _ada);
      expect(offer.offerId, 'daily.event:$_ada:2026-10-01');
      expect(offer.day, const GameDay(2026, 10, 1));
    });

    test('a no-spend check-in opens the day and its event too', () {
      final dev = _Device();
      final out = dev.run([ledger.noSpend(_ada, _at(10, 1))], _at(10, 1, 19));
      expect(dev.offers(out), hasLength(1));
    });

    test('later logs that day, and re-runs, emit nothing more', () {
      final dev = _Device();
      final first = ledger.buy(_ada, _at(10, 1));
      dev.run([first], _at(10, 1, 19));
      final second = ledger.buy(_ada, _at(10, 1, 20));
      expect(dev.offers(dev.run([second], _at(10, 1, 21))), isEmpty);
      expect(dev.offers(dev.run([first, second], _at(10, 1, 22))), isEmpty);
      expect(dev.offers(), hasLength(1));
    });

    test('two devices offering the same day credit one offer', () {
      final events = [ledger.buy(_ada, _at(10, 1))];
      final phone = _Device(name: 'phone')..run(events, _at(10, 1, 19));
      final desktop = _Device(name: 'desktop')..run(events, _at(10, 1, 20));
      final merged = projectGameState([...phone.log, ...desktop.log]);
      expect(merged.person(_ada).dailyOffers, hasLength(1));
      expect(merged.warnings, isEmpty);
      expect(merged, phone.state);
    });

    test("devices that saw different openers keep the earlier one's offer", () {
      // The phone saw only the morning purchase, the desktop only the
      // evening one; each rolled the day's offer from its own opener.
      final morning = ledger.buy(_ada, _at(10, 1, 17));
      final evening = ledger.buy(_ada, _at(10, 1, 23));
      final phone = _Device(name: 'phone')..run([morning], _at(10, 1, 23));
      final desktop = _Device(name: 'desktop')..run([evening], _at(10, 1, 23));
      final merged = projectGameState([...phone.log, ...desktop.log]);
      final reversed = projectGameState([...desktop.log, ...phone.log]);
      final offer = merged.offerFor(_ada, const GameDay(2026, 10, 1))!;
      expect(merged.person(_ada).dailyOffers, hasLength(1));
      expect(reversed.offerFor(_ada, const GameDay(2026, 10, 1)), offer);
      final phoneOffer = phone.offers().single;
      expect(offer.kind, phoneOffer.kind);
      expect(offer.receives, phoneOffer.receives);
      expect(offer.flavourKey, phoneOffer.flavourKey);
    });

    test('the offer is rolled from the ledger event that opened the day', () {
      final dev = _Device();
      final opener = ledger.buy(_ada, _at(10, 1));
      final out = dev.run([
        opener,
        ledger.buy(_ada, _at(10, 1, 20)),
      ], _at(10, 1, 21));
      final expected = rollDailyOffer(
        personId: _ada,
        day: const GameDay(2026, 10, 1),
        seedEventId: opener.eventId,
        hall: HallState.starter(),
        now: _at(10, 1, 21),
      );
      final offer = dev.offers(out).single;
      expect(offer.kind, expected.kind);
      expect(offer.gives, expected.gives);
      expect(offer.receives, expected.receives);
      expect(offer.flavourKey, expected.flavourKey);
      expect(offer.occurredAt, opener.createdAt);
    });

    test('a Standard-mode adult gets no offer', () {
      final dev = _Device(party: _adaWithStandardBen);
      final out = dev.run([ledger.buy(_ben, _at(10, 1))], _at(10, 1, 19));
      expect(dev.offers(out), isEmpty);
    });

    test('only today gets an event: a catch-up over earlier days does not', () {
      final dev = _Device();
      final out = dev.run([
        ledger.buy(_ada, _at(9, 29)),
        ledger.buy(_ada, _at(9, 30)),
        ledger.buy(_ada, _at(10, 1)),
      ], _at(10, 1, 19));
      expect(dev.offers(out).single.day, const GameDay(2026, 10, 1));
    });

    test("today's offer is offered; yesterday's is not today's", () {
      final dev = _Device();
      dev.run([ledger.buy(_ada, _at(10, 1))], _at(10, 1, 19));
      final state = dev.state;
      expect(
        state.offerFor(_ada, const GameDay(2026, 10, 1))?.offerId,
        'daily.event:$_ada:2026-10-01',
      );
      expect(state.offerFor(_ada, const GameDay(2026, 10, 2)), isNull);
      expect(state.offerFor(_ben, const GameDay(2026, 10, 1)), isNull);
    });

    test('a resolved offer is gone, and the next day brings a new one', () {
      final dev = _Device();
      dev.run([ledger.buy(_ada, _at(10, 1))], _at(10, 1, 19));
      dev.resolve(
        _ada,
        'daily.event:$_ada:2026-10-01',
        _at(10, 1, 20),
        accept: false,
      );
      expect(dev.state.offerFor(_ada, const GameDay(2026, 10, 1)), isNull);
      // Re-running over the same day never re-offers a resolved event.
      expect(
        dev.offers(dev.run([ledger.buy(_ada, _at(10, 1, 21))], _at(10, 1, 22))),
        isEmpty,
      );
      final next = dev.run([ledger.buy(_ada, _at(10, 2))], _at(10, 2, 19));
      expect(dev.offers(next).single.day, const GameDay(2026, 10, 2));
    });
  });

  group('firewall', () {
    test('the money reducer reads the same ledger whatever the game does', () {
      final dev = _Device();
      final purchase = ledger.buy(_ada, _at(10, 1), purchaseId: 'p-1');
      final ledgerEvents = List<Event>.unmodifiable([
        MemberSet(
          eventId: 'm1',
          deviceId: 'd',
          userId: _ada,
          occurredAt: _at(9, 1),
          createdAt: _at(9, 1),
          memberId: _ada,
          name: 'Ada',
          role: MemberRole.adult,
        ),
        purchase,
      ]);
      final before = reduce(ledgerEvents, asOf: _at(10, 2)).debugSnapshot();
      dev.run(ledgerEvents, _at(10, 1, 19));
      final offerId = 'daily.event:$_ada:2026-10-01';
      final accepted = dev.resolve(_ada, offerId, _at(10, 1, 20), accept: true);
      // A trader in an empty hall can't be paid; declining resolves it too.
      if (!accepted.accepted) {
        dev.resolve(_ada, offerId, _at(10, 1, 20), accept: false);
      }
      expect(dev.log.whereType<DailyEventOffered>(), isNotEmpty);
      expect(dev.log.whereType<DailyEventResolved>(), isNotEmpty);
      expect(reduce(ledgerEvents, asOf: _at(10, 2)).debugSnapshot(), before);
    });
  });
}
