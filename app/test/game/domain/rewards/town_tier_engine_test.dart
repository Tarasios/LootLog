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
import 'package:lootlog/game/domain/town/prosperity.dart';

import '../town/growth_fixtures.dart';

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

const _solo = Party([PartyAdult(_ada, inAdventure: true)]);
const _duo = Party([
  PartyAdult(_ada, inAdventure: true),
  PartyAdult(_ben, inAdventure: true),
]);

class _Device {
  _Device(this.name, {this.party = _solo});

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
}

/// Festivals worth at least [prosperity] for [who].
List<GameEvent> _worth(int prosperity, {String who = _ada}) => festivals(
      (prosperity + Balance.prosperityPerFestival - 1) ~/ Balance.prosperityPerFestival,
      when: _at(1, 1),
      actor: who,
      lastWeek: GameDay.fromInstant(_at(1)).addDays(-14),
    );

int get _hamlet => Balance.tierProsperity[TownTier.hamlet]!;
int get _village => Balance.tierProsperity[TownTier.village]!;

void main() {
  group('prosperity', () {
    test('the engine stores a new peak once, and only a higher one after', () {
      final device = _Device('one')..log.addAll(_worth(30));
      final first = device.run(const [], _at(2));
      final reached = first.whereType<ProsperityReached>().single;
      final festivalsWorth = device.state.person(_ada).festivals.length *
          Balance.prosperityPerFestival;
      expect(reached.value, festivalsWorth);
      expect(device.state.person(_ada).peakProsperity, festivalsWorth);

      expect(device.run(const [], _at(2, 19)).whereType<ProsperityReached>(), isEmpty);

      device.log.addAll(townDecoration(1, when: _at(2, 20)));
      final topped = device.run(const [], _at(2, 21)).whereType<ProsperityReached>().single;
      expect(topped.value, festivalsWorth + Balance.prosperityPerDecoration);
    });

    test('storing a decoration away never lowers prosperity or the tier', () {
      final device = _Device('one')
        ..log.addAll(_worth(_hamlet - Balance.prosperityPerDecoration))
        ..log.addAll(townDecoration(1, when: _at(1, 2)));
      device.run(const [], _at(2));
      final before = device.state.person(_ada);
      expect(before.townTier, TownTier.hamlet);

      device.log.add(storedAway(1, when: _at(2, 19)));
      final after = device.run(const [], _at(2, 20));
      expect(after.whereType<ProsperityReached>(), isEmpty);
      expect(after.whereType<TierReached>(), isEmpty);
      expect(device.state.person(_ada).peakProsperity, before.peakProsperity);
      expect(device.state.person(_ada).townTier, TownTier.hamlet);
    });
  });

  group('tiers', () {
    test('reaching the hamlet writes TierReached and its reward, once', () {
      final device = _Device('one')..log.addAll(_worth(_hamlet));
      final out = device.run(const [], _at(2));
      expect(out.whereType<TierReached>().single.tier, TownTier.hamlet);
      final reward = out.whereType<RewardGranted>()
          .singleWhere((r) => r.reasonCode == GameReasonCodes.townTier);
      expect(reward.rewardId, tierRewardId(_ada, TownTier.hamlet));
      final loot = Balance.tierRewards[TownTier.hamlet]!;
      expect(reward.gems, loot.gems);
      expect(reward.materials, loot.materials);
      expect(device.state.person(_ada).townTier, TownTier.hamlet);

      final again = device.run(const [], _at(3));
      expect(again.whereType<TierReached>(), isEmpty);
      expect(again.whereType<RewardGranted>()
          .where((r) => r.reasonCode == GameReasonCodes.townTier), isEmpty);
    });

    test('two devices that each reach the tier converge on one reward', () {
      final setup = _worth(_hamlet);
      final one = _Device('one')..log.addAll(setup);
      final two = _Device('two')..log.addAll(setup);
      one.run(const [], _at(2));
      two.run(const [], _at(2, 19));

      final merged = projectGameState([...one.log, ...two.log]);
      final shuffled = projectGameState([...two.log, ...one.log].reversed);
      expect(merged, shuffled);
      final person = merged.person(_ada);
      expect(person.townTier, TownTier.hamlet);
      expect(
        person.unclaimedRewards.keys.where((id) => id.startsWith('tier:')),
        [tierRewardId(_ada, TownTier.hamlet)],
      );

      final settled = _Device('three')..log.addAll([...one.log, ...two.log]);
      final rerun = settled.run(const [], _at(3));
      expect(rerun.whereType<TierReached>(), isEmpty);
      expect(rerun.whereType<ProsperityReached>(), isEmpty);
    });

    test('a device that saw less tops up rather than locking in its value', () {
      final one = _Device('one')..log.addAll(_worth(30));
      one.run(const [], _at(2));
      final two = _Device('two')
        ..log.addAll(_worth(30))
        ..log.addAll(one.log.whereType<ProsperityReached>())
        ..log.addAll(townDecoration(1, when: _at(2, 1)));
      final topUp = two.run(const [], _at(2, 2)).whereType<ProsperityReached>().single;
      final merged = projectGameState({...one.log, ...two.log});
      expect(merged.person(_ada).peakProsperity, topUp.value);
      expect(topUp.value, greaterThan(one.log.whereType<ProsperityReached>().single.value));
    });

    test('the village waits for food: nothing else changes', () {
      final device = _Device('one')..log.addAll(_worth(_village));
      device.run(const [], _at(2));
      final person = device.state.person(_ada);
      expect(person.peakProsperity, greaterThanOrEqualTo(_village));
      expect(person.townTier, TownTier.hamlet);
      expect(device.state.townOf(_ada).materials[MaterialKind.lumber], 0,
          reason: 'nothing is taken from a town that waits');
    });

    test('a quiet neighbour neither holds back nor lowers anyone\'s tier', () {
      final device = _Device('one', party: _duo)..log.addAll(_worth(_hamlet));
      final out = device.run(const [], _at(2));
      expect(out.whereType<TierReached>().map((t) => t.actorId), [_ada]);
      expect(device.state.person(_ben).townTier, TownTier.outpost);
    });
  });

  test('the daily gem cap rises with the tier', () {
    final device = _Device('one')..log.addAll(_worth(_hamlet));
    device.run(const [], _at(2));
    final buys = [for (var i = 0; i < 12; i++) _buy(_ada, _at(3, 17).add(Duration(minutes: i)), 'b$i')];
    final out = device.run(buys, _at(3, 19));
    final capped = out.whereType<RewardGranted>().where((r) =>
        r.reasonCode == GameReasonCodes.extraLog || r.reasonCode == GameReasonCodes.timely);
    expect(capped, hasLength(Balance.dailyGemCapFor(TownTier.hamlet)));
  });
}
