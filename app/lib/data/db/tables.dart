/// Drift table definitions for DuoBudget's local store.
///
/// The store is **append-only** for domain data: every state change is an
/// immutable [Events] row. Nothing here is ever `UPDATE`d or `DELETE`d in the
/// domain sense — corrections are new events. The remaining tables are local
/// bookkeeping (sync cursors, per-hub push tracking, device-local setup) plus a
/// schema-only [Snapshots] table reserved for future reducer memoization.
library;

import 'package:drift/drift.dart';

/// The immutable event log. `eventId` (UUIDv7) is the primary key, which makes
/// inserts idempotent — replaying or re-syncing an event is a no-op.
///
/// The envelope columns mirror `Event`; `payload` holds the type-specific JSON.
/// A row round-trips back to a domain `Event` via `Event.fromJson`.
@DataClassName('EventRow')
class Events extends Table {
  TextColumn get eventId => text()();
  TextColumn get deviceId => text()();
  TextColumn get userId => text()();
  TextColumn get type => text()();

  /// User-editable instant that keys the calendar month.
  DateTimeColumn get occurredAt => dateTime()();

  /// When the event was actually recorded on some device.
  DateTimeColumn get createdAt => dateTime()();

  /// The type-specific payload as a JSON object string.
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {eventId};
}

/// One pull cursor per paired hub. A device may pair with multiple hubs and
/// keeps an independent `lastPulledSeq` for each, so `GET /events?after=` can
/// resume where it left off per hub.
@DataClassName('HubCursorRow')
class HubCursors extends Table {
  TextColumn get hubId => text()();

  /// The highest per-hub `hub_seq` this device has pulled from `hubId`.
  IntColumn get lastPulledSeq => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {hubId};
}

/// Per-event, per-hub push tracking. A row `(hubId, eventId)` records that this
/// device has already pushed `eventId` to `hubId`. Events absent from this table
/// for a given hub are the ones still to be pushed on the next sync cycle.
@DataClassName('HubPushRow')
class HubPushLog extends Table {
  TextColumn get hubId => text()();
  TextColumn get eventId => text()();

  @override
  Set<Column<Object>> get primaryKey => {hubId, eventId};
}

/// Reserved for future reducer memoization: a serialized `HouseholdState` valid
/// up to some event. Schema only — nothing reads or writes this yet.
@DataClassName('SnapshotRow')
class Snapshots extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The read-time the snapshot was computed for.
  DateTimeColumn get asOf => dateTime()();

  /// The last event id folded into this snapshot (null = empty log).
  TextColumn get upToEventId => text().nullable()();

  /// Serialized derived state.
  TextColumn get state => text()();
}

/// Device-local first-run setup: the household timezone, the two user profiles,
/// and which of them is "me" on this device. This is intentionally NOT an event
/// — "me" is per-device and must never sync.
@DataClassName('LocalSetupRow')
class LocalSetupRows extends Table {
  /// Singleton row; always 0.
  IntColumn get id => integer().withDefault(const Constant(0))();

  TextColumn get timezone =>
      text().withDefault(const Constant('America/Vancouver'))();

  TextColumn get user1Id => text()();
  TextColumn get user1Name => text()();
  TextColumn get user2Id => text()();
  TextColumn get user2Name => text()();

  /// The `userId` (either `user1Id` or `user2Id`) that this device represents.
  TextColumn get meUserId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
