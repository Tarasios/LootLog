import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/reason_codes.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/food.dart';

import '../game_fixtures.dart';
import 'growth_fixtures.dart';

int _farmRate(int tier) => Balance.farmBuildings[FarmBuildingType.farm]!.foodPerHour[tier - 1];

void main() {
  var ids = 0;
  GameCommands commandsFor(GameState state, DateTime now) => GameCommands(
        state: state,
        clock: FixedClock(now),
        actorId: robin,
        stamp: GameEventStamp(deviceId: 'dev-1', newEventId: () => 'cmd-${ids++}'),
      );

  /// Robin's farmland with a farm on plot 0, finished at [kBase], on a day
  /// Robin logged (so the crews work the whole day).
  List<GameEvent> withFarm() => [
        granted('a-log', when: at(-5), rewardId: 'a-log', reasonCode: GameReasonCodes.dailyLog),
        districtPurchased('a-farmland', kFarmlandDistrictId, when: at(0)),
        farmBuilt('b-farm', 0, FarmBuildingType.farm, when: at(0)),
      ];

  group('needs', () {
    test('population and the food each resident eats steepen with the tier', () {
      for (final tier in TownTier.values.skip(1)) {
        final previous = TownTier.values[tier.index - 1];
        expect(populationOf(tier), greaterThan(populationOf(previous)), reason: tier.name);
        expect(Balance.foodPerResident[tier]!,
            greaterThanOrEqualTo(Balance.foodPerResident[previous]!), reason: tier.name);
        expect(dailyFoodNeed(tier), populationOf(tier) * Balance.foodPerResident[tier]!);
      }
    });

    test('a town is food-secure with enough days of need in store', () {
      final need = dailyFoodNeed(TownTier.hamlet) * Balance.foodSecureDays;
      final short = projectGameState([...withFarm(), foodHarvested('h1', 0, need - 1, when: at(1))]);
      final enough = projectGameState([...withFarm(), foodHarvested('h1', 0, need, when: at(1))]);
      expect(foodSecure(short.townOf(robin), TownTier.hamlet), isFalse);
      expect(foodSecure(enough.townOf(robin), TownTier.hamlet), isTrue);
    });
  });

  group('farms', () {
    test('produce food by the hour under the working shift', () {
      final state = projectGameState(withFarm());
      final town = state.townOf(robin);
      const farm = PlotAddress(kFarmlandDistrictId, 0);
      final day = GameDay.fromInstant(kBase);
      final dayEnd = kBase.add(const Duration(hours: 24));
      expect(uncollectedFood(town, farm, kBase.add(const Duration(hours: 3)), activeDays: {day}),
          3 * _farmRate(1));
      // A quiet day: only the short shift's hours count.
      final full = uncollectedFood(town, farm, dayEnd, activeDays: {day, day.next()});
      final quiet = uncollectedFood(town, farm, dayEnd, activeDays: const {});
      expect(quiet, lessThan(full));
      expect(quiet, lessThanOrEqualTo(Balance.shortShiftHours * _farmRate(1)));
    });

    test('harvesting banks food, up to the granary', () {
      final now = kBase.add(const Duration(hours: 10));
      final state = projectGameState(withFarm());
      final result = commandsFor(state, now).harvestFood(0);
      expect(result.accepted, isTrue, reason: '$result');
      final harvest = result.events.whereType<FoodHarvested>().single;
      expect(harvest.amount, greaterThan(0));
      final after = state.apply(harvest);
      expect(after.townOf(robin).food.stored, harvest.amount);
      expect(commandsFor(after, now).harvestFood(0).rejection, GameRejection.nothingToCollect);
    });

    test('a full granary refuses more; a granary raises the cap', () {
      final cap = Balance.granaryFoodCapacityByTier[0];
      final full = projectGameState([...withFarm(), foodHarvested('h1', 0, cap, when: at(1))]);
      expect(full.townOf(robin).food.stored, cap);
      expect(commandsFor(full, at(600)).harvestFood(0).rejection, GameRejection.granaryFull);

      final over = projectGameState([...withFarm(), foodHarvested('h1', 0, cap + 50, when: at(1))]);
      expect(over.townOf(robin).food.stored, cap);
      expect(over.warnings.map((w) => w.code), [GameWarningCode.foodCapped]);

      final withGranary = projectGameState([
        ...withFarm(),
        farmBuilt('c-granary', 1, FarmBuildingType.granary, when: at(0)),
      ]);
      expect(foodCapacityAt(withGranary.townOf(robin), at(1)), Balance.granaryFoodCapacityByTier[1]);
    });

    test('only farms and orchards are harvested', () {
      final state = projectGameState([
        ...withFarm(),
        farmBuilt('c-granary', 1, FarmBuildingType.granary, when: at(0)),
      ]);
      expect(commandsFor(state, at(600)).harvestFood(1).rejection, GameRejection.notAProducer);
      expect(commandsFor(state, at(600)).harvestFood(2).rejection, GameRejection.noBuilding);
    });

    test('an upgrade banks what the farm made first', () {
      final state = projectGameState([
        ...hamletWith(lumber: 150, stone: 150),
        built('ch1', 0, BuildingType.centralHall, when: at(0)),
        built('ch2', 0, BuildingType.centralHall, when: at(0), tier: 2),
        ...withFarm(),
      ]);
      final result = commandsFor(state, at(300)).startFarmBuilding(0, FarmBuildingType.farm);
      expect(result.accepted, isTrue, reason: '$result');
      expect(result.events.first, isA<FoodHarvested>());
      expect(result.events.last, isA<DistrictBuildingStarted>());
    });
  });

  group('eating', () {
    final day = GameDay.fromInstant(kBase);

    test('a day is eaten once, however many copies arrive', () {
      final state = projectGameState([
        ...withFarm(),
        foodHarvested('h1', 0, 100, when: at(1)),
        foodConsumed('c1', day, 10, when: onDay(1)),
        foodConsumed('c2', day, 10, when: onDay(1), device: 'dev-2'),
      ]);
      expect(state.townOf(robin).food.stored, 90);
    });

    test('a larger copy for the same day tops up the difference only', () {
      final state = projectGameState([
        ...withFarm(),
        foodHarvested('h1', 0, 100, when: at(1)),
        foodConsumed('c1', day, 10, when: onDay(1)),
        foodConsumed('c2', day, 25, when: onDay(1), device: 'dev-2'),
        foodConsumed('c3', day, 15, when: onDay(1), device: 'dev-3'),
      ]);
      expect(state.townOf(robin).food.stored, 75);
    });

    test('a hungry town loses nothing: food stops at zero and all else stands', () {
      final before = projectGameState([
        ...hamletWith(gems: 7, lumber: 30, stone: 30),
        ...withFarm(),
        foodHarvested('h1', 0, 5, when: at(1)),
      ]);
      final after = projectGameState([
        ...hamletWith(gems: 7, lumber: 30, stone: 30),
        ...withFarm(),
        foodHarvested('h1', 0, 5, when: at(1)),
        foodConsumed('c1', day, 50, when: onDay(1)),
        foodConsumed('c2', day.next(), 50, when: onDay(2)),
      ]);
      final town = after.townOf(robin);
      expect(town.food.stored, 0);
      expect(town.materials, before.townOf(robin).materials);
      expect(town.plots, before.townOf(robin).plots);
      expect(town.districts, before.townOf(robin).districts);
      expect(after.person(robin).gems, 7);
      expect(after.person(robin).townTier, TownTier.hamlet);
      expect(after.warnings, isEmpty, reason: 'going hungry is not an error');
    });

    test('a hungry day is never charged again when food arrives later', () {
      final state = projectGameState([
        ...withFarm(),
        foodConsumed('c1', day, 50, when: onDay(1)),
        foodHarvested('h1', 0, 40, when: onDay(1).add(const Duration(minutes: 1))),
        foodConsumed('c2', day, 50, when: onDay(2), device: 'dev-2'),
      ]);
      expect(state.townOf(robin).food.stored, 40);
    });

    test('the days due run from the first harvest to yesterday', () {
      final state = projectGameState([
        ...hamletWith(),
        ...withFarm(),
        foodHarvested('h1', 0, 100, when: onDay(1)),
        foodConsumed('c1', day.addDays(1), dailyFoodNeed(TownTier.hamlet), when: onDay(2)),
      ]);
      final due = foodConsumptionDue(
        food: state.townOf(robin).food,
        tierOn: state.person(robin).tierOn,
        oldest: day.addDays(-7),
        today: day.addDays(4),
      );
      expect(due.map((d) => d.day), [day.addDays(2), day.addDays(3)]);
      expect(due.map((d) => d.amount).toSet(), {dailyFoodNeed(TownTier.hamlet)});
    });
  });
}
