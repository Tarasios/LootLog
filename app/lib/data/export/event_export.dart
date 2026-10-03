/// The offline fallback for sync: export/import the event log (and its receipt
/// blobs) as portable files, for when two devices can't reach a hub.
///
///  * `.dbevents`     — JSON Lines, one event envelope per line.
///  * `.dbevents.zip` — `events.jsonl` plus a `blobs/<sha256>` entry per
///                      referenced receipt/sprite blob, and — when there are
///                      any — the guild-hall game log as `game_events.jsonl`.
///                      Readers that predate game sync only open the entries
///                      they know, so the extra entry is invisible to them.
///
/// Plain `.dbevents` stays ledger-only: an older importer would reject a game
/// envelope line, so game events travel only in the zip.
///
/// Import is idempotent (events by `eventId`, blobs by content hash), so
/// importing the same file twice, or a file that overlaps what a hub already
/// delivered, changes nothing. Both directions are defensive: a truncated or
/// malformed file raises [ImportException] instead of corrupting the log, and a
/// blob whose bytes don't match its claimed hash raises [BlobIntegrityException]
/// rather than being silently trusted.
library;

// Blob IO is intentionally async so large imports never block the UI isolate.
// ignore_for_file: avoid_slow_async_io

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../domain/event.dart';
import '../../game/domain/game_event.dart';
import '../../game/domain/game_projection.dart';
import '../blobs/blob_store.dart';

/// The `events.jsonl` entry name inside a `.dbevents.zip`.
const String kEventsEntryName = 'events.jsonl';

/// The guild-hall game log's entry inside a `.dbevents.zip` (optional).
const String kGameEventsEntryName = 'game_events.jsonl';

/// Raised when an import file is malformed: not JSON Lines, missing the events
/// entry, or an envelope that doesn't parse. The log is never partially applied.
class ImportException implements Exception {
  const ImportException(this.message);
  final String message;
  @override
  String toString() => 'ImportException: $message';
}

/// Raised when a blob's bytes don't hash to the name it was stored under — a
/// tampered or corrupt archive. Nothing from the offending archive is trusted.
class BlobIntegrityException implements Exception {
  const BlobIntegrityException(this.expectedSha, this.actualSha);
  final String expectedSha;
  final String actualSha;
  @override
  String toString() =>
      'BlobIntegrityException: expected $expectedSha, got $actualSha';
}

/// Serializes [events] to `.dbevents` JSON-Lines text (one envelope per line),
/// in canonical `(occurredAt, eventId)` order so exports are reproducible.
String exportEventsJsonl(Iterable<Event> events) {
  final ordered = _canonical(events);
  final buffer = StringBuffer();
  for (final e in ordered) {
    buffer.writeln(jsonEncode(e.toJson()));
  }
  return buffer.toString();
}

/// Parses `.dbevents` JSON-Lines [text] back into events. Blank lines are
/// ignored; any non-parsing line raises [ImportException]. The result is safe to
/// hand to `EventsDao.appendEvents`, which dedupes by `eventId`.
List<Event> importEventsJsonl(String text) {
  final events = <Event>[];
  final lines = const LineSplitter().convert(text);
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    try {
      final map = (jsonDecode(line) as Map).cast<String, dynamic>();
      events.add(Event.fromJson(map));
    } on Object catch (e) {
      throw ImportException('line ${i + 1}: $e');
    }
  }
  return events;
}

/// Serializes game [events] as JSON Lines in canonical order.
String exportGameEventsJsonl(Iterable<GameEvent> events) {
  final buffer = StringBuffer();
  for (final e in [...events]..sort(compareGameEvents)) {
    buffer.writeln(jsonEncode(e.toJson()));
  }
  return buffer.toString();
}

/// Parses game-event JSON Lines; any non-parsing line raises
/// [ImportException]. Unknown game event types decode as `UnknownGameEvent`.
List<GameEvent> importGameEventsJsonl(String text) {
  final events = <GameEvent>[];
  final lines = const LineSplitter().convert(text);
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    try {
      final map = (jsonDecode(line) as Map).cast<String, dynamic>();
      events.add(GameEvent.fromJson(map));
    } on Object catch (e) {
      throw ImportException('$kGameEventsEntryName line ${i + 1}: $e');
    }
  }
  return events;
}

/// Builds a `.dbevents.zip` from [events] and their referenced blobs, reading
/// bytes from [blobs], plus [gameEvents] when there are any. Missing blobs are
/// skipped (the reference survives; the bytes can arrive from a hub later).
Future<Uint8List> exportEventsZip(
  Iterable<Event> events,
  BlobStore blobs, {
  Iterable<GameEvent> gameEvents = const [],
}) async {
  final ordered = _canonical(events);
  final archive = Archive()
    ..addFile(
      ArchiveFile.bytes(
        kEventsEntryName,
        utf8.encode(exportEventsJsonl(ordered)),
      ),
    );
  if (gameEvents.isNotEmpty) {
    archive.addFile(
      ArchiveFile.bytes(
        kGameEventsEntryName,
        utf8.encode(exportGameEventsJsonl(gameEvents)),
      ),
    );
  }
  for (final sha in BlobStore.referencedBlobs(ordered)) {
    if (!await blobs.exists(sha)) continue;
    final bytes = await blobs.read(sha);
    archive.addFile(ArchiveFile.bytes('blobs/$sha', bytes));
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

/// The events and verified blobs pulled out of a `.dbevents.zip`.
class ImportedArchive {
  const ImportedArchive({
    required this.events,
    required this.blobs,
    this.gameEvents = const [],
  });

  final List<Event> events;

  /// The guild-hall game log carried by the archive (empty for archives that
  /// predate game sync, and always for plain `.dbevents`).
  final List<GameEvent> gameEvents;

  /// Content-verified blob bytes, keyed by sha256. Every entry has already been
  /// checked against its name.
  final Map<String, Uint8List> blobs;
}

/// Parses a `.dbevents.zip`, verifying every `blobs/<sha256>` entry against its
/// name. Raises [ImportException] for a malformed archive and
/// [BlobIntegrityException] for a tampered blob — before anything is persisted.
ImportedArchive readEventsZip(List<int> zipBytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zipBytes);
  } on Object catch (e) {
    throw ImportException('not a readable zip: $e');
  }
  final eventsFile = archive.findFile(kEventsEntryName);
  if (eventsFile == null) {
    throw const ImportException('archive is missing $kEventsEntryName');
  }
  final events = importEventsJsonl(utf8.decode(eventsFile.content as List<int>));
  final gameFile = archive.findFile(kGameEventsEntryName);
  final gameEvents = gameFile == null
      ? const <GameEvent>[]
      : importGameEventsJsonl(utf8.decode(gameFile.content as List<int>));

  final blobs = <String, Uint8List>{};
  for (final file in archive.files) {
    if (!file.isFile || !file.name.startsWith('blobs/')) continue;
    final claimed = file.name.substring('blobs/'.length);
    final bytes = Uint8List.fromList(file.content as List<int>);
    final actual = sha256.convert(bytes).toString();
    if (actual != claimed.toLowerCase()) {
      throw BlobIntegrityException(claimed, actual);
    }
    blobs[actual] = bytes;
  }
  return ImportedArchive(events: events, blobs: blobs, gameEvents: gameEvents);
}

/// Persists a verified [ImportedArchive]'s blobs into [store], returning the
/// hashes written. Blobs were already integrity-checked by [readEventsZip].
Future<List<String>> saveImportedBlobs(
  ImportedArchive imported,
  BlobStore store,
) async {
  final written = <String>[];
  for (final entry in imported.blobs.entries) {
    await store.save(entry.value);
    written.add(entry.key);
  }
  return written;
}

List<Event> _canonical(Iterable<Event> events) => events.toList()
  ..sort((a, b) {
    final c = a.occurredAt.compareTo(b.occurredAt);
    return c != 0 ? c : a.eventId.compareTo(b.eventId);
  });
