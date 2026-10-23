/// The game's only source of randomness: a small, fully specified PRNG seeded
/// from the id of the event a command is about to write.
///
/// Every device must roll the same chest, the same expedition loot and the
/// same boss fight from the same event id, so nothing here relies on
/// `dart:math`'s `Random` (whose algorithm is not specified across platforms
/// or SDK versions). Instead:
/// - [stableHash32] is FNV-1a (32-bit) over the id's UTF-16 code units;
/// - [GameRng] is mulberry32, with every multiply done in exact 32-bit
///   arithmetic, so it gives the same numbers on the VM, AOT and the web.
///
/// Outcomes are rolled once, at command time, and stored in the event; the
/// projection never re-rolls. Changing this algorithm would only change future
/// rolls, but the pinned-sequence test keeps it from drifting by accident.
///
/// Pure Dart, zero Flutter imports.
library;

const int _mask32 = 0xffffffff;

/// FNV-1a 32-bit hash of [s]'s UTF-16 code units: stable across devices,
/// platforms and SDK versions (unlike `String.hashCode`).
int stableHash32(String s) {
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    // Low byte then high byte, so ASCII hashes like the byte-wise reference.
    h ^= unit & 0xff;
    h = _imul(h, 0x01000193);
    final hi = unit >> 8;
    if (hi != 0) {
      h ^= hi;
      h = _imul(h, 0x01000193);
    }
  }
  return h;
}

/// Exact 32-bit multiply (the low 32 bits of `a * b`), safe on every platform.
int _imul(int a, int b) {
  final aHi = (a >> 16) & 0xffff;
  final aLo = a & 0xffff;
  final bHi = (b >> 16) & 0xffff;
  final bLo = b & 0xffff;
  final cross = ((aHi * bLo + aLo * bHi) & 0xffff) << 16;
  return (aLo * bLo + cross) & _mask32;
}

/// A deterministic pseudo-random sequence (mulberry32).
class GameRng {
  GameRng(int seed) : _state = seed & _mask32;

  /// The generator for the event with id [eventId]: the same id gives the
  /// same sequence on every device.
  factory GameRng.forEvent(String eventId) => GameRng(stableHash32(eventId));

  int _state;

  /// The next value in `[0, 2^32)`.
  int nextUint32() {
    _state = (_state + 0x6d2b79f5) & _mask32;
    var t = _imul(_state ^ (_state >> 15), _state | 1);
    t = ((t + _imul(t ^ (t >> 7), t | 61)) & _mask32) ^ t;
    return (t ^ (t >> 14)) & _mask32;
  }

  /// A uniform value in `[0, max)`, without modulo bias.
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'must be positive');
    const span = 0x100000000;
    final limit = span - span % max;
    while (true) {
      final v = nextUint32();
      if (v < limit) return v % max;
    }
  }

  /// A uniform value in `[min, max]` (inclusive at both ends).
  int range(int min, int max) {
    if (max < min) {
      throw ArgumentError('range($min, $max): max is below min');
    }
    return min + nextInt(max - min + 1);
  }

  /// True with probability [permille] / 1000 (0 never, 1000 always).
  bool chance(int permille) {
    if (permille <= 0) return false;
    if (permille >= 1000) return true;
    return nextInt(1000) < permille;
  }

  /// One element of [items], uniformly.
  T pick<T>(List<T> items) {
    if (items.isEmpty) throw ArgumentError('pick from an empty list');
    return items[nextInt(items.length)];
  }
}
