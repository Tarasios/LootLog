/// How game code stamps the events it writes. Pure Dart, zero Flutter imports.
library;

import '../../domain/ids.dart';

/// This device, and a source of fresh event ids: UUIDv7 in the app, so events
/// written together keep their order (the projection breaks `occurredAt` ties
/// by event id), and a deterministic counter in tests.
class GameEventStamp {
  const GameEventStamp({required this.deviceId, this.newEventId = uuidv7});

  final String deviceId;
  final String Function() newEventId;
}
