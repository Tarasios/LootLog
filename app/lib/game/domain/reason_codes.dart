/// Reason codes shared by the reward engine and the game projection.
/// Pure Dart, zero Flutter imports.
library;

import 'game_values.dart';

/// The reward id of [who]'s supply caravan for household day [day]. One per
/// Standard adult per active day, so the id doubles as the record that the
/// caravan adult showed up that day.
String caravanRewardId(String who, GameDay day) =>
    '$_caravanRewardPrefix$who:${day.toKey()}';

/// The household day a caravan reward id was granted for, or null when
/// [rewardId] is not a caravan reward.
GameDay? caravanRewardDay(String rewardId) {
  if (!rewardId.startsWith(_caravanRewardPrefix)) return null;
  final dayKey = rewardId.substring(rewardId.lastIndexOf(':') + 1);
  try {
    return GameDay.parse(dayKey);
  } on FormatException {
    return null;
  }
}

const String _caravanRewardPrefix = 'caravan:';

/// The acquisition id of [personId]'s grand-festival decoration for the
/// week starting [week].
String festivalDecorAcquisitionId(String personId, GameDay week) =>
    '$_festivalDecorPrefix$personId:${week.toKey()}';

/// Whether [acquisitionId] is a grand-festival decoration, which the
/// projection turns into gems when the item is already owned (so devices
/// that disagreed about ownership converge).
bool isFestivalDecorAcquisition(String acquisitionId) =>
    acquisitionId.startsWith(_festivalDecorPrefix);

const String _festivalDecorPrefix = 'festival.decor:';

/// The `reasonCode`s with meaning to the projection. Other codes are free-form.
abstract final class GameReasonCodes {
  /// The once-a-day reward for logging at least one purchase.
  static const String dailyLog = 'log.daily';

  /// The once-a-day reward for a "no spend today" check-in (counts as logging).
  static const String noSpendCheckIn = 'checkin.no_spend';

  /// +1 gem for each further purchase logged that day (capped).
  static const String extraLog = 'log.extra';

  /// +1 gem for logging a purchase within a day of when it happened (capped).
  static const String timely = 'log.timely';

  /// The wood chest for enough active days in a week.
  static const String weeklyCheckIn = 'week.checkin';

  /// The iron chest and gems for a completed weekly reconcile.
  static const String weeklyReconcile = 'week.reconcile';

  /// The party chest for a week every partner showed up.
  static const String partyWeek = 'week.party';

  /// A freeze token earned by the streak.
  static const String streakToken = 'streak.token';

  /// A Standard-mode partner's active day (the supply caravan). Its goods
  /// travel the trade road ([tradeRoad]).
  static const String caravan = 'caravan.supply';

  /// A neighbour's caravan on the trade road, on a day you were both active
  /// (additive; never names anyone).
  static const String tradeRoad = 'trade.road';

  /// The spoils chest for finishing a month's ritual (win or lose).
  static const String ritualSpoils = 'ritual.spoils';

  /// Bonus gems for finishing a month's ritual on time, plus hero gear.
  static const String ritualBonus = 'ritual.bonus';

  /// The gold chest for a personal category that ended a closed month at or
  /// under its limit (a bonus, never a requirement).
  static const String monthGold = 'month.gold';

  /// Gems for a savings quest crossing a share of its goal.
  static const String vaultQuest = 'vault.quest';

  /// Gems for consecutive closed months with a savings allocation.
  static const String vaultSavingsStreak = 'vault.consistency';

  /// The weekend festival's loot, sized by the week's town spirit.
  static const String festival = 'festival.weekend';

  /// Bonus gems when two or more Adventure adults reached a fair or better
  /// the same week (additive; never names anyone).
  static const String festivalJoint = 'festival.joint';

  /// Rewards whose grant marks their household-local day as covered in the
  /// person's streak. The reward engine must grant at most one per person per
  /// day (the daily gem cap) and stamp it with the logged day's `occurredAt`.
  static const Set<String> streakDays = {dailyLog, noSpendCheckIn};
}
