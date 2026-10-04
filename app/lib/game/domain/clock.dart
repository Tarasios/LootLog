/// The game's only source of "now". Injected everywhere time matters, so the
/// same events and the same clock always produce the same game events.
///
/// Pure Dart, zero Flutter imports.
library;

abstract interface class Clock {
  /// The current instant, in UTC.
  DateTime now();
}

/// The device's wall clock.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// A clock frozen at one instant (tests, replays).
class FixedClock implements Clock {
  FixedClock(DateTime at) : _at = at.toUtc();

  final DateTime _at;

  @override
  DateTime now() => _at;
}
