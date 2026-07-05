/// Wire types shared by the hub server and the sync client.
///
/// The sync protocol is deliberately tiny: events travel as their canonical
/// JSON envelope (see `Event.toJson` / `Event.fromJson`), blobs travel as raw
/// content-addressed bytes, and everything is idempotent. These small records
/// just name the request/response shapes so both ends agree.
library;

import '../../domain/event.dart';

/// Result of `POST /pair`: the hub's stable identity plus the bearer token this
/// device must present on every subsequent request.
class PairResult {
  const PairResult({required this.hubId, required this.deviceToken});

  final String hubId;
  final String deviceToken;

  factory PairResult.fromJson(Map<String, dynamic> json) => PairResult(
        hubId: json['hubId'] as String,
        deviceToken: json['deviceToken'] as String,
      );

  Map<String, dynamic> toJson() => {'hubId': hubId, 'deviceToken': deviceToken};
}

/// Result of `GET /events?after=`: a page of hosted events, the `seq` to resume
/// from ([cursor]), and the hub's current high-water mark. The client advances
/// its cursor to [cursor] and pulls again until an empty page.
class EventPage {
  const EventPage({
    required this.events,
    required this.cursor,
    required this.maxSeq,
  });

  final List<Event> events;

  /// The seq to pass as `after` on the next pull (the last event's seq, or the
  /// requested `after` when the page is empty).
  final int cursor;

  /// The hub's highest assigned seq — how far behind the client still is.
  final int maxSeq;

  Map<String, dynamic> toJson() => {
        'events': [for (final e in events) e.toJson()],
        'cursor': cursor,
        'maxSeq': maxSeq,
      };

  factory EventPage.fromJson(Map<String, dynamic> json) => EventPage(
        events: [
          for (final e in (json['events'] as List))
            Event.fromJson((e as Map).cast<String, dynamic>()),
        ],
        cursor: json['cursor'] as int,
        maxSeq: json['maxSeq'] as int,
      );
}

/// Hard cap on a single blob, enforced by both `PUT /blobs` and the client. A
/// receipt image is re-encoded well under this; the ceiling guards the hub.
const int kMaxBlobBytes = 20 * 1024 * 1024;
