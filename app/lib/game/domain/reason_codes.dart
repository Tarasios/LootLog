/// Reason codes shared by the reward engine and the game projection.
/// Pure Dart, zero Flutter imports.
library;

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

  /// A Standard-mode partner's supply caravan for the party pool.
  static const String caravan = 'caravan.supply';

  /// Rewards whose grant marks their household-local day as covered in the
  /// person's streak. The reward engine must grant at most one per person per
  /// day (the daily gem cap) and stamp it with the logged day's `occurredAt`.
  static const Set<String> streakDays = {dailyLog, noSpendCheckIn};
}
