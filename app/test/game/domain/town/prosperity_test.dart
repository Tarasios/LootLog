import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/prosperity.dart';

import '../game_fixtures.dart';
import 'growth_fixtures.dart';

void main() {
  group('townProsperity', () {
    test('counts completed building tiers, placed decorations and festivals', () {
      final state = projectGameState([
        built('b1', 0, BuildingType.centralHall, when: at(0)),
        built('b2', 1, BuildingType.lumberyard, when: at(1)),
        built('b3', 0, BuildingType.centralHall,
            when: at(2), tier: 2, completesAt: at(62)),
      ]);
      final town = state.townOf(robin);

      // The Central Hall's upgrade is still under way: tier 1 counts.
      expect(
        townProsperity(town, townDecorationsPlaced: 3, festivalsHeld: 2, at: at(10)),
        2 * Balance.prosperityPerBuildingTier +
            3 * Balance.prosperityPerDecoration +
            2 * Balance.prosperityPerFestival,
      );
      expect(
        townProsperity(town, townDecorationsPlaced: 0, festivalsHeld: 0, at: at(62)),
        3 * Balance.prosperityPerBuildingTier,
      );
    });

    test('decorations count up to the cap', () {
      final town = projectGameState(const []).townOf(robin);
      expect(
        townProsperity(town,
            townDecorationsPlaced: Balance.prosperityDecorationCap + 20,
            festivalsHeld: 0,
            at: at(0)),
        Balance.prosperityDecorationCap * Balance.prosperityPerDecoration,
      );
    });

    test('a brand-new town has none', () {
      final town = projectGameState(const []).townOf(robin);
      expect(townProsperity(town, townDecorationsPlaced: 0, festivalsHeld: 0, at: at(0)), 0);
    });
  });

  group('tiers', () {
    test('thresholds rise with every tier, starting at zero', () {
      expect(Balance.tierProsperity[TownTier.outpost], 0);
      for (final tier in TownTier.values.skip(1)) {
        expect(Balance.tierProsperity[tier]!,
            greaterThan(Balance.tierProsperity[TownTier.values[tier.index - 1]]!),
            reason: tier.name);
      }
    });

    test('tiersDue climbs one tier at a time up to the peak', () {
      final hamlet = Balance.tierProsperity[TownTier.hamlet]!;
      expect(tiersDue(current: TownTier.outpost, peak: hamlet - 1, foodSecureFrom: (_) => true),
          isEmpty);
      expect(tiersDue(current: TownTier.outpost, peak: hamlet, foodSecureFrom: (_) => true),
          [TownTier.hamlet]);
      expect(
          tiersDue(current: TownTier.hamlet, peak: 1 << 30, foodSecureFrom: (_) => true),
          [TownTier.village, TownTier.town, TownTier.city]);
      expect(tiersDue(current: TownTier.city, peak: 1 << 30, foodSecureFrom: (_) => true),
          isEmpty);
    });

    test('village and beyond wait for food; the hamlet never does', () {
      final village = Balance.tierProsperity[TownTier.village]!;
      final asked = <TownTier>[];
      final due = tiersDue(
        current: TownTier.outpost,
        peak: village,
        foodSecureFrom: (from) {
          asked.add(from);
          return false;
        },
      );
      expect(due, [TownTier.hamlet]);
      expect(asked, [TownTier.hamlet], reason: 'the need of the tier being left');
    });

    test('tier reward ids are per person and tier', () {
      expect(tierRewardId(robin, TownTier.hamlet), 'tier:$robin:hamlet');
    });

    test('every tier above the outpost has a reward and a daily gem cap', () {
      for (final tier in TownTier.values) {
        expect(Balance.dailyGemCapFor(tier), greaterThanOrEqualTo(Balance.dailyGemCap));
        if (tier == TownTier.outpost) continue;
        expect(Balance.tierRewards[tier], isNotNull, reason: tier.name);
        expect(Balance.tierRewards[tier]!.gems, greaterThan(0), reason: tier.name);
      }
      expect(Balance.dailyGemCapFor(TownTier.outpost), Balance.dailyGemCap);
      for (final tier in TownTier.values.skip(1)) {
        expect(Balance.dailyGemCapFor(tier),
            greaterThanOrEqualTo(Balance.dailyGemCapFor(TownTier.values[tier.index - 1])));
      }
    });
  });

  group('projection', () {
    test('the peak only ever rises, whatever order copies arrive in', () {
      final events = [
        prosperityReached('p1', 40, when: at(1)),
        prosperityReached('p2', 90, when: at(2)),
        prosperityReached('p3', 60, when: at(3)),
      ];
      expect(projectGameState(events).person(robin).peakProsperity, 90);
      expect(projectGameState(events.reversed).person(robin).peakProsperity, 90);
    });

    test('a reached tier stands; a lower or repeated one changes nothing', () {
      final state = projectGameState([
        tierReached('t1', TownTier.hamlet, when: onDay(1)),
        tierReached('t2', TownTier.village, when: onDay(20)),
        tierReached('t3', TownTier.hamlet, when: onDay(25), device: 'dev-2'),
      ]);
      final person = state.person(robin);
      expect(person.townTier, TownTier.village);
      expect(person.tiersReached[TownTier.hamlet], onDay(1), reason: 'the earliest stands');
      expect(person.tierOn(GameDay.fromInstant(onDay(0))), TownTier.outpost);
      expect(person.tierOn(GameDay.fromInstant(onDay(5))), TownTier.hamlet);
      expect(person.tierOn(GameDay.fromInstant(onDay(20))), TownTier.village);
      expect(state.warnings, isEmpty);
    });

    test('a person nothing has touched is an outpost with no prosperity', () {
      final person = projectGameState(const []).person(robin);
      expect(person.townTier, TownTier.outpost);
      expect(person.peakProsperity, 0);
    });
  });
}
