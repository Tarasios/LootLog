import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/food.dart';
import 'package:lootlog/game/domain/town/town_book.dart';

import '../game_fixtures.dart';
import 'growth_fixtures.dart';

void main() {
  test('a new town: an outpost, the hamlet next, the farmland locked until then', () {
    final book = townBook(projectGameState(const []), robin, at(0));
    expect(book.tier, TownTier.outpost);
    expect(book.prosperity, 0);
    expect(book.nextTier, TownTier.hamlet);
    expect(book.nextTierProsperity, Balance.tierProsperity[TownTier.hamlet]);
    expect(book.waitingOnFood, isFalse);
    final farmland = book.districts.singleWhere((d) => d.spec.id == kFarmlandDistrictId);
    expect(farmland.owned, isFalse);
    expect(farmland.forSale, isFalse);
    expect(book.districts.singleWhere((d) => d.spec.id == kOutpostDistrictId).owned, isTrue);
    expect(book.districts.map((d) => d.spec.id), [for (final d in kDistricts) d.id]);
  });

  test('a hamlet at the village threshold with no food says what it needs', () {
    final village = Balance.tierProsperity[TownTier.village]!;
    final book = townBook(
      projectGameState([
        ...hamletWith(),
        prosperityReached('p', village, when: at(1)),
      ]),
      robin,
      at(2),
    );
    expect(book.tier, TownTier.hamlet);
    expect(book.nextTier, TownTier.village);
    expect(book.nextTierNeedsFood, isTrue);
    expect(book.foodSecure, isFalse);
    expect(book.waitingOnFood, isTrue);
    expect(book.foodSecureTarget, Balance.foodSecureDays * dailyFoodNeed(TownTier.hamlet));
    expect(book.population, populationOf(TownTier.hamlet));
    expect(book.foodCapacity, Balance.granaryFoodCapacityByTier[0]);
    expect(book.districts.singleWhere((d) => d.spec.id == kFarmlandDistrictId).forSale, isTrue);
  });

  test('a city has no next tier', () {
    final book = townBook(
      projectGameState([tierReached('c', TownTier.city, when: at(0))]),
      robin,
      at(1),
    );
    expect(book.nextTier, isNull);
    expect(book.nextTierProsperity, isNull);
    expect(book.waitingOnFood, isFalse);
  });
}
