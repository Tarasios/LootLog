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
import 'package:lootlog/game/domain/hall_rules.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';

const _ada = 'ada';
const _ben = 'ben';

/// 18:00 UTC is 10–11am in Vancouver, safely inside the local day.
DateTime _at(int day, [int hour = 18]) => DateTime.utc(2026, 10, day, hour);

PurchaseAdded _buy(String who, DateTime at, String id) => PurchaseAdded(
      eventId: id,
      deviceId: 'd-$who',
      userId: who,
      occurredAt: at,
      createdAt: at,
      purchaseId: 'p-$id',
      target: const VaultCharge(),
      amountCents: 1000,
    );

const _duo = Party([
  PartyAdult(_ada, inAdventure: true),
  PartyAdult(_ben, inAdventure: true),
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
}

void main() {
  group('the engine splits a shared town once', () {
    test('the first run writes one TownsSplit with the welcome grant', () {
      final device = _Device('one');
      final out = device.run([_buy(_ada, _at(1), 'e1')], _at(1, 19));
      final split = out.whereType<TownsSplit>().single;
      expect(split.ownerId, _ada);
      expect(split.welcome, Balance.welcomeGrant);
      expect(out.first, split, reason: 'written before anything it shapes');
      expect(device.state.townsSplit, isTrue);

      final again = device.run([_buy(_ada, _at(1), 'e1')], _at(1, 20));
      expect(again.whereType<TownsSplit>(), isEmpty);
    });

    test('the adult who built most keeps the shared town', () {
      final device = _Device('one', party: const Party([
        PartyAdult(_ada, inAdventure: true),
      ]));
      device.run(const [], _at(1));
      // A household that predates the split: replay Ben's building into a
      // fresh, unsplit log.
      final legacy = _Device('legacy');
      legacy.log.add(PlotUnlocked(
        eventId: 'l1', deviceId: 'x', actorId: _ben,
        occurredAt: _at(1), createdAt: _at(1), plotIndex: 3, gemCost: 0,
      ));
      final split = legacy.run(const [], _at(2)).whereType<TownsSplit>().single;
      expect(split.ownerId, _ben);
      expect(legacy.state.townOf(_ben).plots.containsKey(3), isTrue);
      expect(legacy.state.townOf(_ada).plots.containsKey(3), isFalse);
      expect(legacy.state.townOf(_ada).materials, Balance.welcomeGrant);
    });

    test('no split without an Adventure adult', () {
      final device = _Device('one', party: const Party([
        PartyAdult(_ada, inAdventure: false),
      ]));
      expect(device.run([_buy(_ada, _at(1), 'e1')], _at(1, 19)).whereType<TownsSplit>(),
          isEmpty);
    });

    test("two devices' splits converge on the earliest", () {
      final first = _Device('a-dev')..run(const [], _at(1));
      final second = _Device('b-dev')..run(const [], _at(1, 20));
      final merged = [...first.log, ...second.log];
      final one = projectGameState(merged);
      final other = projectGameState(merged.reversed);
      expect(one, other);
      expect(one.ownership.split?.eventId, first.log.whereType<TownsSplit>().single.eventId);
    });

    test("today's daily event rolls against the adult's own town", () {
      final device = _Device('one');
      final out = device.run([_buy(_ben, _at(1), 'e1')], _at(1, 19));
      final offer = out.whereType<DailyEventOffered>().single;
      // Ben's new town holds only the welcome grant, so a trader asks for
      // what the welcome holds (or a visitor comes): never more than he has.
      expect(Balance.welcomeGrant.covers(offer.gives), isTrue);
    });
  });

  group('commands act on the actor\'s own town', () {
    test('building in one town leaves the neighbour\'s untouched', () {
      final device = _Device('one')..run(const [], _at(1));
      final result = device.command(_ben, _at(1, 19),
          (commands) => commands.startBuilding(0, BuildingType.lumberyard));
      expect(result.accepted, isTrue, reason: '$result');
      final state = device.state;
      expect(state.townOf(_ben).plots[0]?.building?.type, BuildingType.lumberyard);
      expect(state.townOf(_ada).plots[0]?.building, isNull);
      expect(state.townOf(_ada).materials, const MaterialBundle.empty());
    });

    test('a building may stand once per town, so each neighbour may have one', () {
      final device = _Device('one')..run(const [], _at(1));
      expect(device.command(_ada, _at(1, 19),
          (commands) => commands.startBuilding(0, BuildingType.lumberyard)).accepted, isTrue);
      expect(device.command(_ben, _at(1, 19),
          (commands) => commands.startBuilding(0, BuildingType.lumberyard)).accepted, isTrue);
      expect(device.command(_ben, _at(1, 19),
          (commands) => commands.startBuilding(1, BuildingType.lumberyard)).rejection,
          GameRejection.buildingAlreadyInHall);
    });

    test("collecting follows the collector's own shift", () {
      final device = _Device('one')..run(const [], _at(1));
      device.command(_ben, _at(1, 19),
          (commands) => commands.startBuilding(0, BuildingType.lumberyard));
      // Ada logs every day; Ben never does. Ben's crews work short shifts.
      for (var day = 2; day <= 4; day++) {
        device.run([for (var d = 2; d <= day; d++) _buy(_ada, _at(d), 'ada-$d')], _at(day, 19));
      }
      final state = device.state;
      final produced = uncollectedProduction(state.townOf(_ben), 0, _at(5, 7),
          activeDays: state.townActiveDaysOf(_ben));
      final made = device.command(_ben, _at(5, 7),
          (commands) => commands.collectMaterials(0));
      final again = device.command(_ben, _at(5, 7),
          (commands) => commands.collectMaterials(0));
      expect(made.accepted, isTrue);
      expect(again.accepted, isFalse);
      final collected = made.events.whereType<MaterialsCollected>().single.amounts;
      // What fits beside the welcome grant in a town with no Storehouse.
      expect(collected[MaterialKind.lumber],
          Balance.storehouseCapacityByTier[0] - Balance.welcomeGrant[MaterialKind.lumber]);
      final rate = Balance.buildings[BuildingType.lumberyard]!
          .productionPerHour[MaterialKind.lumber]![0];
      // Oct 1 from 12:00 local: 0 h of the 8 h short shift remain; Oct 2–4:
      // 8 h each; Oct 5 until midnight local (07:00 UTC is 00:00 PDT): 0 h.
      expect(produced[MaterialKind.lumber], rate * 24);
    });
  });
}
