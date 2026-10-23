/// Display names and one-line descriptions for the guild hall's closed sets
/// (buildings, materials, regions, chests, gear, ritual steps), plus small
/// formatting helpers for loot and durations. Labels only — game-voice
/// narrative lives in `assets/game/text/hall_lines.json`.
library;

import '../config/balance.dart';
import '../config/narration.dart';
import '../domain/game_values.dart';

abstract final class HallNames {
  static String building(BuildingType t) => switch (t) {
        BuildingType.centralHall => 'Central Hall',
        BuildingType.scribesDesk => "Scribe's Desk",
        BuildingType.storehouse => 'Storehouse',
        BuildingType.forge => 'Forge',
        BuildingType.vault => 'Vault',
        BuildingType.lumberyard => 'Lumberyard',
        BuildingType.quarry => 'Quarry',
        BuildingType.mine => 'Mine',
        BuildingType.herbGarden => 'Herb Garden',
        BuildingType.huntersLodge => "Hunter's Lodge",
        BuildingType.arcaneWell => 'Arcane Well',
      };

  static String buildingBlurb(BuildingType t) => switch (t) {
        BuildingType.centralHall =>
          'The heart of the guild. Its tier sets how high every other '
              'building can go and which regions open.',
        BuildingType.scribesDesk =>
          'Where the ledger lives. Log purchases and tend your budgets here.',
        BuildingType.storehouse =>
          'Holds the party\'s materials. Each tier makes room for more.',
        BuildingType.forge =>
          'Crafts hero gear. Gear can never outrank the Forge.',
        BuildingType.vault =>
          'Celebrates savings milestones: how far each goal has come and '
              'how many months in a row you saved.',
        BuildingType.lumberyard => 'Produces lumber over time.',
        BuildingType.quarry => 'Produces stone over time.',
        BuildingType.mine => 'Produces ore over time.',
        BuildingType.herbGarden => 'Grows herbs over time.',
        BuildingType.huntersLodge => 'Brings in hide over time.',
        BuildingType.arcaneWell => 'Draws up crystal and essence over time.',
      };

  static String material(MaterialKind m) => switch (m) {
        MaterialKind.lumber => 'lumber',
        MaterialKind.stone => 'stone',
        MaterialKind.ore => 'ore',
        MaterialKind.herbs => 'herbs',
        MaterialKind.hide => 'hide',
        MaterialKind.crystal => 'crystal',
        MaterialKind.essence => 'essence',
        MaterialKind.trophy => 'trophies',
      };

  /// "Market Catacombs" (no leading article, title case).
  static String region(ExpeditionRegion r) {
    final n = Narration.regionNames[r] ?? r.name;
    final bare = n.startsWith('the ') ? n.substring(4) : n;
    return bare.isEmpty ? bare : bare[0].toUpperCase() + bare.substring(1);
  }

  /// The region's name as it reads mid-sentence ("the Market Catacombs").
  static String regionInSentence(ExpeditionRegion r) =>
      Narration.regionNames[r] ?? r.name;

  static String regionBlurb(ExpeditionRegion r) => switch (r) {
        ExpeditionRegion.marketCatacombs =>
          'Twisting aisles under the grocer\'s stalls.',
        ExpeditionRegion.tavernCellars => 'Barrels, bottles and lost recipes.',
        ExpeditionRegion.oldRoads => 'The long way between towns.',
        ExpeditionRegion.hearthstoneKeep => 'An old keep full of home comforts.',
        ExpeditionRegion.bazaarOfWhims =>
          'Every stall shouts "buy me". The hero only looks.',
        ExpeditionRegion.subscriptionSwamp =>
          'Murky waters where forgotten renewals lurk.',
        ExpeditionRegion.theWilds => 'Far past the map\'s edge.',
      };

  static String chest(ChestType c) => switch (c) {
        ChestType.wood => 'Wood chest',
        ChestType.iron => 'Iron chest',
        ChestType.gold => 'Gold chest',
        ChestType.party => 'Party chest',
        ChestType.spoils => 'Spoils chest',
      };

  static String gearSlot(String slot) => switch (slot) {
        'weapon' => 'Weapon',
        'armor' => 'Armour',
        'trinket' => 'Trinket',
        _ => _title(slot),
      };

  static String gearType(String type) => _title(type);

  static String ritualStep(RitualStep s) => switch (s) {
        RitualStep.reconcile => 'Reconcile',
        RitualStep.review => 'Review',
        RitualStep.plan => 'Plan',
        RitualStep.contribute => 'Contribute',
      };

  static String ritualStepBlurb(RitualStep s) => switch (s) {
        RitualStep.reconcile =>
          'Make sure every purchase from the month is in the ledger, and note '
              'what the variable bills actually came to.',
        RitualStep.review =>
          'Look over the month report: where it went, what went to plan.',
        RitualStep.plan => 'Set up the budgets for the month ahead.',
        RitualStep.contribute =>
          'Divide what was left over: carry it, save it, or put it toward a '
              'goal.',
      };

  static String ritualStepLink(RitualStep s) => switch (s) {
        RitualStep.reconcile => 'Open the ledger',
        RitualStep.review => 'Open the month report',
        RitualStep.plan => 'Open budget setup',
        RitualStep.contribute => 'Divide the leftovers',
      };

  /// "12 lumber, 4 stone" (empty bundle: "nothing").
  static String bundle(MaterialBundle b) => b.isEmpty
      ? 'nothing'
      : [for (final e in b.amounts.entries) '${e.value} ${material(e.key)}']
          .join(', ');

  /// "15 gems + 20 lumber, 5 stone" / "Free".
  static String cost(Loot cost) {
    final parts = [
      if (cost.gems > 0) gems(cost.gems),
      if (!cost.materials.isEmpty) bundle(cost.materials),
    ];
    return parts.isEmpty ? 'Free' : parts.join(' + ');
  }

  /// What a chest or reward held: "18 gems, 1 freeze token, 2 lumber".
  static String loot(Loot loot) {
    final parts = [
      if (loot.gems > 0) gems(loot.gems),
      if (loot.tokens > 0)
        '${loot.tokens} freeze token${loot.tokens == 1 ? '' : 's'}',
      if (!loot.materials.isEmpty) bundle(loot.materials),
    ];
    return parts.isEmpty ? 'a handshake' : parts.join(', ');
  }

  static String gems(int n) => '$n gem${n == 1 ? '' : 's'}';

  /// "45m", "3h 20m", "1d 4h".
  static String duration(Duration d) {
    if (d.isNegative || d == Duration.zero) return 'now';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    if (days > 0) return hours > 0 ? '${days}d ${hours}h' : '${days}d';
    if (d.inHours > 0) return minutes > 0 ? '${d.inHours}h ${minutes}m' : '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '<1m';
  }

  /// How long building [tier] takes: "Instant" or "4h".
  static String buildTime(int tier) {
    final d = Balance.buildTimeByTier[tier - 1];
    return d == Duration.zero ? 'Instant' : duration(d);
  }

  static String _title(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
