/// App-facing sync wiring: a [SyncService] that owns this device's hub-hosting
/// and client sync, and pushes a live [SyncStatus] into the status chip.
///
/// The heavy lifting lives in [HubServer] and [SyncClient]; this is the thin,
/// Riverpod-bound seam that the UI drives (host a hub, pair a hub, sync now) and
/// reads status from. Everything stays non-blocking: a failed cycle updates the
/// status to `offline` and is retried next tick, never thrown at the user.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sync/sync_status.dart';
import '../blobs/blob_store.dart';
import '../db/database.dart';
import '../export/event_export.dart';
import '../export/merge_import.dart';
import '../providers.dart';
import 'hub_server.dart';
import 'sync_client.dart';

/// How often the service runs a background sync cycle when hubs are paired.
const Duration kSyncInterval = Duration(seconds: 20);

/// Details of the hub this device is currently hosting, for the pairing screen.
class HostedHubInfo {
  const HostedHubInfo({
    required this.hubId,
    required this.pairingSecret,
    required this.port,
    required this.lanUrls,
  });

  final String hubId;
  final String pairingSecret;
  final int port;

  /// Reachable `http://<ip>:<port>` URLs across this device's LAN interfaces.
  final List<String> lanUrls;
}

/// A parsed, verified import held between the preview step and applying it, so
/// the file is read (and its blobs integrity-checked) exactly once.
class PreparedImport {
  const PreparedImport({required this.archive, required this.preview});

  final ImportedArchive archive;
  final MergePreview preview;
}

/// The bytes and event count of an "export since last export" archive.
class IncrementalExport {
  const IncrementalExport({required this.bytes, required this.eventCount});

  final Uint8List bytes;
  final int eventCount;
}

/// Owns hub hosting and periodic client sync for the running app.
class SyncService {
  SyncService({
    required this.db,
    required this.blobs,
    required this.deviceName,
    required this.onStatus,
  }) : _client = SyncClient(db: db, blobs: blobs, deviceName: deviceName);

  final AppDatabase db;
  final BlobStore blobs;
  final String deviceName;
  final void Function(SyncStatus) onStatus;

  final SyncClient _client;
  HttpServer? _httpServer;
  Timer? _timer;
  bool _started = false;

  /// Whether this device is currently hosting a hub.
  bool get isHosting => _httpServer != null;

  /// Starts (or restarts) hosting a hub on [port], returning its connection
  /// details. Binds all interfaces so phones on the LAN can reach it.
  Future<HostedHubInfo> startHub({int port = 8787}) async {
    await stopHub();
    final hub = HubServer(db: db, blobs: blobs);
    final server = await hub.serve(host: InternetAddress.anyIPv4, port: port);
    _httpServer = server;
    return HostedHubInfo(
      hubId: hub.hubId,
      pairingSecret: hub.pairingSecret,
      port: server.port,
      lanUrls: await _lanUrls(server.port),
    );
  }

  /// Stops hosting, if active.
  Future<void> stopHub() async {
    await _httpServer?.close(force: true);
    _httpServer = null;
  }

  /// Pairs this device with a hub reachable at [baseUrl], then syncs once.
  Future<void> pair(String baseUrl, String pairingSecret) async {
    await _client.pair(baseUrl, pairingSecret);
    await syncNow();
    _startTimer();
  }

  /// Runs one sync cycle now, updating the live status. Never throws.
  Future<SyncResult> syncNow() async {
    final hubs = await db.pairedHubDao.all();
    if (hubs.isEmpty) {
      onStatus(SyncStatus.localOnly);
      return const SyncResult([]);
    }
    onStatus(SyncStatus.syncing);
    final result = await _client.syncOnce();
    onStatus(result.allOk ? SyncStatus.synced : SyncStatus.offline);
    return result;
  }

  /// The offline fallback: exports the whole event log plus its receipt blobs as
  /// `.dbevents.zip` bytes, ready to write to a chosen file. Advances the
  /// "export since last export" cursor so a following incremental export starts
  /// from here.
  Future<Uint8List> exportArchive() async {
    final maxRowid = await db.eventsDao.maxEventRowid();
    final events = await db.eventsDao.allEvents();
    final bytes = await exportEventsZip(events, blobs);
    await db.eventsDao.setLastExportRowid(maxRowid);
    return bytes;
  }

  /// The vacation-swap shortcut: exports only the events (and their blobs) that
  /// have arrived since the last export — captured here or merged in from a file
  /// — and advances the cursor. Returns null when there is nothing new to send.
  Future<IncrementalExport?> exportSinceLastExport() async {
    final cursor = await db.eventsDao.lastExportRowid();
    final maxRowid = await db.eventsDao.maxEventRowid();
    final events = await db.eventsDao.eventsAfterRowid(cursor);
    if (events.isEmpty) {
      return null;
    }
    final bytes = await exportEventsZip(events, blobs);
    await db.eventsDao.setLastExportRowid(maxRowid);
    return IncrementalExport(bytes: bytes, eventCount: events.length);
  }

  /// Parses and verifies a `.dbevents.zip` WITHOUT applying it, paired with a
  /// [MergePreview] of what applying would add. Throws [ImportException] for a
  /// malformed archive and [BlobIntegrityException] for a tampered blob.
  Future<PreparedImport> prepareImportArchive(List<int> zipBytes) async {
    return _prepare(readEventsZip(zipBytes));
  }

  /// Parses plain `.dbevents` JSON-Lines [text] WITHOUT applying it, paired with
  /// a [MergePreview]. Throws [ImportException] on a malformed line.
  Future<PreparedImport> prepareImportJsonl(String text) async {
    return _prepare(
      ImportedArchive(events: importEventsJsonl(text), blobs: const {}),
    );
  }

  Future<PreparedImport> _prepare(ImportedArchive imported) async {
    final existingIds = await db.eventsDao
        .existingEventIds(imported.events.map((e) => e.eventId));
    final existingShas = <String>{};
    for (final sha in imported.blobs.keys) {
      if (await blobs.exists(sha)) existingShas.add(sha);
    }
    final preview = computeMergePreview(
      incomingEvents: imported.events,
      existingEventIds: existingIds,
      incomingBlobShas: imported.blobs.keys,
      existingBlobShas: existingShas,
    );
    return PreparedImport(archive: imported, preview: preview);
  }

  /// Applies a [PreparedImport]: persists new blobs, then appends the events
  /// (idempotent by id — already-present events are silent no-ops). Returns the
  /// preview, whose numbers now describe what was actually added.
  Future<MergePreview> applyImport(PreparedImport prepared) async {
    await saveImportedBlobs(prepared.archive, blobs);
    await db.eventsDao.appendEvents(prepared.archive.events);
    return prepared.preview;
  }

  /// Convenience one-shot: prepare and immediately apply a `.dbevents.zip`.
  Future<MergePreview> importArchive(List<int> zipBytes) async =>
      applyImport(await prepareImportArchive(zipBytes));

  /// Convenience one-shot: prepare and immediately apply `.dbevents` text.
  Future<MergePreview> importJsonl(String text) async =>
      applyImport(await prepareImportJsonl(text));

  /// Begins periodic background sync if hubs are paired. Idempotent: safe to
  /// call from a widget build; only the first call takes effect.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final hubs = await db.pairedHubDao.all();
    if (hubs.isNotEmpty) {
      _startTimer();
      await syncNow();
    } else {
      onStatus(SyncStatus.localOnly);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(kSyncInterval, (_) => syncNow());
  }

  /// Releases the timer, HTTP server and client.
  Future<void> dispose() async {
    _timer?.cancel();
    await stopHub();
    _client.close();
  }

  Future<List<String>> _lanUrls(int port) async {
    final urls = <String>[];
    try {
      for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      )) {
        for (final addr in iface.addresses) {
          urls.add('http://${addr.address}:$port');
        }
      }
    } on Object {
      // Interface enumeration can fail on locked-down platforms; the hub is
      // still up, we just can't advertise an address.
    }
    return urls;
  }
}

/// The live sync-status controller the status chip watches. The [SyncService]
/// pushes coarse states here; it starts local-only.
class SyncStatusController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.localOnly;

  void set(SyncStatus status) => state = status;
}

/// Live sync status, overriding the placeholder provider from the UI layer.
final liveSyncStatusProvider =
    NotifierProvider<SyncStatusController, SyncStatus>(SyncStatusController.new);

/// The hubs this device is paired with, for the sync screen's list.
final pairedHubsProvider = StreamProvider<List<PairedHubRow>>((ref) {
  return ref.watch(appDatabaseProvider).pairedHubDao.watch();
}, dependencies: [appDatabaseProvider]);

/// The device-wide [SyncService], bound to the real store and status controller.
/// Null until first-run setup names this device.
final syncServiceProvider = Provider<SyncService?>((ref) {
  final setup = ref.watch(localSetupProvider).value;
  if (setup == null) return null;
  final service = SyncService(
    db: ref.watch(appDatabaseProvider),
    blobs: ref.watch(blobStoreProvider),
    deviceName: setup.me.name,
    onStatus: (s) => ref.read(liveSyncStatusProvider.notifier).set(s),
  );
  ref.onDispose(service.dispose);
  return service;
}, dependencies: [
  localSetupProvider,
  appDatabaseProvider,
  blobStoreProvider,
]);
