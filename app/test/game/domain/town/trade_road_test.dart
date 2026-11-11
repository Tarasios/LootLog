import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/reason_codes.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';
import 'package:lootlog/game/domain/town/trade_road.dart';

const _ada = 'ada';
const _ben = 'ben';

/// 18:00 UTC is 11am in Vancouver, safely inside the local day.
DateTime _at(int day, [int hour = 18]) => DateTime.utc(2026, 10, day, hour);

GameDay _day(int day) => GameDay(2026, 10, day);

PurchaseAdded _buy(String who, int day, {int hour = 18}) => PurchaseAdded(
      eventId: 'e-$who-$day-$hour',
      deviceId: 'd-$who',
      userId: who,
      occurredAt: _at(day, hour),
      createdAt: _at(day, hour),
      purchaseId: 'p-$who-$day-$hour',
      target: const VaultCharge(),
      amountCents: 1000,
    );

const _duo = Party([
  PartyAdult(_ada, inAdventure: true),
  PartyAdult(_ben, inAdventure: true),
]);

const _adaWithStandardBen = Party([
  PartyAdult(_ada, inAdventure: true),
  PartyAdult(_ben, inAdventure: false),
]);

class _Device {
  _Device(this.name, {this.party = _duo});

  final String name;
  final Party party;
  final List<GameEvent> log = [];
  int _ids = 0;

  GameState get state => projectGameState(log);

  GameEventStamp get stamp => GameEventStamp(
        deviceId: name,
        newEventId: () => '$name-${(_ids++).toString().padLeft(5, '0')}',
      );

  List<GameEvent> run(List<Event> ledger, DateTime now) {
    final out = const RewardEngine(monthEnd: NoMonthEndRewards())
        .evaluate(ledger, state, FixedClock(now), party: party, stamp: stamp);
    log.addAll(out);
    return out;
  }

  GameCommandResult command(String who, DateTime now,
      GameCommandResult Function(GameCommands commands) body) {
    final result = body(GameCommands(
        state: state, clock: FixedClock(now), actorId: who, stamp: stamp));
    log.addAll(result.events);
    return result;
  }

  List<RewardGranted> tradeRoads([String? who]) => [
        for (final grant in log.whereType<RewardGranted>())
          if (grant.reasonCode == GameReasonCodes.tradeRoad &&
              (who == null || grant.actorId == who))
            grant,
      ];
}

void main() {
  test('a trade-road reward id names the neighbour whose caravan it is', () {
    final day = GameDay.fromInstant(DateTime.utc(2026, 10, 3, 18));
    expect(tradeRoadNeighbourOf(tradeRoadRewardId('u1', day, 'u2')), 'u2');
    expect(tradeRoadNeighbourOf('log.daily:u1:2026-10-03'), isNull);
  });

  group('tradeRoadDelivery', () {
    HallState townWith(Map<int, (BuildingType, int)> buildings) =>
        HallState.starter().copyWith(plots: {
          for (final entry in buildings.entries)
            entry.key: PlotState(
              entry.key,
              BuildingState(
                type: entry.value.$1,
                tier: entry.value.$2,
                startedAt: _at(1),
                completesAt: _at(1),
              ),
            ),
        });

    test("sends the neighbour's busiest material, scaled by its producer tier", () {
      final town = townWith({
        0: (BuildingType.lumberyard, 1),
        1: (BuildingType.quarry, 3),
      });
      final goods = tradeRoadDelivery(town, _at(2));
      final quarryRate = Balance.buildings[BuildingType.quarry]!
          .productionPerHour.entries.first;
      expect(goods.amounts.keys.single, quarryRate.key);
      expect(goods.amounts.values.single, Balance.tradeRoadAmount(3));
    });

    test('equal rates go to the earlier material', () {
      final town = townWith({0: (BuildingType.lumberyard, 1)});
      final lumberRate = Balance.buildings[BuildingType.lumberyard]!
          .productionPerHour[MaterialKind.lumber]![0];
      final goods = tradeRoadDelivery(town, _at(2));
      expect(goods, MaterialBundle({MaterialKind.lumber: Balance.tradeRoadAmount(1)}));
      expect(lumberRate, greaterThan(0));
    });

    test('a town with no producer yet still sends the base amount', () {
      expect(tradeRoadDelivery(HallState.starter(), _at(2)),
          MaterialBundle({Balance.tradeRoadFallbackMaterial: Balance.tradeRoadAmount(0)}));
    });
  });

  group('tradeRoadCaravansDue', () {
    test('one caravan from every other active neighbour, never alone', () {
      final due = tradeRoadCaravansDue(
        from: _day(1),
        to: _day(3),
        adventurerDays: {
          _ada: {_day(1), _day(2)},
          _ben: {_day(2), _day(3)},
        },
        caravanDays: {
          'cat': {_day(3)},
        },
      );
      expect(due, [
        (who: _ada, day: _day(2), neighbourId: _ben),
        (who: _ben, day: _day(2), neighbourId: _ada),
        (who: _ben, day: _day(3), neighbourId: 'cat'),
      ]);
    });
  });

  group('the engine', () {
    test('a day both neighbours were active brings each a caravan', () {
      final device = _Device('one')..run(const [], _at(1, 12));
      device.command(_ben, _at(1, 13),
          (commands) => commands.startBuilding(0, BuildingType.lumberyard));
      device.run([_buy(_ada, 2), _buy(_ben, 2)], _at(2, 19));

      final toAda = device.tradeRoads(_ada).single;
      expect(toAda.rewardId, tradeRoadRewardId(_ada, _day(2), _ben));
      expect(toAda.materials,
          MaterialBundle({MaterialKind.lumber: Balance.tradeRoadAmount(1)}));
      final toBen = device.tradeRoads(_ben).single;
      expect(toBen.materials,
          MaterialBundle({Balance.tradeRoadFallbackMaterial: Balance.tradeRoadAmount(0)}));
    });

    test('nobody alone gets a caravan', () {
      final device = _Device('one')..run([_buy(_ada, 2)], _at(2, 19));
      expect(device.tradeRoads(), isEmpty);
    });

    test('a late log from another device tops the day up, and devices agree',
        () {
      final adaPhone = _Device('ada-phone')..run([_buy(_ada, 2)], _at(2, 19));
      final benPhone = _Device('ben-phone')..run([_buy(_ben, 2)], _at(2, 19, ));
      expect(adaPhone.tradeRoads(), isEmpty);
      expect(benPhone.tradeRoads(), isEmpty);

      // They sync: each sees both logs and both game logs.
      final merged = [...adaPhone.log, ...benPhone.log];
      adaPhone.log
        ..clear()
        ..addAll(merged);
      benPhone.log
        ..clear()
        ..addAll(merged.reversed);
      adaPhone.run([_buy(_ada, 2), _buy(_ben, 2)], _at(2, 20));
      benPhone.run([_buy(_ada, 2), _buy(_ben, 2)], _at(2, 21));
      expect(adaPhone.tradeRoads(_ada), hasLength(1));
      expect(adaPhone.tradeRoads(_ben), hasLength(1));

      final everything = [...adaPhone.log, ...benPhone.log];
      final one = projectGameState(everything);
      final other = projectGameState(everything.reversed);
      expect(one, other);
      expect(one.person(_ada).unclaimedRewards.keys.where((id) => id.startsWith('trade.road:')),
          [tradeRoadRewardId(_ada, _day(2), _ben)]);
    });

    test("a Standard neighbour's active day sends the caravan bundle", () {
      final device = _Device('one', party: _adaWithStandardBen)
        ..run([_buy(_ada, 2), _buy(_ben, 2)], _at(2, 19));
      final toAda = device.tradeRoads(_ada).single;
      expect(toAda.rewardId, tradeRoadRewardId(_ada, _day(2), _ben));
      expect(toAda.materials, Balance.caravanTradeBundle);
      expect(device.tradeRoads(_ben), isEmpty, reason: 'a Standard adult has no town');
    });

    test('the trade road opens on the day the towns split', () {
      final device = _Device('one')
        ..run([_buy(_ada, 2), _buy(_ben, 2), _buy(_ada, 3), _buy(_ben, 3)], _at(3, 19));
      expect([for (final grant in device.tradeRoads()) grant.rewardId], unorderedEquals([
        tradeRoadRewardId(_ada, _day(3), _ben),
        tradeRoadRewardId(_ben, _day(3), _ada),
      ]));
    });

    test("claiming a caravan fills the claimer's own town", () {
      final device = _Device('one')..run(const [], _at(1, 12));
      device.run([_buy(_ada, 2), _buy(_ben, 2)], _at(2, 19));
      final toAda = device.tradeRoads(_ada).single;
      final before = device.state;
      device.command(_ada, _at(2, 20), (commands) => commands.claimReward(toAda.rewardId));
      final after = device.state;
      expect(after.townOf(_ada).materials, before.townOf(_ada).materials + toAda.materials);
      expect(after.townOf(_ben).materials, before.townOf(_ben).materials);
    });

    test("a neighbour's inactivity only ever leaves out shared bonuses", () {
      Set<String> adaRewards(List<Event> ledger) {
        final device = _Device('one')..run(ledger, _at(6, 19));
        return {
          for (final grant in device.log.whereType<RewardGranted>())
            if (grant.actorId == _ada) grant.rewardId,
          for (final chest in device.log.whereType<ChestGranted>())
            if (chest.actorId == _ada) chest.chestId,
        };
      }

      final alone = adaRewards([for (var day = 1; day <= 6; day++) _buy(_ada, day)]);
      final together = adaRewards([
        for (var day = 1; day <= 6; day++) _buy(_ada, day),
        for (var day = 1; day <= 6; day++) _buy(_ben, day),
      ]);
      expect(together.containsAll(alone), isTrue);
      expect(alone.any((id) => id.startsWith('trade.road:')), isFalse);
    });
  });
}
