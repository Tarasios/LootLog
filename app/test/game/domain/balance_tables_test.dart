import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/content.dart';
import 'package:lootlog/game/domain/game_values.dart';

/// Coherence checks over the content tables: every closed set is covered,
/// every per-tier list is the right length, and nothing costs more than the
/// Storehouse can hold at the point the hall can afford it.
void main() {
  test('every chest type has contents; none carries materials', () {
    for (final t in ChestType.values) {
      final spec = Balance.chests[t]!;
      expect(spec.minGems, lessThanOrEqualTo(spec.maxGems));
      expect(spec.tokenChancePermille, inInclusiveRange(0, 1000));
    }
  });

  test('plots: one per building type, a gem price for each lockable one', () {
    expect(Balance.maxPlots, BuildingType.values.length);
    expect(Balance.plotUnlockGems,
        hasLength(Balance.maxPlots - Balance.startingPlotCount));
    expect(Balance.plotUnlockCost(0), isNull);
    expect(Balance.plotUnlockCost(Balance.startingPlotCount),
        Balance.plotUnlockGems.first);
    expect(Balance.plotUnlockCost(Balance.maxPlots), isNull);
  });

  test('building tier tables cover every tier', () {
    expect(Balance.buildTimeByTier, hasLength(Balance.maxBuildingTier));
    expect(Balance.buildTimeByTier.first, Duration.zero);
    expect(Balance.buildTimeByTier[1], const Duration(hours: 1));
    expect(Balance.buildTimeByTier[2], const Duration(hours: 4));
    expect(Balance.buildTimeByTier[3], const Duration(hours: 12));
    expect(Balance.buildTimeByTier[4], const Duration(hours: 12));
    expect(Balance.buildingCostMultiplierByTier,
        hasLength(Balance.maxBuildingTier));
    expect(Balance.buildingGemCostByTier, hasLength(Balance.maxBuildingTier));
    expect(Balance.storehouseCapacityByTier,
        hasLength(Balance.maxBuildingTier + 1));
    for (final type in BuildingType.values) {
      final spec = Balance.buildings[type]!;
      for (final rates in spec.productionPerHour.values) {
        expect(rates, hasLength(Balance.maxBuildingTier), reason: '$type');
      }
    }
  });

  test('the bootstrap buildings are free at tier 1; the rest are not', () {
    expect(Balance.buildingCost(BuildingType.lumberyard, 1), Loot.none);
    expect(Balance.buildingCost(BuildingType.quarry, 1), Loot.none);
    expect(Balance.buildingCost(BuildingType.centralHall, 1), Loot.none);
    expect(Balance.buildingCost(BuildingType.scribesDesk, 1), Loot.none);
    expect(Balance.buildingCost(BuildingType.mine, 1).materials.isEmpty,
        isFalse);
    expect(Balance.buildingCost(BuildingType.lumberyard, 2).materials.isEmpty,
        isFalse);
  });

  test('gems are only asked at the higher tiers', () {
    for (final type in BuildingType.values) {
      expect(Balance.buildingCost(type, 1).gems, 0);
      expect(Balance.buildingCost(type, 2).gems, 0);
      expect(Balance.buildingCost(type, 5).gems, greaterThan(0));
    }
  });

  test('every tier fits in the storehouse the hall can have by then', () {
    // Upgrading anything to tier t needs a Central Hall at t (or t - 1 for
    // the Central Hall itself), and the Storehouse is gated the same way, so
    // the Storehouse can be at tier t - 1 when the cost is due.
    for (final type in BuildingType.values) {
      for (var t = 1; t <= Balance.maxBuildingTier; t++) {
        final cap = Balance.storehouseCapacityByTier[t - 1];
        for (final e in Balance.buildingCost(type, t).materials.amounts.entries) {
          expect(e.value, lessThanOrEqualTo(cap),
              reason: '$type tier $t ${e.key.name}');
        }
      }
    }
    for (final slot in Balance.gearSlots.keys) {
      for (var t = 1; t <= Balance.maxGearTier; t++) {
        final cap = Balance.storehouseCapacityByTier[t - 1];
        for (final e in Balance.gearCost(slot, t).materials.amounts.entries) {
          expect(e.value, lessThanOrEqualTo(cap), reason: '$slot tier $t');
        }
      }
    }
  });

  test('gear tables cover every tier and slot', () {
    expect(Balance.gearCostMultiplierByTier, hasLength(Balance.maxGearTier));
    expect(Balance.gearGemCostByTier, hasLength(Balance.maxGearTier));
    expect(Balance.gearSlots.keys, containsAll(['weapon', 'armor', 'trinket']));
    for (final s in Balance.gearSlots.values) {
      expect(s.gearTypes, isNotEmpty);
    }
  });

  test('every region has a sane loot table; two are open from the start', () {
    for (final r in ExpeditionRegion.values) {
      final spec = Balance.regions[r]!;
      expect(spec.durationMinutes, greaterThan(0));
      expect(spec.loot, isNotEmpty);
      for (final line in spec.loot) {
        expect(line.min, lessThanOrEqualTo(line.max));
        expect(line.kind, isNot(MaterialKind.trophy));
      }
    }
    expect(
        ExpeditionRegion.values
            .where((r) => Balance.regions[r]!.minHallTier == 0),
        hasLength(2));
  });

  test('a boss for every season; HP climbs through the season', () {
    for (final s in Season.values) {
      expect(Balance.bosses[s]!.baseHp, greaterThan(0));
    }
    expect(seasonOf(const Month(2026, 12)), Season.winter);
    expect(seasonOf(const Month(2027, 2)), Season.winter);
    expect(seasonOf(const Month(2026, 3)), Season.spring);
    expect(seasonOf(const Month(2026, 8)), Season.summer);
    expect(seasonOf(const Month(2026, 11)), Season.autumn);
    expect(monthInSeason(const Month(2026, 12)), 0);
    expect(monthInSeason(const Month(2027, 2)), 2);
    expect(monthInSeason(const Month(2026, 10)), 1);
  });

  test('vault milestones are percentages and month counts, never amounts', () {
    expect(Balance.questMilestoneGems.keys, everyElement(inInclusiveRange(1, 100)));
    expect(Balance.questMilestoneGems.keys, contains(100));
    expect(Balance.savingsStreakGems.keys, everyElement(greaterThan(1)));
  });
}
