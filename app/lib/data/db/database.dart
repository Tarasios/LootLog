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
import '../../domain/ids.dart';
import '../setup/local_setup.dart';
import 'tables.dart';

part 'database.g.dart';

/// Data-access object for the append-only event log.
@DriftAccessor(tables: [Events, ExportBookmarks])
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

  /// The subset of [ids] that are already in the log. Used by merge-import to
  /// preview how many incoming events are new versus already present, without
  /// loading the whole log.
  Future<Set<String>> existingEventIds(Iterable<String> ids) async {
    final wanted = ids.toSet().toList();
    if (wanted.isEmpty) {
      return <String>{};
    }
    final query = selectOnly(events)
      ..addColumns([events.eventId])
      ..where(events.eventId.isIn(wanted));
    final rows = await query.get();
    return {for (final r in rows) r.read(events.eventId)!};
  }

  /// The highest event `rowid` currently stored (0 if the log is empty). rowid is
  /// SQLite's local insertion order, so it advances for both locally authored and
  /// imported events — the cursor the "export since last export" shortcut rides.
  Future<int> maxEventRowid() async {
    final row = await customSelect(
      'SELECT COALESCE(MAX(_rowid_), 0) AS m FROM ${events.actualTableName}',
      readsFrom: {events},
    ).getSingle();
    return row.read<int>('m');
  }

  /// The events inserted after [afterRowid] (by local insertion order), returned
  /// in canonical `(occurredAt, eventId)` order. Everything that has arrived —
  /// captured or merged-in — since the cursor was last advanced.
  Future<List<Event>> eventsAfterRowid(int afterRowid) async {
    final rows = await customSelect(
      'SELECT * FROM ${events.actualTableName} WHERE _rowid_ > ?1 '
      'ORDER BY occurred_at, event_id',
      variables: [Variable.withInt(afterRowid)],
      readsFrom: {events},
    ).get();
    return [for (final r in rows) _eventFromRow(events.map(r.data))];
  }

  /// The rowid cursor of the last export (0 if never exported).
  Future<int> lastExportRowid() async {
    final row = await (select(exportBookmarks)..where((t) => t.id.equals(0)))
        .getSingleOrNull();
    return row?.lastExportedRowid ?? 0;
  }

  /// Advances the export cursor to [rowid] after a successful export.
  Future<void> setLastExportRowid(int rowid) async {
    await into(exportBookmarks).insertOnConflictUpdate(
      ExportBookmarkRow(id: 0, lastExportedRowid: rowid),
    );
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

/// A page of hosted events plus the `seq` cursor to resume from.
class HostedPage {
  const HostedPage({required this.events, required this.cursor});

  final List<Event> events;
  final int cursor;
}

/// Data-access object for a device **acting as a hub**: its stable identity,
/// the tokens it has issued, and the monotonic per-hub sequence it assigns to
/// every event it hosts.
///
/// Sequencing is arrival-ordered: [assignSeqs] gives a `seq` to every event in
/// the log that lacks one, so both locally authored events and events pushed by
/// paired devices become visible to `GET /events?after=`. Because `seq` is only
/// ever handed to not-yet-sequenced events, an assigned `seq` is stable forever
/// and cursors never miss or replay a row.
@DriftAccessor(tables: [Events, HostedEventSeq, HubConfigRows, HubDeviceTokens])
class HubHostDao extends DatabaseAccessor<AppDatabase> with _$HubHostDaoMixin {
  HubHostDao(super.db);

  /// This device's hub identity, creating it on first call. The [hubId] and
  /// [pairingSecret] are only generated when absent; passing them lets a caller
  /// (e.g. the e2e harness) pin deterministic values on a fresh database.
  Future<HubConfigRow> ensureConfig({String? hubId, String? pairingSecret}) async {
    final existing =
        await (select(hubConfigRows)..where((t) => t.id.equals(0)))
            .getSingleOrNull();
    if (existing != null) {
      return existing;
    }
    final row = HubConfigRow(
      id: 0,
      hubId: hubId ?? uuidv7(),
      pairingSecret: pairingSecret ?? uuidv7(),
    );
    await into(hubConfigRows).insert(row);
    return row;
  }

  /// Assigns a `seq` to every hosted event that lacks one and returns the new
  /// high-water mark. Idempotent: events already sequenced are left untouched.
  Future<int> assignSeqs() async {
    final assigned = selectOnly(hostedEventSeq)
      ..addColumns([hostedEventSeq.eventId]);
    final query = select(events)
      ..where((t) => t.eventId.isNotInQuery(assigned))
      ..orderBy([(t) => OrderingTerm(expression: t.eventId)]);
    final pending = await query.get();
    if (pending.isNotEmpty) {
      await batch((b) {
        b.insertAll(
          hostedEventSeq,
          [
            for (final r in pending)
              HostedEventSeqCompanion.insert(eventId: r.eventId),
          ],
          mode: InsertMode.insertOrIgnore,
        );
      });
    }
    return maxSeq();
  }

  /// The highest `seq` this hub has assigned (0 if it hosts nothing yet).
  Future<int> maxSeq() async {
    final expr = hostedEventSeq.seq.max();
    final q = selectOnly(hostedEventSeq)..addColumns([expr]);
    final row = await q.getSingleOrNull();
    return row?.read(expr) ?? 0;
  }

  /// Up to [limit] hosted events with `seq > after`, in `seq` order, paired with
  /// the `seq` to resume from (the last row's seq, or [after] when the page is
  /// empty). Pagination-safe: a caller advances its cursor to [HostedPage.cursor]
  /// and repeats until a short page signals it has caught up.
  Future<HostedPage> eventsAfter(int after, {int limit = 500}) async {
    final rows = await (select(events).join([
      innerJoin(
        hostedEventSeq,
        hostedEventSeq.eventId.equalsExp(events.eventId),
      ),
    ])
          ..where(hostedEventSeq.seq.isBiggerThanValue(after))
          ..orderBy([OrderingTerm(expression: hostedEventSeq.seq)])
          ..limit(limit))
        .get();
    final events0 = [
      for (final r in rows) db.eventsDao._eventFromRow(r.readTable(events)),
    ];
    final cursor =
        rows.isEmpty ? after : rows.last.read(hostedEventSeq.seq)!;
    return HostedPage(events: events0, cursor: cursor);
  }

  /// Records a device token issued at pairing. Idempotent on the token.
  Future<void> issueToken(String token, String deviceName) async {
    await into(hubDeviceTokens).insertOnConflictUpdate(
      HubDeviceTokenRow(
        token: token,
        deviceName: deviceName,
        pairedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Whether [token] is a token this hub issued.
  Future<bool> isValidToken(String token) async {
    final row = await (select(hubDeviceTokens)
          ..where((t) => t.token.equals(token)))
        .getSingleOrNull();
    return row != null;
  }
}

/// Data-access object for the hubs this device is paired with **as a client**.
@DriftAccessor(tables: [PairedHubs])
class PairedHubDao extends DatabaseAccessor<AppDatabase>
    with _$PairedHubDaoMixin {
  PairedHubDao(super.db);

  /// All hubs this device syncs with.
  Future<List<PairedHubRow>> all() =>
      (select(pairedHubs)..orderBy([(t) => OrderingTerm(expression: t.hubId)]))
          .get();

  /// Watches the paired hubs for the sync-status UI.
  Stream<List<PairedHubRow>> watch() =>
      (select(pairedHubs)..orderBy([(t) => OrderingTerm(expression: t.hubId)]))
          .watch();

  /// Adds or updates a pairing.
  Future<void> upsert(PairedHubRow row) =>
      into(pairedHubs).insertOnConflictUpdate(row);

  /// Forgets a hub (unpairs it).
  Future<void> remove(String hubId) =>
      (delete(pairedHubs)..where((t) => t.hubId.equals(hubId))).go();
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

/// The LootLog local database.
@DriftDatabase(
  tables: [
    Events,
    HubCursors,
    HubPushLog,
    HostedEventSeq,
    HubConfigRows,
    HubDeviceTokens,
    PairedHubs,
    Snapshots,
    LocalSetupRows,
    ExportBookmarks,
  ],
  daos: [EventsDao, SyncDao, HubHostDao, PairedHubDao, LocalSetupDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2 adds the hub-hosting and client-pairing tables. Nothing in the
          // append-only event log changes, so the upgrade only creates the new
          // bookkeeping tables.
          if (from < 2) {
            await m.createTable(hostedEventSeq);
            await m.createTable(hubConfigRows);
            await m.createTable(hubDeviceTokens);
            await m.createTable(pairedHubs);
          }
          // v3 adds the device-local "export since last export" bookmark. Again
          // device-local bookkeeping only; the event log is untouched.
          if (from < 3) {
            await m.createTable(exportBookmarks);
          }
        },
      );
}
