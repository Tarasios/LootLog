import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/food.dart';

import '../town/growth_fixtures.dart';

const _ada = 'ada';

/// 18:00 UTC is 10–11am in Vancouver, safely inside the local day.
DateTime _at(int day, [int hour = 18]) => DateTime.utc(2026, 10, day, hour);
GameDay _day(int day) => GameDay.fromInstant(_at(day));

const _solo = Party([PartyAdult(_ada, inAdventure: true)]);

class _Device {
  _Device(this.name);

  final String name;
  final List<GameEvent> log = [];
  int _ids = 0;

  GameState get state => projectGameState(log);

  GameEventStamp get stamp => GameEventStamp(
        deviceId: name,
        newEventId: () => '$name-${(_ids++).toString().padLeft(5, '0')}',
      );

  List<GameEvent> run(DateTime now) {
    final out = const RewardEngine(monthEnd: NoMonthEndRewards())
        .evaluate(const <Event>[], state, FixedClock(now), party: _solo, stamp: stamp);
    log.addAll(out);
    return out;
  }
}

/// Ada at the hamlet with farmland and a farm, and [food] harvested on day 1.
List<GameEvent> _farmTown({int food = 100, int prosperity = 0}) => [
      tierReached('t-hamlet', TownTier.hamlet, when: _at(1, 9), actor: _ada),
      districtPurchased('t-land', kFarmlandDistrictId, when: _at(1, 10), actor: _ada),
      farmBuilt('t-farm', 0, FarmBuildingType.farm, when: _at(1, 11), actor: _ada),
      foodHarvested('t-food', 0, food, when: _at(1, 12), actor: _ada),
      if (prosperity > 0) prosperityReached('t-peak', prosperity, when: _at(1, 13), actor: _ada),
    ];

int get _need => dailyFoodNeed(TownTier.hamlet);
int get _cap => Balance.granaryFoodCapacityByTier[0];

void main() {
  test('each day since the first harvest is eaten once, at the day boundary', () {
    final device = _Device('one')..log.addAll(_farmTown());
    final out = device.run(_at(4));
    expect(out.whereType<FoodConsumed>().map((c) => c.day), [_day(1), _day(2), _day(3)]);
    expect(out.whereType<FoodConsumed>().map((c) => c.amount).toSet(), {_need});
    expect(device.state.townOf(_ada).food.stored, 100 - 3 * _need);

    expect(device.run(_at(4, 20)).whereType<FoodConsumed>(), isEmpty);
    expect(device.run(_at(5)).whereType<FoodConsumed>().map((c) => c.day), [_day(4)]);
  });

  test('two devices eating the same days converge on eating them once', () {
    final one = _Device('one')..log.addAll(_farmTown());
    final two = _Device('two')..log.addAll(_farmTown());
    one.run(_at(4));
    two.run(_at(4, 19));
    final merged = projectGameState([...one.log, ...two.log]);
    expect(merged, projectGameState([...two.log, ...one.log].reversed));
    expect(merged.townOf(_ada).food.stored, 100 - 3 * _need);
  });

  test('a day eaten at the old tier tops up once the new tier syncs in', () {
    final early = _Device('one')..log.addAll(_farmTown(food: _cap));
    early.run(_at(3));
    final villageNeed = dailyFoodNeed(TownTier.village);
    // Another device had seen the village reached on day 2.
    final later = _Device('two')
      ..log.addAll(early.log)
      ..log.add(tierReached('t-village', TownTier.village, when: _at(2, 9), actor: _ada));
    final topUp = later.run(_at(3, 19)).whereType<FoodConsumed>().toList();
    expect(topUp.map((c) => (c.day, c.amount)), [(_day(2), villageNeed)]);
    expect(later.state.townOf(_ada).food.stored, _cap - _need - villageNeed);
  });

  test('the village waits for food, and comes once the stores hold enough', () {
    final village = Balance.tierProsperity[TownTier.village]!;
    final hamletSecure = _need * Balance.foodSecureDays;
    final villageSecure = dailyFoodNeed(TownTier.village) * Balance.foodSecureDays;
    final hungry = _Device('one')..log.addAll(_farmTown(food: 0, prosperity: village));
    final waited = hungry.run(_at(2));
    expect(waited.whereType<TierReached>(), isEmpty);
    expect(hungry.state.person(_ada).townTier, TownTier.hamlet);
    expect(hungry.state.townOf(_ada).districts.owns(kFarmlandDistrictId), isTrue,
        reason: 'a hungry town keeps everything');

    // A hamlet's worth of food is not a village's.
    hungry.log.add(foodHarvested('fed', 0, hamletSecure, when: _at(2, 19), actor: _ada));
    expect(hungry.run(_at(2, 20)).whereType<TierReached>(), isEmpty);

    // A village's stock needs a granary to hold it.
    expect(villageSecure, greaterThan(_cap), reason: 'a granary is worthwhile');
    hungry.log
      ..add(farmBuilt('granary', 1, FarmBuildingType.granary, when: _at(2, 20), actor: _ada))
      ..add(foodHarvested('fed-more', 0, villageSecure, when: _at(2, 21), actor: _ada));
    final grown = hungry.run(_at(2, 22));
    expect(grown.whereType<TierReached>().single.tier, TownTier.village);
  });

  test('no farm, no harvest: nothing is eaten and no event is written', () {
    final device = _Device('one')
      ..log.add(tierReached('t-hamlet', TownTier.hamlet, when: _at(1, 9), actor: _ada));
    expect(device.run(_at(5)).whereType<FoodConsumed>(), isEmpty);
  });
}
