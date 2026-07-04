/// UUIDv7 generation. Event IDs are time-ordered UUIDv7 so that sorting by id
/// approximates sorting by creation time. Pure Dart, zero Flutter imports.
library;

import 'dart:math';

final Random _rng = Random.secure();

/// Generates a UUIDv7 string for the given [millisSinceEpoch] (defaults to now).
///
/// Layout (RFC 9562): 48-bit big-endian Unix millisecond timestamp, version
/// nibble `7`, 12 bits of randomness, variant bits `10`, then 62 bits of
/// randomness.
String uuidv7({int? millisSinceEpoch}) {
  final ts = millisSinceEpoch ?? DateTime.now().toUtc().millisecondsSinceEpoch;
  final bytes = Uint8ListLike(16);

  // 48-bit timestamp, big-endian.
  bytes[0] = (ts >> 40) & 0xff;
  bytes[1] = (ts >> 32) & 0xff;
  bytes[2] = (ts >> 24) & 0xff;
  bytes[3] = (ts >> 16) & 0xff;
  bytes[4] = (ts >> 8) & 0xff;
  bytes[5] = ts & 0xff;

  // Random for the rest.
  for (var i = 6; i < 16; i++) {
    bytes[i] = _rng.nextInt(256);
  }

  // Version 7 in the high nibble of byte 6.
  bytes[6] = (bytes[6] & 0x0f) | 0x70;
  // Variant 10 in the two high bits of byte 8.
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = [for (final b in bytes.values) b.toRadixString(16).padLeft(2, '0')];
  return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
      '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
      '${hex.sublist(10, 16).join()}';
}

/// A tiny fixed-length byte buffer. Avoids importing `dart:typed_data` for such
/// a small need while keeping the generator free of Flutter dependencies.
class Uint8ListLike {
  Uint8ListLike(int length) : values = List<int>.filled(length, 0);

  final List<int> values;

  int operator [](int index) => values[index];

  void operator []=(int index, int value) => values[index] = value & 0xff;
}
