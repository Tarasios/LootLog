/// Reason codes shared by the reward engine and the game projection.
/// Pure Dart, zero Flutter imports.
library;

/// The `reasonCode`s with meaning to the projection. Other codes are free-form.
abstract final class GameReasonCodes {
  /// The once-a-day reward for logging at least one purchase.
  static const String dailyLog = 'log.daily';

  /// The once-a-day reward for a "no spend today" check-in (counts as logging).
  static const String noSpendCheckIn = 'checkin.no_spend';

  /// Rewards whose grant marks their household-local day as covered in the
  /// person's streak. The reward engine must grant at most one per person per
  /// day (the daily gem cap) and stamp it with the logged day's `occurredAt`.
  static const Set<String> streakDays = {dailyLog, noSpendCheckIn};
}
