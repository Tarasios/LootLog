/// Update-safety: schema migrations preserve data (workstream G).
///
/// An app update opens yesterday's database file with today's schema. These
/// tests build a real database file, rewind it to an old schema version
/// (dropping the tables later versions added — surviving tables have kept
/// their shape across every migration to date), then reopen it with the
/// current [AppDatabase] and assert that the event log, device setup, sync
/// cursors, and pairings all survive and that the new tables work.
///
/// When `schemaVersion` is next bumped, add the new version's dropped tables
/// to [_tablesAddedAfter] and these tests keep guarding the upgrade path.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/setup/local_setup.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

/// SQL table names by the schema version that introduced them. Dropping every
/// table added after version N turns a current file into a faithful version-N
/// file (no migration to date has altered a pre-existing table).
List<String> _tablesAddedAfter(int version) => [
      if (version < 2) ...[
        'hosted_event_seq',
        'hub_config_rows',
        'hub_device_tokens',
        'paired_hubs',
      ],
      if (version < 3) 'export_bookmarks',
    ];

Event _member(String id, String name) => MemberSet(
      eventId: 'm-$id',
      deviceId: 'dev-1',
      userId: id,
      occurredAt: DateTime.utc(2026, 1, 1, 18),
      createdAt: DateTime.utc(2026, 1, 1, 18),
      memberId: id,
      name: name,
      role: MemberRole.adult,
    );

Event _purchase(String id, int cents) => PurchaseAdded(
      eventId: 'p-$id',
      deviceId: 'dev-1',
      userId: 'u1',
      occurredAt: DateTime.utc(2026, 1, 10, 18),
      createdAt: DateTime.utc(2026, 1, 10, 18),
      purchaseId: id,
      target: const VaultCharge(),
      amountCents: cents,
      shared: false,
    );

LocalSetup _setup() => LocalSetup(
      timezone: 'America/Vancouver',
      user1: const UserProfile(userId: 'u1', name: 'Robin'),
      user2: const UserProfile(userId: 'u2', name: 'Sam'),
      meUserId: 'u1',
    );

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('lootlog-migration');
  });
  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  File dbFile() => File('${tmp.path}/app.db');

  /// Creates a current-schema database file holding real data, then rewinds
  /// the file to look exactly like a version-[from] install.
  Future<void> seedAsVersion(int from) async {
    final db = AppDatabase(NativeDatabase(dbFile()));
    await db.eventsDao.appendEvents([
      _member('u1', 'Robin'),
      _member('u2', 'Sam'),
      _purchase('p1', 1250),
    ]);
    await db.localSetupDao.save(_setup());
    await db.syncDao.setPullCursor('hub-a', 17);
    await db.close();

    final raw = sq.sqlite3.open(dbFile().path);
    for (final table in _tablesAddedAfter(from)) {
      raw.execute('DROP TABLE $table;');
    }
    raw.execute('PRAGMA user_version = $from;');
    raw.dispose();
  }

  Future<void> expectDataSurvived(AppDatabase db) async {
    final events = await db.eventsDao.allEvents();
    expect(events.map((e) => e.eventId), containsAll(['m-u1', 'm-u2', 'p-p1']));
    expect(
      events.whereType<PurchaseAdded>().single.amountCents,
      1250,
      reason: 'integer cents must round-trip an upgrade exactly',
    );

    final setup = await db.localSetupDao.load();
    expect(setup, isNotNull);
    expect(setup!.meUserId, 'u1');
    expect(setup.user2.name, 'Sam');

    expect(await db.syncDao.pullCursor('hub-a'), 17,
        reason: 'pull cursors survive so sync resumes, not re-pulls');
  }

  test('a v1 file upgrades to the current schema with all data intact',
      () async {
    await seedAsVersion(1);

    final db = AppDatabase(NativeDatabase(dbFile()));
    await expectDataSurvived(db);

    // The tables v2 and v3 added exist and work after the upgrade.
    await db.pairedHubDao.upsert(const PairedHubRow(
      hubId: 'hub-b',
      baseUrl: 'http://192.168.1.20:8080',
      deviceToken: 'tok-123',
      name: 'Desktop',
    ));
    expect((await db.pairedHubDao.all()).single.deviceToken, 'tok-123');
    await db.close();
  });

  test('a v2 file upgrades to the current schema with pairings intact',
      () async {
    await seedAsVersion(2);

    // v2 already had paired_hubs — a pairing recorded before the update must
    // survive it (re-pairing after every release would be a broken product).
    final raw = sq.sqlite3.open(dbFile().path);
    raw.execute(
      "INSERT INTO paired_hubs (hub_id, base_url, device_token, name) "
      "VALUES ('hub-a', 'http://192.168.1.20:8080', 'tok-old', 'Desktop');",
    );
    raw.dispose();

    final db = AppDatabase(NativeDatabase(dbFile()));
    await expectDataSurvived(db);

    final hubs = await db.pairedHubDao.all();
    expect(hubs.single.hubId, 'hub-a');
    expect(hubs.single.deviceToken, 'tok-old',
        reason: 'hub bearer tokens survive an update — no re-pairing');
    await db.close();
  });

  test('reopening a current-version file is a clean no-op', () async {
    await seedAsVersion(3);
    final db = AppDatabase(NativeDatabase(dbFile()));
    await expectDataSurvived(db);
    await db.close();
  });
}
