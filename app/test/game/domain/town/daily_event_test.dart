import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/daily_event.dart';

import '../game_fixtures.dart';

const GameDay _today = GameDay(2026, 10, 1);

HallState _hall(List<GameEvent> events) => projectGameState(events).hall;

DailyOffer _roll(String seed, HallState hall) => rollDailyOffer(
  personId: robin,
  day: _today,
  seedEventId: seed,
  hall: hall,
  now: at(60),
);

/// Offers for 300 different opening events.
List<DailyOffer> _many(HallState hall) => [
  for (var i = 0; i < 300; i++) _roll('ledger-$i', hall),
];

void main() {
  final emptyHall = _hall(const []);
  final lumberHall = _hall([
    built('b1', 0, BuildingType.lumberyard, when: at(0), tier: 2),
    collected(
      'c1',
      'plot-0',
      MaterialBundle({
        MaterialKind.lumber: 90,
        MaterialKind.stone: 40,
        MaterialKind.ore: 3,
      }),
      when: at(1),
    ),
  ]);

  test('the offer id is built from the person and the day', () {
    final offer = _roll('ledger-1', emptyHall);
    expect(offer.offerId, 'daily.event:$robin:2026-10-01');
    expect(offer.offerId, dailyEventOfferId(robin, _today));
    expect(offer.day, _today);
  });

  test('the same opening event rolls the same offer', () {
    for (var i = 0; i < 20; i++) {
      final first = _roll('ledger-$i', lumberHall);
      final second = _roll('ledger-$i', lumberHall);
      expect(second, first);
    }
  });

  test('every kind turns up, roughly by its weight', () {
    final kinds = _many(lumberHall).map((offer) => offer.kind).toList();
    for (final kind in DailyEventKind.values) {
      expect(kinds, contains(kind));
    }
    final visitors = kinds
        .where((kind) => kind == DailyEventKind.visitor)
        .length;
    // Weight 20 of 100: well under half, well over a twentieth.
    expect(visitors, inInclusiveRange(15, 120));
  });

  test('a hall with no producer never rolls a windfall', () {
    final stockedHall = _hall([
      collected(
        'c1',
        'plot-0',
        MaterialBundle({MaterialKind.stone: 60}),
        when: at(1),
      ),
    ]);
    final kinds = _many(stockedHall).map((offer) => offer.kind).toSet();
    expect(kinds, isNot(contains(DailyEventKind.windfall)));
    expect(kinds, containsAll([DailyEventKind.trader, DailyEventKind.visitor]));
  });

  test("a hall that can't pay a trader gets a visitor instead", () {
    final kinds = _many(emptyHall).map((offer) => offer.kind).toSet();
    expect(kinds, {DailyEventKind.visitor});
    final thinHall = _hall([
      built('b1', 0, BuildingType.lumberyard, when: at(0)),
      collected(
        'c1',
        'plot-0',
        MaterialBundle({MaterialKind.lumber: Balance.traderGiveAmount(0) - 1}),
        when: at(1),
      ),
    ]);
    final thinKinds = _many(thinHall).map((offer) => offer.kind).toSet();
    expect(thinKinds, {DailyEventKind.windfall, DailyEventKind.visitor});
  });

  test('a windfall is four hours of that producer at its current tier', () {
    final windfall = _many(
      lumberHall,
    ).firstWhere((offer) => offer.kind == DailyEventKind.windfall);
    final perHour = Balance
        .buildings[BuildingType.lumberyard]!
        .productionPerHour[MaterialKind.lumber]![1];
    expect(Balance.windfallHours, 4);
    expect(windfall.plotIndex, 0);
    expect(windfall.gives.isEmpty, isTrue);
    expect(
      windfall.receives,
      Loot(materials: MaterialBundle({MaterialKind.lumber: perHour * 4})),
    );
  });

  test('a producer still under its first construction has no good day', () {
    final building = _hall([
      built('b1', 0, BuildingType.quarry, when: at(0), completesAt: at(600)),
    ]);
    final kinds = _many(building).map((offer) => offer.kind).toSet();
    expect(kinds, isNot(contains(DailyEventKind.windfall)));
  });

  test(
    'a trader swaps the most plentiful material for the scarcest other one',
    () {
      final trader = _many(
        lumberHall,
      ).firstWhere((offer) => offer.kind == DailyEventKind.trader);
      expect(trader.plotIndex, isNull);
      expect(
        trader.gives,
        MaterialBundle({MaterialKind.lumber: Balance.traderGiveAmount(0)}),
      );
      final received = trader.receives.materials.amounts;
      expect(received.keys.single, isNot(MaterialKind.lumber));
      expect(lumberHall.materials[received.keys.single], 0);
      expect(received.values.single, Balance.traderReceiveAmount(0));
      expect(trader.receives.gems, 0);
    },
  );

  test(
    'a trader never swaps a material for itself, and can always be paid',
    () {
      for (final offer in _many(lumberHall)) {
        if (offer.kind != DailyEventKind.trader) continue;
        final given = offer.gives.amounts.keys.single;
        final received = offer.receives.materials.amounts.keys.single;
        expect(given, isNot(received));
        expect(lumberHall.materials.covers(offer.gives), isTrue);
      }
    },
  );

  test("a trader's amounts grow with the Central Hall", () {
    final grandHall = _hall([
      built('b1', 0, BuildingType.centralHall, when: at(0), tier: 3),
      collected(
        'c1',
        'plot-0',
        MaterialBundle({MaterialKind.stone: 120}),
        when: at(1),
      ),
    ]);
    final trader = _many(
      grandHall,
    ).firstWhere((offer) => offer.kind == DailyEventKind.trader);
    expect(
      trader.gives,
      MaterialBundle({MaterialKind.stone: Balance.traderGiveAmount(3)}),
    );
    expect(
      Balance.traderGiveAmount(3),
      greaterThan(Balance.traderGiveAmount(0)),
    );
  });

  test('a visitor brings a small bundle of one material, or two gems', () {
    final visitors = _many(
      lumberHall,
    ).where((offer) => offer.kind == DailyEventKind.visitor).toList();
    final withGems = visitors
        .where((offer) => offer.receives.gems > 0)
        .toList();
    final withMaterials = visitors
        .where((offer) => offer.receives.gems == 0)
        .toList();
    expect(withGems, isNotEmpty);
    expect(withMaterials, isNotEmpty);
    for (final offer in withGems) {
      expect(offer.receives, const Loot(gems: Balance.visitorGiftGems));
    }
    for (final offer in withMaterials) {
      expect(
        offer.receives.materials.amounts.values.single,
        Balance.visitorGift,
      );
      expect(
        Balance.visitorGiftMaterials,
        contains(offer.receives.materials.amounts.keys.single),
      );
    }
    for (final offer in visitors) {
      expect(offer.gives.isEmpty, isTrue);
    }
  });

  test('every offer names a flavour line of its own kind', () {
    for (final offer in _many(lumberHall)) {
      expect(offer.flavourKey, startsWith('${offer.kind.name}.'));
      expect(dailyEventFlavourKeys(offer.kind), contains(offer.flavourKey));
    }
  });
}
