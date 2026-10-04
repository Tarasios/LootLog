/// Every tunable balance number for the guild-hall layer lives here and
/// nowhere else (see `README.md`). Pure Dart, zero Flutter imports.
library;

import '../domain/game_values.dart';

/// Guild-hall balance numbers.
abstract final class Balance {
  /// Hall plots unlocked before any `PlotUnlocked` event (indices
  /// `0 .. startingPlotCount - 1`). Placeholder until the economy pass.
  static const int startingPlotCount = 3;

  // ---- Reward engine ------------------------------------------------------

  /// The gem pouch for a person's first active-day event of a day.
  static const int activeDayPouchGems = 5;

  /// Gems for each further purchase logged that day.
  static const int extraLogGems = 1;

  /// Gems for logging a purchase within [timelyWindow] of when it happened.
  static const int timelyBonusGems = 1;
  static const Duration timelyWindow = Duration(hours: 24);

  /// The most further-purchase and timely grants per person per day (the
  /// pouch is outside the cap). The anti-spam measure.
  static const int dailyGemCap = 5;

  /// Active days within one Monday-to-Sunday week that earn the wood chest.
  static const int weeklyCheckInActiveDays = 4;

  /// Gems that come with the iron chest for a completed weekly reconcile.
  static const int weeklyReconcileGems = 10;

  /// Streak length that earns each freeze token.
  static const int streakDaysPerFreezeToken = 7;

  /// The most freeze tokens a person holds at once (claimed or waiting).
  static const int maxFreezeTokens = 3;

  /// What a Standard-mode adult's active day sends to the party pool.
  static final MaterialBundle caravanMaterials =
      MaterialBundle({MaterialKind.lumber: 2, MaterialKind.stone: 1});

  /// How many days back activity is still rewarded. Bounds the catch-up when
  /// the game first runs over an existing ledger, while still rewarding a
  /// partner whose device was offline for a few days.
  static const int rewardLookbackDays = 7;
}
