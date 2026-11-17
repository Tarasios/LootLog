import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';
import 'package:lootlog/game/domain/town/daily_event.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/food.dart';
import 'package:lootlog/game/domain/town/market.dart';
import 'package:lootlog/game/domain/town/residents.dart';

import '../game_fixtures.dart';
import '../town/growth_fixtures.dart';

const _solo = Party([PartyAdult(robin, inAdventure: true)]);

/// 18:00 UTC is 10–11am in Vancouver, safely inside the local day.
DateTime _oct(int day, [int hour = 18]) => DateTime.utc(2026, 10, day, hour);

class _Device {
  _Device(this.name, [List<GameEvent> setup = const []]) {
    log.addAll(setup);
  }

  final String name;
  final List<GameEvent> log = [];
  int _ids = 0;
  int _ledgerIds = 0;

  GameState get state => projectGameState(log);

  List<GameEvent> run(List<Event> ledger, DateTime now) {
    final out = const RewardEngine(monthEnd: NoMonthEndRewards()).evaluate(
      ledger,
      state,
      FixedClock(now),
      party: _solo,
      stamp: GameEventStamp(
        deviceId: name,
        newEventId: () => '$name-${(_ids++).toString().padLeft(5, '0')}',
      ),
    );
    log.addAll(out);
    return out;
  }

  PurchaseAdded buy(DateTime at) => PurchaseAdded(
        eventId: 'l-$name-${_ledgerIds++}',
        deviceId: 'phone',
        userId: robin,
        occurredAt: at,
        createdAt: at,
        purchaseId: 'p-$name-$_ledgerIds',
        target: const VaultCharge(),
        amountCents: 1000,
      );
}

final MaterialBundle _stores = MaterialBundle({
  for (final kind in MaterialKind.values) kind: 1000,
});

void main() {
  group('the town gate needs housing', () {
    /// A village with the prosperity and the food of a town, and [cottages]
    /// tier-3 cottages.
    List<GameEvent> village({required int cottages}) {
      final perCottage = Balance.civicBuildings[CivicBuildingType.cottage]!.housingByTier[2];
      final housing = cottages * perCottage;
      final food = Balance.foodSecureDays * dailyFoodNeed(TownTier.town, housing: housing);
      return [
        ...tierWith(TownTier.village),
        ...festivals(
          Balance.tierProsperity[TownTier.town]! ~/ Balance.prosperityPerFestival + 1,
          when: _oct(1, 1),
          lastWeek: GameDay.fromInstant(_oct(1)).addDays(-14),
        ),
        districtPurchased('farmland', kFarmlandDistrictId, when: _oct(1, 2)),
        districtPurchased('homes', kResidentialDistrictId, when: _oct(1, 2)),
        farmBuilt('farm', 0, FarmBuildingType.farm, when: _oct(1, 3)),
        for (var tier = 1; tier <= 5; tier++)
          farmBuilt('granary-$tier', 1, FarmBuildingType.granary, when: _oct(1, 3), tier: tier),
        foodHarvested('harvest', 0, food, when: _oct(2, 1)),
        for (var plot = 0; plot < cottages; plot++)
          for (var tier = 1; tier <= 3; tier++)
            civicBuilt('cottage-$plot-$tier', kResidentialDistrictId, plot, CivicBuildingType.cottage,
                when: _oct(1, 4), tier: tier),
      ];
    }

    int cottagesFor(TownTier tier) {
      final perCottage = Balance.civicBuildings[CivicBuildingType.cottage]!.housingByTier[2];
      return (housingNeededFor(tier) + perCottage - 1) ~/ perCottage;
    }

    test('a village short of houses waits, however prosperous and well fed', () {
      final device = _Device('one', village(cottages: cottagesFor(TownTier.town) - 1));
      final out = device.run(const [], _oct(2, 2));
      expect(out.whereType<TierReached>(), isEmpty);
      expect(device.state.person(robin).townTier, TownTier.village);
    });

    test('with the houses it grows into a town', () {
      final device = _Device('one', village(cottages: cottagesFor(TownTier.town)));
      final out = device.run(const [], _oct(2, 2));
      expect(out.whereType<TierReached>().single.tier, TownTier.town);
    });
  });

  group('the park lifts the weekend festival', () {
    /// Robin, owning the park since [parkOn], logs [weekdays] weekdays of
    /// the week of October 5.
    FestivalTier festivalFor({required DateTime parkOn, required int weekdays}) {
      final device = _Device('one', [
        ...tierWith(TownTier.town),
        districtPurchased('park', kParkDistrictId, when: parkOn),
      ]);
      device.run([for (var day = 5; day < 5 + weekdays; day++) device.buy(_oct(day))], _oct(9));
      device.run(const [], _oct(12, 20));
      return device.state.person(robin).festivals[const GameDay(2026, 10, 5)]!;
    }

    test('one tier up for a week that ended with the park', () {
      expect(festivalFor(parkOn: _oct(1), weekdays: 3), FestivalTier.grandFestival);
      expect(festivalFor(parkOn: _oct(1), weekdays: 1), FestivalTier.fair);
      expect(festivalFor(parkOn: _oct(8), weekdays: 1), FestivalTier.fair);
    });

    test('a grand festival stays grand', () {
      expect(festivalFor(parkOn: _oct(1), weekdays: 5), FestivalTier.grandFestival);
    });

    test('a week that ended before the park was bought is as it was', () {
      expect(festivalFor(parkOn: _oct(12, 19), weekdays: 3), FestivalTier.fair);
    });
  });

  group('the market trade', () {
    List<GameEvent> withStall({DateTime? stallDone}) => [
          ...tierWith(TownTier.town, materials: _stores),
          districtPurchased('market', kMarketRowDistrictId, when: _oct(1)),
          civicBuilt('stall', kMarketRowDistrictId, 0, CivicBuildingType.stall,
              when: _oct(1), completesAt: stallDone ?? _oct(1)),
        ];

    test('a logged day brings one extra trader offer, once', () {
      final device = _Device('one', withStall());
      final day = GameDay.fromInstant(_oct(5));
      final out = device.run([device.buy(_oct(5))], _oct(5, 19));
      final offers = out.whereType<DailyEventOffered>().toList();
      expect(offers.map((o) => o.offerId).toSet(),
          {dailyEventOfferId(robin, day), marketOfferId(robin, day)});
      final market = offers.singleWhere((o) => o.offerId == marketOfferId(robin, day));
      expect(market.kind, DailyEventKind.trader);
      expect(market.gives.isEmpty, isFalse);
      expect(market.receives.materials.isEmpty, isFalse);

      final again = device.run([device.buy(_oct(5, 20))], _oct(5, 21));
      expect(again.whereType<DailyEventOffered>(), isEmpty);
      expect(device.state.person(robin).dailyOffers, hasLength(2));
    });

    test('two devices offer the same market trade and the town shows it once', () {
      final one = _Device('one', withStall());
      final two = _Device('two', withStall());
      final purchase = one.buy(_oct(5));
      final fromOne = one.run([purchase], _oct(5, 19)).whereType<DailyEventOffered>();
      final fromTwo = two.run([purchase], _oct(5, 20)).whereType<DailyEventOffered>();
      final day = GameDay.fromInstant(_oct(5));
      DailyEventOffered market(Iterable<DailyEventOffered> offers) =>
          offers.singleWhere((o) => o.offerId == marketOfferId(robin, day));
      expect(market(fromTwo).gives, market(fromOne).gives);
      expect(market(fromTwo).receives, market(fromOne).receives);
      final merged = projectGameState([...one.log, ...two.log]);
      expect(merged.person(robin).dailyOffers, hasLength(2));
    });

    test('no stall in service, no market trade', () {
      final building = _Device('one', withStall(stallDone: _oct(30)));
      final out = building.run([building.buy(_oct(5))], _oct(5, 19));
      expect(out.whereType<DailyEventOffered>().single.offerId,
          dailyEventOfferId(robin, GameDay.fromInstant(_oct(5))));
    });

    test('today\'s daily event is still the one offerFor shows', () {
      final device = _Device('one', withStall());
      final day = GameDay.fromInstant(_oct(5));
      device.run([device.buy(_oct(5))], _oct(5, 19));
      expect(device.state.offerFor(robin, day)!.offerId, dailyEventOfferId(robin, day));
      expect(device.state.marketOfferFor(robin, day)!.offerId, marketOfferId(robin, day));
    });
  });
}
