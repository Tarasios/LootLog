/// Every tunable balance number for the guild-hall layer lives here and
/// nowhere else (see `README.md`). Pure Dart, zero Flutter imports.
library;

/// Guild-hall balance numbers.
abstract final class Balance {
  /// Hall plots unlocked before any `PlotUnlocked` event (indices
  /// `0 .. startingPlotCount - 1`). Placeholder until the economy pass.
  static const int startingPlotCount = 3;
}
