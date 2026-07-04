/// The drift database and its data-access objects.
///
/// The database is the on-device system of record: an append-only [Events] log
/// plus local sync/setup bookkeeping. Derived state is never stored here (see
/// the reducer); the one exception is the schema-only [Snapshots] table, wired
/// up for a future memoization pass.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/event.dart';
import '../setup/local_setup.dart';
import 'tables.dart';

part 'database.g.dart';

/// Data-access object for the append-only event log.
@DriftAccessor(tables: [Events])
class EventsDao extends DatabaseAccessor<AppDatabase> with _$EventsDaoMixin {
  EventsDao(super.db);

  /// Appends [events] to the log. Idempotent on `eventId`: re-appending an event
  /// that already exists (a re-sync, an import, a replay) is a silent no-op, so
  /// the log can only ever grow and never diverge.
  Future<void> appendEvents(Iterable<Event> events) async {
    if (events.isEmpty) {
      return;
    }
    await batch((b) {
      b.insertAll(
        this.events,
        [for (final e in events) _rowFor(e)],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Watches the entire event log in canonical `(occurredAt, eventId)` order,
  /// re-emitting whenever the table changes. The reducer is order-independent,
  /// but ordering here keeps the stream stable and cheap for consumers.
  Stream<List<Event>> watchAllEvents() {
    final query = select(events)
      ..orderBy([
        (t) => OrderingTerm(expression: t.occurredAt),
        (t) => OrderingTerm(expression: t.eventId),
      ]);
    return query.watch().map(
          (rows) => [for (final r in rows) _eventFromRow(r)],
        );
  }

  /// A one-shot read of the whole log, in the same canonical order.
  Future<List<Event>> allEvents() async {
    final query = select(events)
      ..orderBy([
        (t) => OrderingTerm(expression: t.occurredAt),
        (t) => OrderingTerm(expression: t.eventId),
      ]);
    final rows = await query.get();
    return [for (final r in rows) _eventFromRow(r)];
  }

  EventsCompanion _rowFor(Event e) => EventsCompanion.insert(
        eventId: e.eventId,
        deviceId: e.deviceId,
        userId: e.userId,
        type: e.type,
        occurredAt: e.occurredAt,
        createdAt: e.createdAt,
        payload: jsonEncode(e.payload()),
      );

  Event _eventFromRow(EventRow r) => Event.fromJson({
        'eventId': r.eventId,
        'deviceId': r.deviceId,
        'userId': r.userId,
        'occurredAt': r.occurredAt.toUtc().toIso8601String(),
        'createdAt': r.createdAt.toUtc().toIso8601String(),
        'type': r.type,
        'payload': jsonDecode(r.payload),
      });
}

/// Data-access object for multi-hub sync bookkeeping: per-hub pull cursors and
/// per-event, per-hub push tracking. Event idempotency (by `eventId`) and
/// content-addressed blobs make convergence conflict-free, so this is pure
/// progress tracking with no merge logic.
@DriftAccessor(tables: [Events, HubCursors, HubPushLog])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  /// The last `hub_seq` pulled from [hubId] (0 if never pulled).
  Future<int> pullCursor(String hubId) async {
    final row = await (select(hubCursors)
          ..where((t) => t.hubId.equals(hubId)))
        .getSingleOrNull();
    return row?.lastPulledSeq ?? 0;
  }

  /// Records that [hubId] has been pulled up to [seq].
  Future<void> setPullCursor(String hubId, int seq) async {
    await into(hubCursors).insertOnConflictUpdate(
      HubCursorRow(hubId: hubId, lastPulledSeq: seq),
    );
  }

  /// The events not yet pushed to [hubId], in canonical order. These are the
  /// rows to send on the next `POST /events` batch for that hub.
  Future<List<Event>> unpushedEventsForHub(String hubId) async {
    final pushed = selectOnly(hubPushLog)
      ..addColumns([hubPushLog.eventId])
      ..where(hubPushLog.hubId.equals(hubId));
    final query = select(events)
      ..where((t) => t.eventId.isNotInQuery(pushed))
      ..orderBy([
        (t) => OrderingTerm(expression: t.occurredAt),
        (t) => OrderingTerm(expression: t.eventId),
      ]);
    final rows = await query.get();
    return [for (final r in rows) attachedTo._eventFromRow(r)];
  }

  /// Marks [eventIds] as pushed to [hubId]. Idempotent on `(hubId, eventId)`.
  Future<void> markPushed(String hubId, Iterable<String> eventIds) async {
    await batch((b) {
      b.insertAll(
        hubPushLog,
        [
          for (final id in eventIds)
            HubPushLogCompanion.insert(hubId: hubId, eventId: id),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  EventsDao get attachedTo => db.eventsDao;
}

/// Data-access object for device-local setup (timezone, profiles, "me").
@DriftAccessor(tables: [LocalSetupRows])
class LocalSetupDao extends DatabaseAccessor<AppDatabase>
    with _$LocalSetupDaoMixin {
  LocalSetupDao(super.db);

  /// The saved setup for this device, or null on a fresh install.
  Future<LocalSetup?> load() async {
    final row = await (select(localSetupRows)
          ..where((t) => t.id.equals(0)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Watches the setup, emitting null until first-run setup completes.
  Stream<LocalSetup?> watch() {
    final query = select(localSetupRows)..where((t) => t.id.equals(0));
    return query.watchSingleOrNull().map((r) => r == null ? null : _fromRow(r));
  }

  /// Persists (or overwrites) the device-local setup.
  Future<void> save(LocalSetup setup) async {
    await into(localSetupRows).insertOnConflictUpdate(
      LocalSetupRow(
        id: 0,
        timezone: setup.timezone,
        user1Id: setup.user1.userId,
        user1Name: setup.user1.name,
        user2Id: setup.user2.userId,
        user2Name: setup.user2.name,
        meUserId: setup.meUserId,
      ),
    );
  }

  LocalSetup _fromRow(LocalSetupRow r) => LocalSetup(
        timezone: r.timezone,
        user1: UserProfile(userId: r.user1Id, name: r.user1Name),
        user2: UserProfile(userId: r.user2Id, name: r.user2Name),
        meUserId: r.meUserId,
      );
}

/// The DuoBudget local database.
@DriftDatabase(
  tables: [Events, HubCursors, HubPushLog, Snapshots, LocalSetupRows],
  daos: [EventsDao, SyncDao, LocalSetupDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
