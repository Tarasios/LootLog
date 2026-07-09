/// Merge-import: the count-only preview shown before applying a `.dbevents(.zip)`
/// swap, and echoed back as the summary after.
///
/// Import is idempotent — events match by `eventId`, receipt/sprite blobs by
/// content hash, and nothing is ever overwritten — so a single [MergePreview]
/// describes both "what applying will add" and, unchanged, "what was added".
/// The preview is a pure function of set membership ([computeMergePreview]); the
/// service layer gathers the "already present" sets from the DB and blob store.
library;

import '../../domain/event.dart';

/// How much of an incoming file is new versus already present locally.
class MergePreview {
  const MergePreview({
    required this.newEvents,
    required this.presentEvents,
    required this.newReceipts,
    required this.presentReceipts,
  });

  /// Incoming events whose `eventId` is not already in the local log.
  final int newEvents;

  /// Incoming events already in the local log (idempotent no-ops).
  final int presentEvents;

  /// Carried receipt/sprite blobs whose content hash is not already stored.
  final int newReceipts;

  /// Carried blobs already stored locally.
  final int presentReceipts;

  /// Total distinct events described by the file.
  int get totalEvents => newEvents + presentEvents;

  /// Whether applying this file would change nothing at all.
  bool get isNoOp => newEvents == 0 && newReceipts == 0;

  /// A one-line human summary, e.g. `14 new events, 3 receipts — 210 already
  /// present`. Receipts are omitted when none are new; the "already present"
  /// tail is omitted when everything in the file is new.
  String describe() {
    final head = StringBuffer('$newEvents new ${_plural(newEvents, 'event')}');
    if (newReceipts > 0) {
      head.write(', $newReceipts ${_plural(newReceipts, 'receipt')}');
    }
    if (presentEvents == 0) {
      return head.toString();
    }
    return '$head — $presentEvents already present';
  }

  static String _plural(int n, String word) => n == 1 ? word : '${word}s';
}

/// Computes a [MergePreview] purely from set membership. [incomingEvents] and
/// [incomingBlobShas] are what the file carries; [existingEventIds] and
/// [existingBlobShas] are what the device already has. Duplicates within the
/// file itself are counted once.
MergePreview computeMergePreview({
  required Iterable<Event> incomingEvents,
  required Set<String> existingEventIds,
  required Iterable<String> incomingBlobShas,
  required Set<String> existingBlobShas,
}) {
  var newEvents = 0;
  var presentEvents = 0;
  final seenEvents = <String>{};
  for (final e in incomingEvents) {
    if (!seenEvents.add(e.eventId)) continue;
    if (existingEventIds.contains(e.eventId)) {
      presentEvents++;
    } else {
      newEvents++;
    }
  }

  var newReceipts = 0;
  var presentReceipts = 0;
  final seenShas = <String>{};
  for (final sha in incomingBlobShas) {
    if (!seenShas.add(sha)) continue;
    if (existingBlobShas.contains(sha)) {
      presentReceipts++;
    } else {
      newReceipts++;
    }
  }

  return MergePreview(
    newEvents: newEvents,
    presentEvents: presentEvents,
    newReceipts: newReceipts,
    presentReceipts: presentReceipts,
  );
}
